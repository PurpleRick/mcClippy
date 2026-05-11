//
//  Onboarding.swift
//  mcClippy
//

import AppKit
import SwiftUI

@MainActor
final class OnboardingController {
    static let shared = OnboardingController()
    private let defaultsKey = "mcClippy.hasSeenOnboarding"
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?

    private init() {}

    var hasSeen: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    func showIfNeeded() {
        guard !hasSeen else { return }
        show()
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = OnboardingView { [weak self] in self?.dismiss() }
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "Welcome to mcClippy"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 500))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        // Whether the user clicks "Get Started" or the red traffic-light, persist
        // the seen flag so the welcome window doesn't reappear every launch.
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            UserDefaults.standard.set(true, forKey: "mcClippy.hasSeenOnboarding")
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        UserDefaults.standard.set(true, forKey: defaultsKey)
        window?.close()
    }
}

private struct OnboardingView: View {
    let onFinish: () -> Void

    @ObservedObject private var shortcutStore = ShortcutStore.shared
    @ObservedObject private var shortcutManager = GlobalShortcutManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "clipboard")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to mcClippy").font(.title2.weight(.semibold))
                    Text("Local-first clipboard history for macOS.")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Row(icon: shortcutManager.registrationStatus.isRegistered ? "keyboard" : "exclamationmark.triangle",
                    title: shortcutTitle,
                    message: shortcutMessage)
                Row(icon: "lock.shield", title: "Encrypted at rest",
                    message: "Captured content is sealed with ChaChaPoly and a Keychain key — only this Mac can read it.")
                Row(icon: "eye.slash", title: "Sensitive items are blurred",
                    message: "Passwords, tokens, and API keys are auto-detected and hidden until you click the eye. Paste still works while blurred — safe for screen shares.")
                Row(icon: "key", title: "Passwords stay usable",
                    message: "Password-manager and concealed pasteboards are captured as sensitive items, masked by default, and available when you reveal or paste them.")
                Row(icon: "clock.arrow.circlepath", title: "Windows-like by default",
                    message: "Clipboard and pinned history clear when mcClippy starts. Change how long each type persists in Settings → General.")
                Row(icon: "nosign", title: "Per-app exclusions",
                    message: "Add bundle IDs in Settings → Exclusions to skip captures while those apps are frontmost.")
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Get Started", action: onFinish)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
        }
        .padding(24)
        .frame(width: 520, height: 500, alignment: .topLeading)
    }

    private var shortcutTitle: String {
        if shortcutManager.registrationStatus.isRegistered {
            return "Press \(shortcutStore.current.displayString) anywhere"
        }
        return "Shortcut needs attention"
    }

    private var shortcutMessage: String {
        if shortcutManager.registrationStatus.isRegistered {
            return "Opens a floating panel near your cursor. Arrow keys move, Return pastes, Esc closes. Rebind it in Settings → General."
        }
        return shortcutManager.registrationStatus.message + " Open Settings → General to choose another combo."
    }
}

private struct Row: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
