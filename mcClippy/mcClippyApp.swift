//
//  mcClippyApp.swift
//  mcClippy
//

import AppKit
import Carbon
import CryptoKit
import SwiftData
import SwiftUI

@main
struct mcClippyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        PasteHistoryPanelController.shared.configure(modelContainer: Self.sharedModelContainer)
        PasteboardMonitor.shared.start(modelContainer: Self.sharedModelContainer)
        GlobalShortcutManager.shared.start()
    }

    var body: some Scene {
        MenuBarExtra("Paste History", systemImage: "clipboard") {
            MenuBarControlsView()
        }
        .modelContainer(Self.sharedModelContainer)

        Settings {
            SettingsView()
        }
        .modelContainer(Self.sharedModelContainer)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        OnboardingController.shared.showIfNeeded()
    }
}

// MARK: - Menu Bar

struct MenuBarControlsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @ObservedObject private var shortcutStore = ShortcutStore.shared

    var body: some View {
        Button("Show Paste History  \(shortcutStore.current.displayString)") {
            PasteHistoryPanelController.shared.toggle()
        }

        SettingsLink {
            Label("Settings...", systemImage: "gearshape")
        }

        Divider()

        Button("Pause Monitoring") { PasteboardMonitor.shared.isPaused.toggle() }
        Button("Private Mode (10 min)") {
            PasteboardMonitor.shared.privateModeUntil = Date().addingTimeInterval(10 * 60)
        }
        Button("Exclude Frontmost App") { AppExclusionStore.shared.excludeFrontmost() }

        Divider()

        Button("Clear All Unpinned", role: .destructive) {
            for item in items where !item.isPinned { modelContext.delete(item) }
        }
        Button("Clear Images Only", role: .destructive) {
            for item in items where item.type == .image && !item.isPinned { modelContext.delete(item) }
        }
        Button("Clear Sensitive Items", role: .destructive) {
            for item in items where item.isSensitive { modelContext.delete(item) }
        }

        Divider()

        Text("\(items.count) saved item\(items.count == 1 ? "" : "s")")

        Divider()

        Button("Show Welcome Window") { OnboardingController.shared.show() }

        Button("Quit mcClippy") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: [.command])
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            ExclusionsSettingsView()
                .tabItem { Label("Exclusions", systemImage: "nosign") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(minWidth: 500, minHeight: 460)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject private var shortcutStore = ShortcutStore.shared
    @ObservedObject private var autoPaste = AutoPasteSettings.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginSettings.shared
    @ObservedObject private var historySettings = HistorySettings.shared
    @State private var isAccessibilityTrusted = AccessibilityHelper.isTrusted()

    var body: some View {
        Form {
            Section("Shortcut") {
                ShortcutRecorderView()
                Text("Press this combo anywhere to open Paste History near your cursor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch mcClippy at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))

                if let error = launchAtLogin.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Auto-paste") {
                Toggle("Paste selected item into the previous app on Enter", isOn: $autoPaste.isEnabled)
                if autoPaste.isEnabled {
                    if isAccessibilityTrusted {
                        Label("Accessibility access granted", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Needs Accessibility permission", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Button("Request Accessibility Access") {
                                AccessibilityHelper.requestAccess()
                                isAccessibilityTrusted = AccessibilityHelper.isTrusted()
                            }
                        }
                    }
                    Text("When access is unavailable, Enter still restores the clipboard and returns to the previous app.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("History") {
                Stepper("Keep up to \(historySettings.maxCount) items", value: $historySettings.maxCount, in: 10...500, step: 10)
                Stepper("Maximum item size: \(historySettings.maxItemSizeMegabytes) MB", value: Binding(
                    get: { historySettings.maxItemSizeMegabytes },
                    set: { historySettings.maxItemSizeMegabytes = $0 }
                ), in: 1...50)
                Stepper(historySettings.maxAgeDays == 0 ? "Maximum age: Forever" : "Maximum age: \(historySettings.maxAgeDays) days", value: $historySettings.maxAgeDays, in: 0...365, step: 7)
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            while !Task.isCancelled {
                isAccessibilityTrusted = AccessibilityHelper.isTrusted()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct ExclusionsSettingsView: View {
    @ObservedObject private var store = AppExclusionStore.shared
    @State private var newBundleID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The monitor skips new clipboard captures while one of these apps is frontmost.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(store.bundleIDs, id: \.self) { id in
                    HStack {
                        Text(id).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button(role: .destructive) { store.remove(id) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 160)

            HStack {
                Button("Exclude Frontmost App") { store.excludeFrontmost() }
                Spacer()
                TextField("bundle.id", text: $newBundleID)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                Button("Add") {
                    store.add(newBundleID)
                    newBundleID = ""
                }
                .disabled(newBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Divider()

            HistoryClearControls()
        }
        .padding()
    }
}

private struct HistoryClearControls: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        HStack {
            Button("Clear Unpinned", role: .destructive) {
                for item in items where !item.isPinned {
                    modelContext.delete(item)
                }
            }

            Button("Clear Sensitive", role: .destructive) {
                for item in items where item.isSensitive {
                    modelContext.delete(item)
                }
            }

            Button("Clear All", role: .destructive) {
                for item in items {
                    modelContext.delete(item)
                }
            }
        }
        .controlSize(.small)
    }
}

private struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("mcClippy").font(.title2.weight(.semibold))
            Text("Local-first clipboard history for macOS.")
                .foregroundStyle(.secondary)
            Divider()
            Label("History encrypted at rest (ChaChaPoly + Keychain).", systemImage: "lock.shield")
            Label("Skips password-manager pasteboards.", systemImage: "key.slash")
            Label("Sensitive previews are blurred until you reveal them.", systemImage: "eye.slash")
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Panel Controller

@MainActor
final class PasteHistoryPanelController {
    static let shared = PasteHistoryPanelController()

    private var panel: KeyablePanel?
    private var modelContainer: ModelContainer?
    private var resignObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private(set) var previousFrontmostApp: NSRunningApplication?

    private init() {
        NotificationCenter.default.addObserver(
            forName: .pasteHistoryShortcutPressed,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in PasteHistoryPanelController.shared.toggle() }
        }
    }

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func toggle() {
        if let panel, panel.isVisible {
            close()
        } else {
            show()
        }
    }

    func show() {
        guard let modelContainer else { return }
        // Capture the app the user was actually working in BEFORE we steal focus.
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousFrontmostApp = front
        }
        let panel = self.panel ?? makePanel(modelContainer: modelContainer)
        self.panel = panel
        positionPanel(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func close() {
        removeKeyMonitor()
        panel?.orderOut(nil)
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard PasteHistoryPanelController.shared.panel?.isKeyWindow == true else {
                return event
            }
            switch event.keyCode {
            case 126: // up arrow
                NotificationCenter.default.post(name: .panelMoveSelectionUp, object: nil)
                return nil
            case 125: // down arrow
                NotificationCenter.default.post(name: .panelMoveSelectionDown, object: nil)
                return nil
            case 36, 76: // return / numpad enter
                NotificationCenter.default.post(name: .panelPasteSelected, object: nil)
                return nil
            case 53: // escape
                NotificationCenter.default.post(name: .panelDismiss, object: nil)
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func makePanel(modelContainer: ModelContainer) -> KeyablePanel {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow

        let close: () -> Void = { [weak self] in self?.close() }
        let root = ContentView()
            .environment(\.panelClose, close)
            .modelContainer(modelContainer)
            .frame(width: 360, height: 480)

        let host = NSHostingView(rootView: root)
        host.wantsLayer = true
        host.layer?.cornerRadius = 12
        host.layer?.masksToBounds = true
        panel.contentView = host

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { _ in
            Task { @MainActor in PasteHistoryPanelController.shared.close() }
        }

        return panel
    }

    private func positionPanel(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        // Shrink the panel if it's taller/wider than the available space (small
        // laptop screens, huge Dock, etc.) so it never gets pinned off-screen.
        var size = panel.frame.size
        size.width = min(size.width, max(280, visible.width - 16))
        size.height = min(size.height, max(240, visible.height - 16))
        if size != panel.frame.size {
            panel.setContentSize(size)
        }

        let maxX = max(visible.minX + 8, visible.maxX - size.width - 8)
        let maxY = max(visible.minY + 8, visible.maxY - size.height - 8)
        var origin = NSPoint(x: mouse.x - 40, y: mouse.y - size.height - 8)
        origin.x = min(max(origin.x, visible.minX + 8), maxX)
        origin.y = min(max(origin.y, visible.minY + 8), maxY)
        panel.setFrameOrigin(origin)
    }
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct PanelCloseKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var panelClose: () -> Void {
        get { self[PanelCloseKey.self] }
        set { self[PanelCloseKey.self] = newValue }
    }
}

// MARK: - Pasteboard Monitor

@MainActor
final class PasteboardMonitor {
    static let shared = PasteboardMonitor()

    private var timer: Timer?
    private var modelContainer: ModelContainer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    var isPaused = false
    var privateModeUntil: Date?

    private init() {}

    func start(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        sanitizeSensitivePreviews(in: modelContainer.mainContext)
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.7, repeats: true) { _ in
            Task { @MainActor in PasteboardMonitor.shared.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func acknowledge(changeCount: Int) {
        lastChangeCount = changeCount
    }

    private var isPrivate: Bool {
        guard let privateModeUntil else { return false }
        return privateModeUntil > Date()
    }

    fileprivate func tick() {
        guard !isPaused, !isPrivate else { return }
        let frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        if AppExclusionStore.shared.isExcluded(frontBundleID) { return }
        capture(from: pb)
    }

    private func capture(from pb: NSPasteboard) {
        guard let modelContainer,
              let snapshot = PasteboardSerializer.snapshot(from: pb) else { return }

        guard snapshot.sizeBytes <= HistorySettings.shared.maxItemSizeBytes else { return }

        let context = modelContainer.mainContext
        let targetHash = snapshot.contentHash
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.contentHash == targetHash })

        if let existing = try? context.fetch(descriptor).first {
            existing.createdAt = Date()
            existing.sourceAppBundleId = snapshot.sourceAppBundleId
            existing.sourceAppName = snapshot.sourceAppName
            existing.isSensitive = snapshot.isSensitive
            existing.plainTextPreview = PasteboardSerializer.storedPreview(for: snapshot)
            try? context.save()
            return
        }

        guard let raw = snapshot.data,
              let sealedBlob = EncryptionService.seal(raw) else { return }

        let item = Item(
            type: snapshot.type,
            plainTextPreview: PasteboardSerializer.storedPreview(for: snapshot),
            dataBlob: sealedBlob,
            contentHash: snapshot.contentHash,
            sourceAppBundleId: snapshot.sourceAppBundleId,
            sourceAppName: snapshot.sourceAppName,
            isSensitive: snapshot.isSensitive,
            sizeBytes: snapshot.sizeBytes,
            isEncrypted: true
        )
        context.insert(item)
        try? context.save()
        pruneHistory(in: context)
    }

    private func pruneHistory(in context: ModelContext) {
        let countDescriptor = FetchDescriptor<Item>(
            predicate: #Predicate { !$0.isPinned },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let unpinned = try? context.fetch(countDescriptor) {
            for item in unpinned.dropFirst(HistorySettings.shared.maxCount) {
                context.delete(item)
            }
        }

        let maxAgeDays = HistorySettings.shared.maxAgeDays
        if maxAgeDays > 0,
           let cutoff = Calendar.current.date(byAdding: .day, value: -maxAgeDays, to: Date()) {
            let ageDescriptor = FetchDescriptor<Item>(
                predicate: #Predicate { !$0.isPinned && $0.createdAt < cutoff }
            )
            if let stale = try? context.fetch(ageDescriptor) {
                for item in stale { context.delete(item) }
            }
        }

        try? context.save()
    }

    private func sanitizeSensitivePreviews(in context: ModelContext) {
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.isSensitive })
        guard let sensitiveItems = try? context.fetch(descriptor) else { return }

        for item in sensitiveItems {
            item.plainTextPreview = PasteboardSerializer.sensitivePlaceholder
        }
        try? context.save()
    }
}

// MARK: - Pasteboard Serializer

struct ClipboardSnapshot {
    let type: ClipboardItemKind
    let preview: String
    let data: Data?
    let contentHash: String
    let sourceAppBundleId: String?
    let sourceAppName: String?
    let isSensitive: Bool
    let sizeBytes: Int
}

enum PasteboardSerializer {
    static let sensitivePlaceholder = "Sensitive - hidden"

    private static let concealedTypes: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
        NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType"),
        NSPasteboard.PasteboardType("com.agilebits.onepassword"),
        NSPasteboard.PasteboardType("com.apple.is-remote-clipboard"),
    ]

    /// Bundle IDs of known password / secret managers. Anything copied while one
    /// of these is frontmost is force-flagged as sensitive even if the content
    /// itself doesn't match any pattern (auto-generated random passwords often
    /// match nothing).
    static let passwordManagerBundleIDs: Set<String> = [
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "com.nordvpn.macos.NordPass",
        "com.nordsec.nordpass",
        "com.lastpass.LastPass",
        "org.keepassxc.keepassxc",
        "com.dashlane.dashlanephonefinal",
        "com.dashlane.Dashlane",
        "com.apple.Passwords",
        "com.proton.pass.electron",
        "me.proton.pass",
        "io.enpass.app",
        "com.roboform.RoboForm",
        "com.stickypassword.Sticky-Password",
    ]

    static func isPasswordManagerSource(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return passwordManagerBundleIDs.contains(bundleID)
    }

    static func snapshot(from pasteboard: NSPasteboard) -> ClipboardSnapshot? {
        if let types = pasteboard.types, types.contains(where: concealedTypes.contains) {
            return nil
        }
        let sourceApp = NSWorkspace.shared.frontmostApplication
        let sourceIsPM = isPasswordManagerSource(sourceApp?.bundleIdentifier)

        if let image = NSImage(pasteboard: pasteboard),
           let data = image.tiffRepresentation {
            return ClipboardSnapshot(
                type: .image,
                preview: "Image copied to clipboard",
                data: data,
                contentHash: hash(data),
                sourceAppBundleId: sourceApp?.bundleIdentifier,
                sourceAppName: sourceApp?.localizedName,
                isSensitive: sourceIsPM,
                sizeBytes: data.count
            )
        }

        if let fileURLString = pasteboard.string(forType: .fileURL),
           let fileURL = URL(string: fileURLString) {
            let data = Data(fileURL.absoluteString.utf8)
            return ClipboardSnapshot(
                type: .file,
                preview: fileURL.lastPathComponent.isEmpty ? fileURL.path : fileURL.lastPathComponent,
                data: data,
                contentHash: hash(data),
                sourceAppBundleId: sourceApp?.bundleIdentifier,
                sourceAppName: sourceApp?.localizedName,
                isSensitive: sourceIsPM,
                sizeBytes: data.count
            )
        }

        if let html = pasteboard.string(forType: .html), !html.isEmpty {
            let data = Data(html.utf8)
            return ClipboardSnapshot(
                type: .richText,
                preview: html.strippingTags.truncatedPreview,
                data: data,
                contentHash: hash(data),
                sourceAppBundleId: sourceApp?.bundleIdentifier,
                sourceAppName: sourceApp?.localizedName,
                isSensitive: sourceIsPM || SensitiveContentDetector.looksSensitive(html),
                sizeBytes: data.count
            )
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let data = Data(text.utf8)
            let type: ClipboardItemKind = URL(string: text)?.scheme == nil ? .text : .url
            return ClipboardSnapshot(
                type: type,
                preview: text.truncatedPreview,
                data: data,
                contentHash: hash(data),
                sourceAppBundleId: sourceApp?.bundleIdentifier,
                sourceAppName: sourceApp?.localizedName,
                isSensitive: sourceIsPM || SensitiveContentDetector.looksSensitive(text),
                sizeBytes: data.count
            )
        }

        return nil
    }

    @discardableResult
    static func restore(_ item: Item, to pasteboard: NSPasteboard, asPlainText: Bool = false) -> Bool {
        pasteboard.clearContents()

        if asPlainText {
            guard let value = plainTextValue(for: item) else { return false }
            pasteboard.setString(value, forType: .string)
            return true
        }

        let blob = decodedData(for: item)

        switch item.type {
        case .image:
            guard let data = blob, let image = NSImage(data: data) else { return false }
            return pasteboard.writeObjects([image])
        case .file:
            guard let data = blob,
                  let value = String(data: data, encoding: .utf8),
                  let url = URL(string: value) else { return false }
            return pasteboard.writeObjects([url as NSURL])
        case .richText:
            guard let data = blob,
                  let value = String(data: data, encoding: .utf8) else { return false }
            pasteboard.setData(data, forType: .html)
            pasteboard.setString(value.strippingTags, forType: .string)
            return true
        case .url, .text:
            guard let data = blob,
                  let value = String(data: data, encoding: .utf8) else { return false }
            pasteboard.setString(value, forType: .string)
            return true
        }
    }

    static func storedPreview(for snapshot: ClipboardSnapshot) -> String {
        snapshot.isSensitive ? sensitivePlaceholder : snapshot.preview
    }

    static func displayPreview(for item: Item, revealingSensitive: Bool) -> String {
        guard item.isSensitive else { return item.plainTextPreview }
        guard revealingSensitive else { return sensitivePlaceholder }

        return plainTextValue(for: item)?.truncatedPreview ?? sensitivePlaceholder
    }

    static func decodedData(for item: Item) -> Data? {
        guard let stored = item.dataBlob else { return nil }
        return item.isEncrypted ? EncryptionService.open(stored) : stored
    }

    private static func plainTextValue(for item: Item) -> String? {
        guard let data = decodedData(for: item),
              let value = String(data: data, encoding: .utf8) else { return nil }

        switch item.type {
        case .richText:
            return value.strippingTags
        case .text, .url, .file:
            return value
        case .image:
            return nil
        }
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum SensitiveContentDetector {
    static func looksSensitive(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lowered = trimmed.lowercased()
        let markers = ["password", "passwd", "api_key", "apikey", "secret", "token", "bearer ", "private key"]
        if markers.contains(where: lowered.contains) { return true }
        // Stripe / OpenAI / generic provider keys
        if trimmed.range(of: #"(?i)(sk|pk|rk)_[a-z0-9]{20,}"#, options: .regularExpression) != nil { return true }
        // GitHub PATs
        if trimmed.range(of: #"gh[pousr]_[A-Za-z0-9]{20,}"#, options: .regularExpression) != nil { return true }
        // JWT-like (base64.base64.base64) with the `eyJ` header prefix
        if trimmed.range(of: #"eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"#, options: .regularExpression) != nil { return true }
        // Padded base64 of at least 24 chars (much tighter than before — plain URLs
        // and long single-line prose don't carry `=` padding).
        if trimmed.range(of: #"^[A-Za-z0-9+/]{24,}={1,2}$"#, options: .regularExpression) != nil { return true }
        // Random-looking password: short string, no whitespace, mixed character classes.
        if looksLikePassword(trimmed) { return true }
        return false
    }

    /// Detects auto-generated password style strings:
    /// 8–64 chars, no whitespace, doesn't look like a URL, and contains at
    /// least 3 of the 4 character classes (upper / lower / digit / special).
    /// Hits 1Password/NordPass defaults while leaving long URLs alone.
    static func looksLikePassword(_ value: String) -> Bool {
        guard value.count >= 8, value.count <= 64 else { return false }
        if value.contains(where: { $0.isWhitespace || $0.isNewline }) { return false }
        // URL-shaped strings: explicit scheme, or starts with `www.`
        if value.contains("://") { return false }
        if value.hasPrefix("www.") { return false }
        let hasUpper = value.contains(where: { $0.isUppercase })
        let hasLower = value.contains(where: { $0.isLowercase })
        let hasDigit = value.contains(where: { $0.isNumber })
        let hasSpecial = value.contains(where: { !$0.isLetter && !$0.isNumber })
        let classes = [hasUpper, hasLower, hasDigit, hasSpecial].filter { $0 }.count
        return classes >= 3
    }
}

extension String {
    var truncatedPreview: String {
        let condensed = replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard condensed.count > 180 else { return condensed }
        return String(condensed.prefix(180)) + "..."
    }

    var strippingTags: String {
        replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
    }
}

// MARK: - Global Hotkey

final class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var isStarted = false

    private init() {}

    func start() {
        guard !isStarted else { return }
        isStarted = true

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, eventRef, _ in
            guard let eventRef else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr, hotKeyID.id == GlobalShortcutManager.hotKeyID else { return noErr }
            NotificationCenter.default.post(name: .pasteHistoryShortcutPressed, object: nil)
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        reload()
    }

    func reload() {
        if let existing = hotKeyRef {
            UnregisterEventHotKey(existing)
            hotKeyRef = nil
        }
        let spec = MainActor.assumeIsolated { ShortcutStore.shared.current }
        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: Self.hotKeyID)
        RegisterEventHotKey(
            spec.keyCode,
            spec.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }

    private static let hotKeySignature = OSType(UInt32(ascii: "McPV"))
    private static let hotKeyID = UInt32(1)
}

extension Notification.Name {
    static let pasteHistoryShortcutPressed = Notification.Name("pasteHistoryShortcutPressed")
    static let panelMoveSelectionUp = Notification.Name("panelMoveSelectionUp")
    static let panelMoveSelectionDown = Notification.Name("panelMoveSelectionDown")
    static let panelPasteSelected = Notification.Name("panelPasteSelected")
    static let panelDismiss = Notification.Name("panelDismiss")
}

private extension UInt32 {
    init(ascii: String) {
        self = ascii.utf8.reduce(0) { ($0 << 8) + UInt32($1) }
    }
}
