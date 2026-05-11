//
//  mcClippyTests.swift
//  mcClippyTests
//
//  Created by Gordon van Straaten on 11/05/2026.
//

import AppKit
import Foundation
import Testing
@testable import mcClippy

struct mcClippyTests {
    @Test func encryptionRoundTripsData() throws {
        let original = Data("token-value-that-should-round-trip".utf8)
        let sealed = EncryptionService.seal(original)

        #expect(sealed != nil)
        #expect(sealed.flatMap(EncryptionService.open) == original)
    }

    @Test func sensitivePreviewIsStoredAsPlaceholder() {
        let snapshot = ClipboardSnapshot(
            type: .text,
            preview: "password=correct-horse-battery-staple",
            data: Data("password=correct-horse-battery-staple".utf8),
            contentHash: "hash",
            sourceAppBundleId: nil,
            sourceAppName: nil,
            isSensitive: true,
            sizeBytes: 37
        )

        #expect(PasteboardSerializer.storedPreview(for: snapshot) == PasteboardSerializer.sensitivePlaceholder)
    }

    @Test func revealedSensitivePreviewUsesDecryptedData() throws {
        let secret = "password=correct-horse-battery-staple"
        let data = Data(secret.utf8)
        let item = Item(
            type: .text,
            plainTextPreview: PasteboardSerializer.sensitivePlaceholder,
            dataBlob: EncryptionService.seal(data),
            contentHash: "hash",
            sourceAppBundleId: nil,
            sourceAppName: nil,
            isSensitive: true,
            sizeBytes: data.count,
            isEncrypted: true
        )

        #expect(PasteboardSerializer.displayPreview(for: item, revealingSensitive: false) == PasteboardSerializer.sensitivePlaceholder)
        #expect(PasteboardSerializer.displayPreview(for: item, revealingSensitive: true) == secret)
    }

    @Test func pasteAsTextRestoresFullDecryptedValueNotPreview() throws {
        let fullValue = String(repeating: "abc123", count: 80)
        let data = Data(fullValue.utf8)
        let item = Item(
            type: .text,
            plainTextPreview: String(fullValue.prefix(20)),
            dataBlob: EncryptionService.seal(data),
            contentHash: "hash",
            sourceAppBundleId: nil,
            sourceAppName: nil,
            isSensitive: false,
            sizeBytes: data.count,
            isEncrypted: true
        )
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))

        #expect(PasteboardSerializer.restore(item, to: pasteboard, asPlainText: true))
        #expect(pasteboard.string(forType: .string) == fullValue)
    }

    @Test func richTextRestoreWritesHTMLAndPlainTextFallback() throws {
        let html = "<strong>Hello</strong> <em>World</em>"
        let data = Data(html.utf8)
        let item = Item(
            type: .richText,
            plainTextPreview: "Hello World",
            dataBlob: EncryptionService.seal(data),
            contentHash: "hash",
            sourceAppBundleId: nil,
            sourceAppName: nil,
            isSensitive: false,
            sizeBytes: data.count,
            isEncrypted: true
        )
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))

        #expect(PasteboardSerializer.restore(item, to: pasteboard))
        #expect(pasteboard.string(forType: .html) == html)
        #expect(pasteboard.string(forType: .string)?.contains("Hello") == true)
        #expect(pasteboard.string(forType: .string)?.contains("World") == true)
    }

    @Test func sensitiveDetectorFlagsTokenLikeContent() {
        #expect(SensitiveContentDetector.looksSensitive("api_key=sk_abcdefghijklmnopqrstuvwxyz123456"))
        #expect(!SensitiveContentDetector.looksSensitive("https://example.com/docs"))
    }

    @MainActor
    @Test func shortcutSpecCodableRoundTrips() throws {
        let spec = ShortcutSpec(keyCode: 49, modifierFlags: 768)
        let data = try JSONEncoder().encode(spec)
        let decoded = try JSONDecoder().decode(ShortcutSpec.self, from: data)

        #expect(decoded == spec)
    }

    @MainActor
    @Test func appExclusionsCanAddAndRemoveBundleID() {
        let id = "test.mcClippy.exclusion.\(UUID().uuidString)"
        let store = AppExclusionStore.shared

        store.add(id)
        #expect(store.isExcluded(id))

        store.remove(id)
        #expect(!store.isExcluded(id))
    }

    @MainActor
    @Test func historySettingsClampValues() {
        let settings = HistorySettings.shared
        let originalCount = settings.maxCount
        let originalSize = settings.maxItemSizeBytes
        let originalAge = settings.maxAgeDays

        settings.maxCount = 1
        settings.maxItemSizeBytes = 1
        settings.maxAgeDays = 999

        #expect(settings.maxCount == 10)
        #expect(settings.maxItemSizeBytes == 64 * 1024)
        #expect(settings.maxAgeDays == 365)

        settings.maxCount = originalCount
        settings.maxItemSizeBytes = originalSize
        settings.maxAgeDays = originalAge
    }
}
