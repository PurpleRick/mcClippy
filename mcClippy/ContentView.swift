//
//  ContentView.swift
//  mcClippy
//

import AppKit
import SwiftData
import SwiftUI

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all, pinned, text, image, link
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .pinned: "Pinned"
        case .text: "Text"
        case .image: "Image"
        case .link: "Link"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "tray.full"
        case .pinned: "pin.fill"
        case .text: "text.alignleft"
        case .image: "photo"
        case .link: "link"
        }
    }

    func matches(_ item: Item) -> Bool {
        switch self {
        case .all: true
        case .pinned: item.isPinned
        case .text: item.type == .text || item.type == .richText
        case .image: item.type == .image
        case .link: item.type == .url
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.panelClose) private var panelClose
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]

    @State private var searchText = ""
    @State private var filter: HistoryFilter = .all
    @State private var selectedID: UUID?
    @State private var hoveredID: UUID?
    @State private var revealedSensitiveItemIDs = Set<UUID>()
    @FocusState private var searchFocused: Bool

    private var filteredItems: [Item] {
        items
            .filter { filter.matches($0) }
            .filter { item in
                guard !searchText.isEmpty else { return true }
                return item.plainTextPreview.localizedCaseInsensitiveContains(searchText)
                    || (item.sourceAppName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            .sorted { a, b in
                if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
                return recencyDate(for: a) > recencyDate(for: b)
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            filterStrip
            Divider().opacity(0.5)
            list
        }
        .background(.regularMaterial)
        .onReceive(NotificationCenter.default.publisher(for: .panelMoveSelectionUp)) { _ in
            moveSelection(by: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelMoveSelectionDown)) { _ in
            moveSelection(by: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelPasteSelected)) { _ in
            pasteSelected()
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDismiss)) { _ in
            panelClose()
        }
        .onAppear {
            searchFocused = true
            if selectedID == nil { selectedID = filteredItems.first?.id }
        }
        .onChange(of: filteredItems.map(\.id)) { _, new in
            if let id = selectedID, !new.contains(id) {
                selectedID = new.first
            } else if selectedID == nil {
                selectedID = new.first
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { pasteSelected() }
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var filterStrip: some View {
        HStack(spacing: 6) {
            ForEach(HistoryFilter.allCases) { option in
                FilterChip(
                    title: option.title,
                    systemImage: option.systemImage,
                    isSelected: filter == option
                ) {
                    filter = option
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - List

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredItems) { item in
                        ClipboardRow(
                            item: item,
                            isSelected: selectedID == item.id,
                            isHovered: hoveredID == item.id,
                            isSensitiveRevealed: revealedSensitiveItemIDs.contains(item.id),
                            onTap: {
                                selectedID = item.id
                                paste(item)
                            },
                            onHover: { hovering in
                                hoveredID = hovering ? item.id : (hoveredID == item.id ? nil : hoveredID)
                            },
                            togglePin: { item.isPinned.toggle() },
                            pasteAsText: { paste(item, asPlainText: true) },
                            delete: {
                                modelContext.delete(item)
                                if selectedID == item.id { selectedID = filteredItems.first?.id }
                            },
                            toggleSensitive: {
                                if revealedSensitiveItemIDs.contains(item.id) {
                                    revealedSensitiveItemIDs.remove(item.id)
                                } else {
                                    revealedSensitiveItemIDs.insert(item.id)
                                }
                            }
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id, anchor: .center) }
            }
            .overlay {
                if filteredItems.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Clipboard Items" : "No Matches",
                        systemImage: searchText.isEmpty ? "clipboard" : "magnifyingglass",
                        description: Text(searchText.isEmpty
                            ? "Copy something, then press \(ShortcutStore.shared.current.displayString) to see it here."
                            : "Try a different search.")
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func moveSelection(by offset: Int) {
        let ids = filteredItems.map(\.id)
        guard !ids.isEmpty else { return }
        guard let current = selectedID, let idx = ids.firstIndex(of: current) else {
            selectedID = ids.first
            return
        }
        let next = (idx + offset).clamped(to: 0...(ids.count - 1))
        selectedID = ids[next]
    }

    private func pasteSelected() {
        guard let id = selectedID,
              let item = filteredItems.first(where: { $0.id == id }) else { return }
        paste(item)
    }

    private func paste(_ item: Item, asPlainText: Bool = false) {
        guard PasteboardSerializer.restore(item, to: .general, asPlainText: asPlainText) else { return }
        let now = Date()
        item.lastUsedAt = now
        PasteboardMonitor.shared.acknowledge(changeCount: NSPasteboard.general.changeCount)
        let candidate = PasteHistoryPanelController.shared.previousFrontmostApp
        let previousApp: NSRunningApplication? = (candidate?.isTerminated == false) ? candidate : nil
        panelClose()
        if AutoPasteSettings.shared.isEnabled {
            if !AutoPaster.paste(into: previousApp) {
                previousApp?.activate(options: [])
            }
        }
    }

    private func recencyDate(for item: Item) -> Date {
        item.lastUsedAt ?? item.createdAt
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.caption)
                Text(title).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                Capsule().fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row

private struct ClipboardRow: View {
    let item: Item
    let isSelected: Bool
    let isHovered: Bool
    let isSensitiveRevealed: Bool
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    let togglePin: () -> Void
    let pasteAsText: () -> Void
    let delete: () -> Void
    let toggleSensitive: () -> Void

    private var shouldMaskPreview: Bool { item.isSensitive && !isSensitiveRevealed }
    private var displayPreview: String {
        PasteboardSerializer.displayPreview(for: item, revealingSensitive: isSensitiveRevealed)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 10) {
                    thumbnail

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            if item.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                            Text(item.type.label.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                            if let app = item.sourceAppName {
                                Text("· \(app)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Text(item.createdAt, style: .relative)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        ZStack(alignment: .leading) {
                            Text(displayPreview)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .blur(radius: shouldMaskPreview ? 4 : 0)
                                .allowsHitTesting(false)

                            if shouldMaskPreview {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10))
                                    Text("Sensitive - paste still works")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.thinMaterial, in: Capsule())
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            rowActions
                .opacity(item.isSensitive || isHovered || isSelected ? 1 : 0)
                .allowsHitTesting(item.isSensitive || isHovered || isSelected)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.18)
                      : (isHovered ? Color.secondary.opacity(0.10) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1)
        )
        .onHover(perform: onHover)
        .contextMenu {
            Button(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin", action: togglePin)
            Button("Paste as Text", systemImage: "textformat", action: pasteAsText)
            if item.isSensitive {
                Button(isSensitiveRevealed ? "Hide Preview" : "Reveal Preview",
                       systemImage: isSensitiveRevealed ? "eye.slash" : "eye",
                       action: toggleSensitive)
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if item.type == .image,
           let data = PasteboardSerializer.decodedData(for: item),
           let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: item.type.systemImageName)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 38)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var rowActions: some View {
        VStack(spacing: 4) {
            if item.isSensitive {
                Button(action: toggleSensitive) {
                    Image(systemName: isSensitiveRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help(isSensitiveRevealed ? "Hide sensitive preview" : "Reveal sensitive preview")
                .accessibilityLabel(isSensitiveRevealed ? "Hide sensitive preview" : "Reveal sensitive preview")
            }

            Button(action: togglePin) {
                Image(systemName: item.isPinned ? "pin.slash" : "pin")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(item.isPinned ? "Unpin" : "Pin")
            .accessibilityLabel(item.isPinned ? "Unpin" : "Pin")

            Menu {
                Button("Paste as Text", systemImage: "textformat", action: pasteAsText)
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More actions")
        }
        .foregroundStyle(.secondary)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    ContentView()
        .frame(width: 360, height: 480)
        .modelContainer(for: Item.self, inMemory: true)
}
