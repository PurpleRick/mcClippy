//
//  AutoPaste.swift
//  mcClippy
//

import AppKit
import ApplicationServices
import Carbon
import Combine
import Foundation

@MainActor
final class AutoPasteSettings: ObservableObject {
    static let shared = AutoPasteSettings()
    private let defaultsKey = "mcClippy.autoPasteEnabled"

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: defaultsKey) }
    }

    private init() {
        if UserDefaults.standard.object(forKey: defaultsKey) == nil {
            self.isEnabled = true
            UserDefaults.standard.set(true, forKey: defaultsKey)
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: defaultsKey)
        }
    }
}

enum AccessibilityHelper {
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccess() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: kCFBooleanTrue] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

enum AutoPaster {
    /// Activate `targetApp` then post ⌘V to the system. Caller is responsible for
    /// ensuring the clipboard already holds the desired content.
    @discardableResult
    static func paste(into targetApp: NSRunningApplication?) -> Bool {
        guard AccessibilityHelper.isTrusted() else {
            AccessibilityHelper.requestAccess()
            return false
        }

        let pid = targetApp?.processIdentifier
        targetApp?.activate(options: [.activateAllWindows])

        // Give AppKit a moment to close the panel and restore focus. Posting to
        // the target PID avoids dropping Cmd+V when our menu-bar panel still owns
        // key focus for a few milliseconds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            postCommandV(to: pid)
        }
        return true
    }

    private static func postCommandV(to pid: pid_t?) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand

        if let pid, pid > 0 {
            down.postToPid(pid)
            up.postToPid(pid)
        } else {
            down.post(tap: .cgAnnotatedSessionEventTap)
            up.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
