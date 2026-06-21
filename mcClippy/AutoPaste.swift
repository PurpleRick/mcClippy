//
//  AutoPaste.swift
//  mcClippy
//

import AppKit
import ApplicationServices
import Carbon
import Combine
import Foundation
import os

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
    /// Activate `targetApp` then post ⌘V once the target is frontmost.
    /// Returns false if Accessibility is missing or the target is nil/terminated.
    /// Returning true means we scheduled the keystroke after the target became
    /// active (or hit the ~400 ms cap) — not that the keystroke necessarily landed.
    @discardableResult
    static func paste(into targetApp: NSRunningApplication?) -> Bool {
        guard AccessibilityHelper.isTrusted() else {
            Log.paste.notice("Auto-paste skipped: Accessibility not trusted; prompting")
            AccessibilityHelper.requestAccess()
            return false
        }
        guard let target = targetApp, !target.isTerminated else {
            Log.paste.notice("Auto-paste skipped: target app is nil or terminated")
            return false
        }

        target.activate(options: [.activateAllWindows])
        attemptPaste(target: target, retriesRemaining: 8)
        return true
    }

    private static func attemptPaste(target: NSRunningApplication, retriesRemaining: Int) {
        if target.isActive || retriesRemaining == 0 {
            postCommandV()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            attemptPaste(target: target, retriesRemaining: retriesRemaining - 1)
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            Log.paste.error("Auto-paste failed: could not create ⌘V CGEvent")
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        // HID-level tap is the most reliable across destination apps; some
        // Electron/Chromium apps drop events posted to the annotated session tap.
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
