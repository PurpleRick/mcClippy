//
//  AppExclusions.swift
//  mcClippy
//

import AppKit
import Combine
import Foundation

@MainActor
final class AppExclusionStore: ObservableObject {
    static let shared = AppExclusionStore()

    private let defaultsKey = "mcClippy.excludedBundleIDs"

    @Published private(set) var bundleIDs: [String]

    private init() {
        self.bundleIDs = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
    }

    func add(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !bundleIDs.contains(trimmed) else { return }
        bundleIDs.append(trimmed)
        persist()
    }

    func remove(_ id: String) {
        bundleIDs.removeAll { $0 == id }
        persist()
    }

    func excludeFrontmost() {
        if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            add(id)
        }
    }

    func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleIDs.contains(bundleID)
    }

    private func persist() {
        UserDefaults.standard.set(bundleIDs, forKey: defaultsKey)
    }
}
