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

    /// Reverse-DNS bundle identifier check. Requires at least two
    /// dot-separated segments starting with a letter and made up of
    /// alphanumerics or `-`. Catches accidental "banana" / "hello.world"
    /// noise without being so strict it blocks valid IDs.
    /// `nonisolated` so tests and any non-MainActor caller can validate cheaply.
    nonisolated static func isValidBundleID(_ id: String) -> Bool {
        let pattern = #"^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$"#
        return id.range(of: pattern, options: .regularExpression) != nil
    }

    @discardableResult
    func add(_ id: String) -> Bool {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidBundleID(trimmed), !bundleIDs.contains(trimmed) else { return false }
        bundleIDs.append(trimmed)
        persist()
        return true
    }

    func remove(_ id: String) {
        bundleIDs.removeAll { $0 == id }
        persist()
    }

    /// Add the current frontmost app's bundle ID, but never add mcClippy
    /// itself — when the user clicks this from the menu bar or Settings,
    /// mcClippy is briefly frontmost and would otherwise self-exclude.
    func excludeFrontmost() {
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              id != Bundle.main.bundleIdentifier else { return }
        add(id)
    }

    func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleIDs.contains(bundleID)
    }

    private func persist() {
        UserDefaults.standard.set(bundleIDs, forKey: defaultsKey)
    }
}
