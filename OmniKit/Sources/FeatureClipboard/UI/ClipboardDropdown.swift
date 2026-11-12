import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Clipboard history as a dropdown under the menu bar icon: sized and styled
/// like a native menu, but with image previews. Click, ↩ or ⌘1–⌘9 pastes;
/// ↑↓ move; typing filters; Esc closes.
struct ClipboardDropdown: View {
    let feature: ClipboardHistoryFeature
    let close: () -> Void
    @State private var query = ""
    @State private var selection = 0
    @State private var hovered: Int?
    @State private var confirmClear = false
    @FocusState private var focused: Bool

    /// Native menus are about this wide for one-line items.
    static let width: CGFloat = 340
    static let textRow: CGFloat = 22
    static let imageRow: CGFloat = 44
    private typealias S = L10n.Clipboard

    private var records: [ClipRecord] {
        let all = query.isEmpty
            ? feature.newestRecords(limit: ClipboardHistoryFeature.historyMenuCount)
            : feature.records(matching: query, limit: ClipboardHistoryFeature.historyMenuCount)
        // Pinned first, like the menu used to show them.
        return all.filter(\.pinned) + all.filter { !$0.pinned }
    }

    var body: some View {
        let items = records
        VStack(alignment: .leading, spacing: 0) {
            if !query.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text(query).lineLimit(1)
                }
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).frame(height: Self.textRow)
                Divider().padding(.vertical, 4)
            }
            if items.isEmpty {
                Text(query.isEmpty ? S.emptyHistory : L10n.Common.noMatches(query))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .padding(.horizontal, 10).frame(minHeight: Self.textRow)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, record in
                                if index > 0, record.pinned != items[index - 1].pinned { Divider().padding(.vertical, 4) }
                                row(record, index: index).id(index)
                            }
                        }
                    }
                    .frame(maxHeight: maxListHeight(items))
                    .onChange(of: selection) { _, value in proxy.scrollTo(value) }
                }
            }
            Divider().padding(.vertical, 4)
            plainRow(S.menuSearchHistory) { close(); feature.searchHistory() }
            plainRow(S.menuClearHistory) { confirmClear = true }
        }
        .padding(5)
        .frame(width: Self.width)
        .background(MenuMaterial())
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(nsColor: .separatorColor).opacity(OmniStyle.increaseContrast ? 1 : 0.5)))
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(phases: .down) { press in handle(press, items: items) }
        .confirmationDialog(S.clearConfirmation((try? feature.store?.unpinnedCount()) ?? 0), isPresented: $confirmClear) {
            Button(S.menuClearHistory, role: .destructive) { feature.clear(keepPinned: true); close() }
            Button(L10n.Common.cancel, role: .cancel) {}
        }
    }

    private func maxListHeight(_ items: [ClipRecord]) -> CGFloat {
        let screen = NSScreen.main?.visibleFrame.height ?? 800
        let content = items.reduce(CGFloat(0)) { $0 + ($1.kind == .image ? Self.imageRow : Self.textRow) } + 10
        return min(content, screen - 160)
    }

    // MARK: Rows

    private func row(_ record: ClipRecord, index: Int) -> some View {
        let highlighted = index == (hovered ?? selection)
        return Button { paste(record) } label: {
            HStack(spacing: 8) {
                preview(record)
                Text(record.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                if index < 9 {
                    Text("⌘\(index + 1)").font(.system(size: 13)).foregroundStyle(highlighted ? .white.opacity(0.8) : .secondary) // l10n-ignore
                }
            }
            .foregroundStyle(highlighted ? .white : .primary)
            .padding(.horizontal, 9)
            .frame(height: record.kind == .image ? Self.imageRow : Self.textRow)
            .background(RoundedRectangle(cornerRadius: 5).fill(highlighted ? Color.accentColor : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in hovered = inside ? index : (hovered == index ? nil : hovered) }
        .help(record.kind == .text ? String((record.text ?? "").prefix(400)) : record.title)
    }

    @ViewBuilder private func preview(_ record: ClipRecord) -> some View {
        switch record.kind {
        case .image:
            if let url = feature.store?.thumbnailURL(for: record), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: Self.imageRow - 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo").frame(width: 16)
            }
        case .files:
            if let url = record.fileURLs.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 16, height: 16)
            }
        case .text:
            if record.sourceBundleID == PasteboardTypes.capturedTextSource {
                Image(systemName: "text.viewfinder").frame(width: 16)
            } else if record.pinned {
                Image(systemName: "pin.fill").font(.system(size: 10)).frame(width: 16)
            }
        }
    }

    private func plainRow(_ title: String, action: @escaping () -> Void) -> some View {
        PlainMenuRow(title: title, action: action)
    }

    // MARK: Actions

    private func paste(_ record: ClipRecord) {
        close()
        let action = feature.pasteAction(for: record)
        // Let the dropdown go away so the paste lands in the app you were using.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            action()
        }
    }

    private func handle(_ press: KeyPress, items: [ClipRecord]) -> KeyPress.Result {
        if press.modifiers.contains(.command), let digit = Int(press.characters), (1...9).contains(digit) {
            if items.indices.contains(digit - 1) { paste(items[digit - 1]) }
            return .handled
        }
        switch press.key {
        case .downArrow:
            hovered = nil
            selection = min(selection + 1, max(items.count - 1, 0))
        case .upArrow:
            hovered = nil
            selection = max(selection - 1, 0)
        case .return:
            if items.indices.contains(selection) { paste(items[selection]) }
        case .escape:
            close()
        case .delete:
            if !query.isEmpty { query.removeLast(); selection = 0 }
        default:
            let typed = press.characters.filter { !$0.isNewline && $0.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) } }
            guard !typed.isEmpty, press.modifiers.isDisjoint(with: [.command, .control]) else { return .ignored }
            query += typed
            selection = 0
        }
        return .handled
    }
}

private struct PlainMenuRow: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 13))
                .foregroundStyle(hovering ? .white : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9)
                .frame(height: ClipboardDropdown.textRow)
                .background(RoundedRectangle(cornerRadius: 5).fill(hovering ? Color.accentColor : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// The same translucent material native menus use.
private struct MenuMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
