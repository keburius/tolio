import OmniCore
import OmniPlatform
import SwiftUI

/// What the panel's controls do; implemented by `ControlPanelController`.
@MainActor
struct ControlPanelActions {
    var activate: (ControlPanelFocus.Target) -> Void
    var turnOn: (QuickAccessID) -> Void
    var menu: (QuickAccessID) -> [MenuEntry]
    var settingsShortcut: String
}

struct ControlPanelView: View {
    @Bindable var model: ControlPanelModel
    let actions: ControlPanelActions

    var body: some View {
        VStack(alignment: .leading, spacing: OmniStyle.s3) {
            header
            tiles
            if let id = model.turnOnPrompt, let tile = model.tiles.first(where: { $0.id == id }), case let .off(feature) = tile.state {
                turnOnRow(id: id, feature: feature)
            }
            clips
            windowSection
            Divider()
            footer
        }
        .frame(width: 368, alignment: .leading)
        .padding(OmniStyle.s4)
        .omniPanelBackground(material: .regularMaterial)
    }

    private var header: some View {
        HStack {
            Button { actions.activate(.settings) } label: { Text(L10n.App.name).font(.headline) }
                .buttonStyle(.plain)
                .help(L10n.App.settings)
            Spacer()
            if let shortcut = ShortcutLookupText.controlPanel { ShortcutChip(shortcut) }
        }
    }

    // MARK: Tiles

    private var tiles: some View {
        HStack(spacing: OmniStyle.s2) {
            ForEach(model.tiles) { tile in
                TileButton(tile: tile, focused: isFocused(.tile(tile.id))) { actions.activate(.tile(tile.id)) }
                    .contextMenu { MenuEntriesView(entries: tileMenu(tile)) }
            }
        }
    }

    private func tileMenu(_ tile: ControlPanelModel.Tile) -> [MenuEntry] {
        if case .off = tile.state { return [] }
        return actions.menu(tile.id)
    }

    private func turnOnRow(id: QuickAccessID, feature: String) -> some View {
        HStack {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            Text(L10n.App.featureIsOff(feature)).font(.callout)
            Spacer()
            Button(L10n.Common.turnOn) { actions.turnOn(id) }.controlSize(.small)
        }
        .padding(OmniStyle.s2)
        .omniPanelBackground(radius: OmniStyle.controlRadius, material: .thinMaterial)
    }

    // MARK: Clips

    @ViewBuilder private var clips: some View {
        VStack(alignment: .leading, spacing: OmniStyle.s1) {
            HStack {
                SectionHeader(L10n.Panel.recentlyCopied)
                Spacer()
                if case .items = model.clips {
                    Button(L10n.Panel.showAll) { actions.activate(.showAllClips) }
                        .buttonStyle(.link).font(.caption)
                        .overlay(focusRing(.showAllClips))
                }
            }
            switch model.clips {
            case let .items(results):
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    ClipRow(index: index, result: result, focused: isFocused(.recent(index))) { actions.activate(.recent(index)) }
                }
            case .empty:
                Text(L10n.Panel.nothingCopied).font(.callout).foregroundStyle(.secondary).padding(.vertical, OmniStyle.s1)
            case let .featureOff(name):
                HStack {
                    Text(L10n.Panel.turnOnToSeeClips(name)).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.Common.turnOn) { actions.turnOn(.clipboard) }.controlSize(.small)
                }
            }
        }
    }

    // MARK: Window layouts

    @ViewBuilder private var windowSection: some View {
        VStack(alignment: .leading, spacing: OmniStyle.s2) {
            switch model.window {
            case let .window(app, title):
                SectionHeader(L10n.Panel.windowSection)
                Text(title.map { L10n.Panel.windowTitle(app, $0) } ?? app).font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                LayoutGrid(layouts: model.layouts, focused: model.showsFocusRing ? model.focus.current : nil) { actions.activate(.layout($0)) }
            case .none:
                SectionHeader(L10n.Panel.windowSection)
                Text(L10n.Panel.noWindow).font(.callout).foregroundStyle(.secondary)
            case let .featureOff(name):
                SectionHeader(L10n.Panel.windowSection)
                HStack {
                    Text(L10n.Panel.turnOnToArrange(name)).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.Common.turnOn) { actions.turnOn(.windowLayouts) }.controlSize(.small)
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: OmniStyle.s2) {
            if let stats = model.statsLine {
                Text(stats).font(.caption.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack {
                Button { actions.activate(.settings) } label: {
                    HStack(spacing: OmniStyle.s1) { Text(L10n.App.settings); ShortcutChip(actions.settingsShortcut) }
                }
                .buttonStyle(.borderless)
                .overlay(focusRing(.settings))
                Spacer()
                Button { actions.activate(.quit) } label: {
                    HStack(spacing: OmniStyle.s1) { Text(L10n.App.quit); ShortcutChip("⌘Q") } // l10n-ignore
                }
                .buttonStyle(.borderless)
                .overlay(focusRing(.quit))
            }
        }
    }

    private func isFocused(_ target: ControlPanelFocus.Target) -> Bool {
        model.showsFocusRing && model.focus.current == target
    }

    @ViewBuilder private func focusRing(_ target: ControlPanelFocus.Target) -> some View {
        if isFocused(target) {
            RoundedRectangle(cornerRadius: OmniStyle.controlRadius).strokeBorder(Color.accentColor, lineWidth: 2).padding(-3)
        }
    }
}

/// The control panel's own shortcut, set by the controller when it opens.
@MainActor
enum ShortcutLookupText {
    static var controlPanel: String?
}

private struct TileButton: View {
    let tile: ControlPanelModel.Tile
    let focused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: OmniStyle.s1) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: symbol).font(.system(size: 20)).frame(height: 24)
                    if case .needsPermission = tile.state {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9)).foregroundStyle(.orange).offset(x: 8, y: -4)
                    }
                }
                Text(title).font(.caption.weight(.medium)).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
                Text(subtitle).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(width: 66, height: 78)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: OmniStyle.cardRadius).fill(background))
        .overlay {
            RoundedRectangle(cornerRadius: OmniStyle.cardRadius)
                .strokeBorder(focused ? Color.accentColor : Color(nsColor: .separatorColor).opacity(OmniStyle.increaseContrast ? 1 : 0.4), lineWidth: focused ? 2 : 1)
        }
        .opacity(isOff ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, subtitle].joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }

    private var isOff: Bool { if case .off = tile.state { true } else { false } }

    private var symbol: String {
        if case .ready(true, _) = tile.state, tile.id == .keepAwake { return "cup.and.saucer.fill" }
        if case .recording = tile.state { return "stop.circle.fill" }
        return tile.symbol
    }

    private var title: String {
        if case let .recording(elapsed) = tile.state { return L10n.Panel.stop(elapsed) }
        return tile.title
    }

    private var subtitle: String {
        switch tile.state {
        case .off: L10n.Common.off
        case .needsPermission: L10n.Status.needsPermission
        case let .ready(_, detail): detail ?? tile.shortcut ?? ""
        case .recording: tile.shortcut ?? ""
        }
    }

    private var background: Color {
        switch tile.state {
        case .ready(true, _): Color.accentColor.opacity(0.22)
        case .recording: Color.red.opacity(0.22)
        default: Color.primary.opacity(0.05)
        }
    }
}

