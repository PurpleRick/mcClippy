//
//  Shortcuts.swift
//  mcClippy
//

import AppKit
import Carbon
import Combine
import SwiftUI

struct ShortcutSpec: Equatable, Codable {
    var keyCode: UInt32
    var modifierFlags: UInt32

    static let `default` = ShortcutSpec(keyCode: UInt32(kVK_ANSI_V), modifierFlags: UInt32(cmdKey | shiftKey))

    var carbonModifiers: UInt32 { modifierFlags }

    var displayString: String {
        var parts: [String] = []
        if modifierFlags & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifierFlags & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifierFlags & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifierFlags & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: "A"; case kVK_ANSI_B: "B"; case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"; case kVK_ANSI_E: "E"; case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"; case kVK_ANSI_H: "H"; case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"; case kVK_ANSI_K: "K"; case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"; case kVK_ANSI_N: "N"; case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"; case kVK_ANSI_Q: "Q"; case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"; case kVK_ANSI_T: "T"; case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"; case kVK_ANSI_W: "W"; case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"; case kVK_ANSI_Z: "Z"
        case kVK_ANSI_0: "0"; case kVK_ANSI_1: "1"; case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"; case kVK_ANSI_4: "4"; case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"; case kVK_ANSI_7: "7"; case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_Space: "Space"
        case kVK_Return: "↩"
        case kVK_Tab: "⇥"
        case kVK_Escape: "⎋"
        case kVK_F1: "F1"; case kVK_F2: "F2"; case kVK_F3: "F3"
        case kVK_F4: "F4"; case kVK_F5: "F5"; case kVK_F6: "F6"
        case kVK_F7: "F7"; case kVK_F8: "F8"; case kVK_F9: "F9"
        case kVK_F10: "F10"; case kVK_F11: "F11"; case kVK_F12: "F12"
        default: "?"
        }
    }

    static func carbonFlags(from nsFlags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if nsFlags.contains(.command) { carbon |= UInt32(cmdKey) }
        if nsFlags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if nsFlags.contains(.option) { carbon |= UInt32(optionKey) }
        if nsFlags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }
}

@MainActor
final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()

    private let defaultsKey = "mcClippy.shortcut"

    @Published var current: ShortcutSpec {
        didSet {
            persist()
            GlobalShortcutManager.shared.reload()
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(ShortcutSpec.self, from: data) {
            self.current = decoded
        } else {
            self.current = .default
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

// MARK: - Recorder UI

struct ShortcutRecorderView: View {
    @ObservedObject private var store = ShortcutStore.shared
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text("Open Paste History")
            Spacer()
            Button {
                toggleRecording()
            } label: {
                Text(isRecording ? "Press combo…" : store.current.displayString)
                    .frame(minWidth: 110)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1)
                    )
                    .foregroundStyle(isRecording ? Color.accentColor : Color.primary)
                    .font(.system(.body, design: .monospaced))
            }
            .buttonStyle(.plain)
            Button("Reset") { store.current = .default }
                .controlSize(.small)
        }
        .onDisappear { stopRecording() }
    }

    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let nsFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let carbon = ShortcutSpec.carbonFlags(from: nsFlags)
            // Reject bare keys with no modifiers (would conflict with normal typing)
            guard carbon != 0 else { return event }
            let spec = ShortcutSpec(keyCode: UInt32(event.keyCode), modifierFlags: carbon)
            DispatchQueue.main.async {
                ShortcutStore.shared.current = spec
                self.stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
