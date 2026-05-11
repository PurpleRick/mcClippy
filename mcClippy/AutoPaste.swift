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
        guard AccessibilityHelper.isTrusted() else { return false }
        targetApp?.activate(options: [])

        // Give the activation a brief moment before posting the key.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            postCommandV()
        }
        return true
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }
}
