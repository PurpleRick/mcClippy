//
//  ProductSettings.swift
//  mcClippy
//

import Foundation
import Combine
import ServiceManagement

@MainActor
final class HistorySettings: ObservableObject {
    static let shared = HistorySettings()

    private let maxCountKey = "mcClippy.history.maxCount"
    private let maxItemSizeKey = "mcClippy.history.maxItemSizeBytes"
    private let maxAgeDaysKey = "mcClippy.history.maxAgeDays"

    @Published var maxCount: Int {
        didSet {
            maxCount = max(10, min(maxCount, 500))
            UserDefaults.standard.set(maxCount, forKey: maxCountKey)
        }
    }

    @Published var maxItemSizeBytes: Int {
        didSet {
            maxItemSizeBytes = max(64 * 1024, min(maxItemSizeBytes, 50 * 1024 * 1024))
            UserDefaults.standard.set(maxItemSizeBytes, forKey: maxItemSizeKey)
        }
    }

    @Published var maxAgeDays: Int {
        didSet {
            maxAgeDays = max(0, min(maxAgeDays, 365))
            UserDefaults.standard.set(maxAgeDays, forKey: maxAgeDaysKey)
        }
    }

    var maxItemSizeMegabytes: Int {
        get { maxItemSizeBytes / 1_048_576 }
        set { maxItemSizeBytes = newValue * 1_048_576 }
    }

    private init() {
        let storedMaxCount = UserDefaults.standard.integer(forKey: maxCountKey)
        self.maxCount = storedMaxCount == 0 ? 100 : storedMaxCount

        let storedMaxItemSize = UserDefaults.standard.integer(forKey: maxItemSizeKey)
        self.maxItemSizeBytes = storedMaxItemSize == 0 ? 5 * 1024 * 1024 : storedMaxItemSize

        self.maxAgeDays = UserDefaults.standard.integer(forKey: maxAgeDaysKey)
    }
}

@MainActor
final class LaunchAtLoginSettings: ObservableObject {
    static let shared = LaunchAtLoginSettings()

    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var lastError: String?

    private init() {
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        refresh()
    }
}