private struct ClipRow: View {
    let index: Int
    let result: SearchResult
    let focused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: OmniStyle.s2) {
                Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 12)
                icon.frame(width: 20, height: 20)
                Text(result.title).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: OmniStyle.s2)
                if let subtitle = result.subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            .padding(.horizontal, OmniStyle.s1)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: OmniStyle.controlRadius).fill(focused ? Color.accentColor.opacity(0.2) : .clear))
    }

    @ViewBuilder private var icon: some View {
        switch result.icon {
        case let .symbol(name): Image(systemName: name).foregroundStyle(.secondary)
        case let .file(url): Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
        case let .image(url):
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 3))
            }
            else { Image(systemName: "photo").foregroundStyle(.secondary) }
        }
    }
}

/// Six small window-layout buttons, each drawn as a screen with the window's place.
struct LayoutGrid: View {
    let layouts: [ControlPanelModel.Layout]
    let focused: ControlPanelFocus.Target?
    let action: (String) -> Void

    var body: some View {
        // Buttons share the row's width, so the grid never pushes the panel wider.
        HStack(spacing: OmniStyle.s1) {
            ForEach(layouts) { layout in
                Button { action(layout.id) } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).strokeBorder(.secondary, lineWidth: 1)
                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 2).fill(Color.accentColor)
                                    .frame(width: max(2, geometry.size.width * layout.span.width - 2))
                                    .offset(x: geometry.size.width * layout.span.x + 1)
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(width: 40, height: 24)
                        Text(layout.title).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                        if let shortcut = layout.shortcut { Text(shortcut).font(.caption2.monospacedDigit()).foregroundStyle(.secondary) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if focused == .layout(layout.id) {
                        RoundedRectangle(cornerRadius: OmniStyle.controlRadius).strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                }
                .help(layout.title)
            }
        }
    }
}

/// SwiftUI rendering of a feature's options menu (for right-click on tiles).
struct MenuEntriesView: View {
    let entries: [MenuEntry]

    var body: some View {
        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
            switch entry {
            case .separator: Divider()
            case let .header(text): Text(text)
            case let .submenu(title, children): Menu(title) { MenuEntriesView(entries: children) }
            case let .action(action):
                Button {
                    if let question = action.confirmation, !MenuBuilder.confirm(question) { return }
                    action.perform()
                } label: {
                    if action.isChecked { Label(action.title, systemImage: "checkmark") } else { Text(action.title) }
                }
                .disabled(!action.isEnabled)
            }
        }
    }
}
