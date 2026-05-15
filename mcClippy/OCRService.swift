//
//  OCRService.swift
//  mcClippy
//

import Foundation
import ImageIO
import Vision

/// On-device text recognition for image clipboard items.
///
/// Vision runs locally — no network, no entitlement. Extraction is on-demand:
/// `OCRService.shared.extract(for:data:)` is called when the user requests
/// "Paste as Text" on an image row. Results are cached on the `Item` via
/// `ocrText` + `ocrCompletedAt`, so the second request is instant.
///
/// Concurrency: a semaphore caps at 2 simultaneous VNRequests so a panel-full
/// of fresh image items can't peg the CPU. Concurrent calls for the same
/// `itemID` are deduped — later callers await the same in-flight `Task` instead
/// of starting a duplicate Vision request.
actor OCRService {
    static let shared = OCRService()

    /// Maximum pixel dimension we feed to Vision. Above this we downsample via
    /// `CGImageSourceCreateThumbnailAtIndex` — Vision's accuracy plateaus well
    /// below source resolution for screen captures, and the speed gain is large.
    private static let maxPixelSize: Int = 4096

    private var inFlight: [UUID: Task<String?, Never>] = [:]
    private let permitter = ConcurrencyPermitter(limit: 2)

    private init() {}

    /// Returns the extracted text, or nil if extraction failed.
    /// Empty string means OCR ran successfully but found no text.
    func extract(itemID: UUID, data: Data, languages: [String]? = nil) async -> String? {
        if let pending = inFlight[itemID] {
            return await pending.value
        }
        let task = Task<String?, Never> { [permitter] in
            await permitter.acquire()
            defer { Task { await permitter.release() } }
            return Self.runVision(on: data, languages: languages)
        }
        inFlight[itemID] = task
        let result = await task.value
        inFlight[itemID] = nil
        return result
    }

    /// Drops any cached in-flight task for an item (e.g. when the item is
    /// deleted while OCR is running). The task itself continues to completion
    /// but its result is no longer awaited.
    func cancelInFlight(itemID: UUID) {
        inFlight[itemID] = nil
    }

    /// True if there is an active extraction for this item.
    func isExtracting(itemID: UUID) -> Bool {
        inFlight[itemID] != nil
    }

    // MARK: - Vision plumbing (synchronous, runs inside the Task)

    private static func runVision(on data: Data, languages: [String]?) -> String? {
        guard let cgImage = downsampledImage(from: data, maxPixelSize: maxPixelSize) else {
            return nil
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if let languages, !languages.isEmpty {
            request.recognitionLanguages = languages
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results else { return "" }
        // Join the top candidate from each observation, in reading order.
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n")
    }

    private static func downsampledImage(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// A small async-friendly counting semaphore. Apple ships
/// `AsyncSemaphore` in newer Swift but it's not yet universal; this is the
/// minimal version we need.
actor ConcurrencyPermitter {
    private let limit: Int
    private var inUse: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func acquire() async {
        if inUse < limit {
            inUse += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else if inUse > 0 {
            inUse -= 1
        }
    }
}
