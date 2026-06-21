//
//  Log.swift
//  mcClippy
//
//  Lightweight, privacy-preserving logging. mcClippy handles clipboard
//  contents, so the cardinal rule here is: NEVER log captured text, previews,
//  decrypted blobs, or anything derived from them. Log control-flow events and
//  failure reasons only, and treat every interpolated value as `.private`
//  unless it is provably non-sensitive metadata (counts, byte sizes, booleans,
//  error descriptions from system APIs).
//
//  View these in Console.app or:
//    log show --predicate 'subsystem == "makmaj.mcClippy"' --last 1h --info
//

import Foundation
import os

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "makmaj.mcClippy"

    /// App lifecycle, container creation, store maintenance.
    static let app = Logger(subsystem: subsystem, category: "app")
    /// Pasteboard capture pipeline (never logs captured content).
    static let capture = Logger(subsystem: subsystem, category: "capture")
    /// Auto-paste / CGEvent posting.
    static let paste = Logger(subsystem: subsystem, category: "paste")
    /// On-demand OCR.
    static let ocr = Logger(subsystem: subsystem, category: "ocr")
}
