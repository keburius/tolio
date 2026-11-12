import AppKit
import Observation
import SwiftUI

/// What the overlay shows.
@MainActor
@Observable
final class OverlayModel {
    enum Mode { case hold, pinned }
    enum Status: Equatable { case loading, ready, unavailable }

    static let columnWidth: CGFloat = 300
    static let columnSpacing: CGFloat = 28
    static let rowHeight: CGFloat = 21
    static let headerHeight: CGFloat = 30
    static let sectionSpacing: CGFloat = 14
    static let padding: CGFloat = 22
    static let titleBarHeight: CGFloat = 52

    var mode: Mode = .hold
    var status: Status = .loading
    var appName = ""
    var appIcon: NSImage?
    var sections: [ShortcutSection] = []
    var query = ""
    var truncated = false
    /// Set by the controller from the screen size.
    var maxColumns = 3
    var rowsPerColumn = 30
    @ObservationIgnored var onChoose: (ShortcutEntry) -> Void = { _ in }

    var visibleSections: [ShortcutSection] {
        mode == .pinned ? ShortcutCatalog.filter(sections, query: query) : sections
    }

    /// Height of one section in points, as packed into columns.
    static func height(of section: ShortcutSection) -> Int {
        Int(headerHeight + CGFloat(section.entries.count) * rowHeight + sectionSpacing)
    }

    var columns: [[ShortcutSection]] {
        let shown = visibleSections
        let packed = ColumnPacker.pack(
            rowCounts: shown.map(Self.height(of:)), maxColumns: maxColumns,
            rowsPerColumn: Int(CGFloat(rowsPerColumn) * Self.rowHeight)
        )
        return packed.map { $0.map { shown[$0] } }
    }
}

struct OverlayView: View {
    @Bindable var model: OverlayModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            content
        }
        .padding(OverlayModel.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .onChange(of: model.mode, initial: true) { _, mode in searchFocused = mode == .pinned }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let icon = model.appIcon {
                Image(nsImage: icon).resizable().frame(width: 28, height: 28)
            }
            Text(model.appName).font(.title2.weight(.semibold)).lineLimit(1)
            if model.truncated {
                Text("Large menu: showing the first items read")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.mode == .pinned {
                TextField("Filter", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .focused($searchFocused)
            } else {
                Text("Click an item to run it").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(height: OverlayModel.titleBarHeight - 24)
    }

    @ViewBuilder private var content: some View {
        switch model.status {
        case .loading where model.sections.isEmpty:
            centered { ProgressView().controlSize(.small); Text("Reading menus…").foregroundStyle(.secondary) }
        case .unavailable where model.sections.isEmpty:
            centered { Text("\(model.appName) doesn't expose its menus to Accessibility.").foregroundStyle(.secondary) }
        default:
            if model.visibleSections.isEmpty {
                centered {
                    Text(model.query.isEmpty ? "No keyboard shortcuts in \(model.appName)'s menus." : "No matches.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: OverlayModel.columnSpacing) {
                        ForEach(Array(model.columns.enumerated()), id: \.offset) { _, column in
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(column) { section in sectionView(section) }
                            }
                            .frame(width: OverlayModel.columnWidth, alignment: .leading)
                        }
                    }
                }
                .scrollIndicators(.automatic)
            }
        }
    }

    private func sectionView(_ section: ShortcutSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .font(.headline)
                .frame(height: OverlayModel.headerHeight, alignment: .bottomLeading)
                .padding(.bottom, 2)
            ForEach(section.entries) { entry in
                EntryRow(entry: entry) { model.onChoose(entry) }
            }
        }
        .padding(.bottom, OverlayModel.sectionSpacing - 2)
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) { content() }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EntryRow: View {
    let entry: ShortcutEntry
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(entry.title).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 8)
                Text(entry.shortcut).font(.body.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, 6)
            .frame(height: OverlayModel.rowHeight)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 5).fill(hovering ? Color.accentColor.opacity(0.25) : .clear))
        }
        .buttonStyle(.plain)
        .opacity(entry.isEnabled ? 1 : 0.45)
        .onHover { hovering = $0 }
        .help(entry.isEnabled ? entry.title : "\(entry.title) (not available right now)")
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
