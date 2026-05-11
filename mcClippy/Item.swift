//
//  Item.swift
//  mcClippy
//
//  Created by Gordon van Straaten on 11/05/2026.
//

import Foundation
import SwiftData

enum ClipboardItemKind: String, CaseIterable, Codable {
    case text
    case image
    case file
    case url
    case richText

    var label: String {
        switch self {
        case .text:
            "Text"
        case .image:
            "Image"
        case .file:
            "File"
        case .url:
            "URL"
        case .richText:
            "Rich Text"
        }
    }

    var systemImageName: String {
        switch self {
        case .text:
            "text.alignleft"
        case .image:
            "photo"
        case .file:
            "doc"
        case .url:
            "link"
        case .richText:
            "textformat"
        }
    }
}

@Model
final class Item {
    var id: UUID
    var typeRawValue: String
    var plainTextPreview: String
    var dataBlob: Data?
    var contentHash: String
    var sourceAppBundleId: String?
    var sourceAppName: String?
    var createdAt: Date
    var lastUsedAt: Date?
    var isPinned: Bool
    var isSensitive: Bool
    var sizeBytes: Int
    var isEncrypted: Bool = false

    var type: ClipboardItemKind {
        get {
            ClipboardItemKind(rawValue: typeRawValue) ?? .text
        }
        set {
            typeRawValue = newValue.rawValue
        }
    }

    init(
        id: UUID = UUID(),
        type: ClipboardItemKind,
        plainTextPreview: String,
        dataBlob: Data?,
        contentHash: String,
        sourceAppBundleId: String?,
        sourceAppName: String?,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        isPinned: Bool = false,
        isSensitive: Bool = false,
        sizeBytes: Int,
        isEncrypted: Bool = false
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.plainTextPreview = plainTextPreview
        self.dataBlob = dataBlob
        self.contentHash = contentHash
        self.sourceAppBundleId = sourceAppBundleId
        self.sourceAppName = sourceAppName
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
        self.isSensitive = isSensitive
        self.sizeBytes = sizeBytes
        self.isEncrypted = isEncrypted
    }
}
