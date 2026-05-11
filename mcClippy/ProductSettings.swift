//
//  ProductSettings.swift
//  mcClippy
//

import Foundation
import Combine
import Darwin
import ServiceManagement

enum ClipboardRetentionPolicy: String, CaseIterable, Identifiable {
    case untilReboot = "clearAtStartup"
    case oneDay
    case sevenDays
    case thirtyDays
    case ninetyDays
    case oneYear
    case forever

    var id: String { rawValue }

    var label: String {
        switch self {
        case .untilReboot:
            "Until reboot"
        case .oneDay:
            "1 day"
        case .sevenDays:
            "7 days"
        case .thirtyDays:
            "30 days"
        case .ninetyDays:
            "90 days"
        case .oneYear:
            "365 days"
        case .forever:
            "Forever"
        }
    }

    var maxAgeDays: Int? {
        switch self {
        case .untilReboot, .forever:
            nil
        case .oneDay:
            1
        case .sevenDays:
            7
        case .thirtyDays:
            30
        case .ninetyDays:
            90
        case .oneYear:
            365
        }
    }

    static func ageLimited(days: Int) -> ClipboardRetentionPolicy {
        switch max(0, min(days, 365)) {
        case 0:
            .forever
        case 1:
            .oneDay
        case 2...7:
            .sevenDays
        case 8...30:
            .thirtyDays
        case 31...90:
            .ninetyDays
        case 91...365:
            .oneYear
        default:
            .forever
        }
    }
}

@MainActor
final class HistorySettings: ObservableObject {
    static let shared = HistorySettings()

    private let maxCountKey = "mcClippy.history.maxCount"
    private let maxItemSizeKey = "mcClippy.history.maxItemSizeBytes"
    private let maxAgeDaysKey = "mcClippy.history.maxAgeDays"
    private let regularRetentionKey = "mcClippy.history.regularRetentionPolicy"
    private let pinnedRetentionKey = "mcClippy.history.pinnedRetentionPolicy"
    private let lastBootCleanupKey = "mcClippy.history.lastBootCleanupToken"

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

    @Published var regularRetentionPolicy: ClipboardRetentionPolicy {
        didSet {
            UserDefaults.standard.set(regularRetentionPolicy.rawValue, forKey: regularRetentionKey)
        }
    }

    @Published var pinnedRetentionPolicy: ClipboardRetentionPolicy {
        didSet {
            UserDefaults.standard.set(pinnedRetentionPolicy.rawValue, forKey: pinnedRetentionKey)
        }
    }

    var maxAgeDays: Int {
        get { regularRetentionPolicy.maxAgeDays ?? 0 }
        set {
            let clamped = max(0, min(newValue, 365))
            regularRetentionPolicy = ClipboardRetentionPolicy.ageLimited(days: clamped)
            UserDefaults.standard.set(clamped, forKey: maxAgeDaysKey)
        }
    }

    var maxItemSizeMegabytes: Int {
        get { maxItemSizeBytes / 1_048_576 }
        set { maxItemSizeBytes = newValue * 1_048_576 }
    }

    var usesRebootScopedRetention: Bool {
        regularRetentionPolicy == .untilReboot || pinnedRetentionPolicy == .untilReboot
    }

    func shouldClearRebootScopedHistory() -> Bool {
        guard usesRebootScopedRetention else { return false }
        return UserDefaults.standard.string(forKey: lastBootCleanupKey) != currentBootToken
    }

    func markRebootScopedHistoryCleared() {
        UserDefaults.standard.set(currentBootToken, forKey: lastBootCleanupKey)
    }

    func resetRebootScopedHistoryMarkerForTesting() {
        UserDefaults.standard.removeObject(forKey: lastBootCleanupKey)
    }

    private var currentBootToken: String {
        var bootTime = timeval()
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        var size = MemoryLayout<timeval>.stride
        if sysctl(&mib, UInt32(mib.count), &bootTime, &size, nil, 0) == 0, bootTime.tv_sec > 0 {
            return String(bootTime.tv_sec)
        }

        let bootDate = Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)
        return String(Int(bootDate.timeIntervalSince1970 / 60))
    }

    private init() {
        let storedMaxCount = UserDefaults.standard.integer(forKey: maxCountKey)
        self.maxCount = storedMaxCount == 0 ? 100 : max(10, min(storedMaxCount, 500))

        let storedMaxItemSize = UserDefaults.standard.integer(forKey: maxItemSizeKey)
        self.maxItemSizeBytes = storedMaxItemSize == 0 ? 5 * 1024 * 1024 : max(64 * 1024, min(storedMaxItemSize, 50 * 1024 * 1024))

        if let raw = UserDefaults.standard.string(forKey: regularRetentionKey),
           let policy = ClipboardRetentionPolicy(rawValue: raw) {
            self.regularRetentionPolicy = policy
        } else if UserDefaults.standard.object(forKey: maxAgeDaysKey) != nil {
            self.regularRetentionPolicy = ClipboardRetentionPolicy.ageLimited(days: UserDefaults.standard.integer(forKey: maxAgeDaysKey))
        } else {
            self.regularRetentionPolicy = .untilReboot
        }

        if let raw = UserDefaults.standard.string(forKey: pinnedRetentionKey),
           let policy = ClipboardRetentionPolicy(rawValue: raw) {
            self.pinnedRetentionPolicy = policy
        } else {
            self.pinnedRetentionPolicy = .untilReboot
        }
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
