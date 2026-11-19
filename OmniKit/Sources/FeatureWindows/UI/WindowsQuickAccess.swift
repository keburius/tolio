import OmniCore
import OmniPlatform
import SwiftUI

extension WindowsFeature {
    /// The Window Layouts menu bar icon and control panel tile.
    ///
    /// Left-clicking the icon shows the app's own small layout grid (built by
    /// the app from `WindowAction`), so `primary` does nothing here.
    public var quickAccessItems: [QuickAccessItem] {
        [
            QuickAccessItem(
                id: .windowLayouts, title: displayName, symbolName: symbolName,
                clickHint: L10n.Windows.clickHint, shortcutID: nil,
                primary: {},
                menu: { [weak self] in self?.quickAccessMenu() ?? [] }
            ),
        ]
    }

    /// Every layout with its shortcut, then the gap and drag-to-edge options.
    func quickAccessMenu() -> [MenuEntry] {
        let manager = self.manager
        var entries: [MenuEntry] = WindowAction.allCases.map { action in
            .action(MenuAction(action.title, shortcutID: action.hotkeyID) { manager?.perform(action) })
        }
        entries.append(.separator)
        let gap = settings?.value(Self.gapKey) ?? Self.gapKey.defaultValue
        entries.append(.submenu(title: L10n.Windows.gapMenu, entries: Self.gapChoices.map { points in
            .action(MenuAction(Self.gapTitle(points), isChecked: points == gap) { [weak self] in
                self?.settings?.set(points, for: Self.gapKey)
            })
        }))
        let dragOn = settings?.value(Self.dragSnapKey) ?? Self.dragSnapKey.defaultValue
        entries.append(.action(MenuAction(L10n.Windows.dragToEdgeMenu, isChecked: dragOn) { [weak self] in
            self?.setDragSnapping(!dragOn)
        }))
        return entries
    }
}

struct WindowsSettingsView: View {
    enum Tab: Hashable { case shortcuts, settings }

    let feature: WindowsFeature
    let settings: SettingsStore
    @State private var tab = Tab.shortcuts
    @Environment(\.settingsHighlight) private var highlight

    /// Left column: halves and thirds. Right column: quarters and the rest.
    private static let columns: [[WindowAction]] = [
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf, .firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds],
        [.topLeft, .topRight, .bottomLeft, .bottomRight, .maximize, .center, .nextDisplay, .previousDisplay, .restore],
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ASSegmented(L10n.Windows.tabsLabel, selection: $tab, options: [
                (Tab.shortcuts, L10n.Windows.tabShortcuts), (Tab.settings, L10n.Windows.tabSettings),
            ], size: .wide)
            switch tab {
            case .shortcuts: shortcutGrid
            case .settings: settingsTab
            }
        }
        .onChange(of: highlight, initial: true) { _, anchor in
            // Settings search points at a control on the other tab: show it.
            if anchor == WindowsFeature.Anchor.gap || anchor == WindowsFeature.Anchor.dragToEdge { tab = .settings }
        }
    }

    private var shortcutGrid: some View {
        let bindings = settings.value(HotkeyManager.bindingsKey)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(Self.columns.indices, id: \.self) { column in
                    ASCard {
                        ASDividedStack {
                            ForEach(Self.columns[column], id: \.self) { action in
                                LayoutShortcutRow(action: action, combo: bindings.combo(for: action.hotkey))
                            }
                        }
                    }
                }
            }
            ASFootnote(L10n.Windows.gridHelp)
        }
    }

    private var settingsTab: some View {
        ASSection {
            ASRow(L10n.Windows.gap) {
                ASPopUp(
                    L10n.Windows.gap, selection: settings.binding(WindowsFeature.gapKey),
                    options: WindowsFeature.gapChoices.map { ($0, WindowsFeature.gapTitle($0)) }
                )
            }
            .settingsAnchor(WindowsFeature.Anchor.gap)
            VStack(alignment: .leading, spacing: 0) {
                ASToggleRow(L10n.Windows.dragToEdge, subtitle: L10n.Windows.dragToEdgeHelp, isOn: Binding(
                    get: { settings.value(WindowsFeature.dragSnapKey) },
                    set: { feature.setDragSnapping($0) }
                ))
                if let error = feature.dragError {
                    Text(error).font(AS.footnote).foregroundStyle(AS.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding([.horizontal, .bottom], 12)
                }
            }
            .settingsAnchor(WindowsFeature.Anchor.dragToEdge)
        }
    }
}

/// One layout in the shortcut grid: its picture, name and keys.
private struct LayoutShortcutRow: View {
    let action: WindowAction
    let combo: KeyCombo?
    @Environment(\.shortcutEditor) private var editor

    var body: some View {
        HStack(spacing: 10) {
            LayoutPictogram(action: action)
            Text(action.title).font(AS.body).foregroundStyle(AS.text).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let editor {
                editor(action.hotkey.id)
            } else {
                staticKeys
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(height: 34)
        .accessibilityElement(children: .contain)
    }

    private var staticKeys: some View {
            Group {
                if let combo {
                    KeyCaps(combo.displayString, spacing: 3)
                } else {
                    Text(L10n.Windows.noShortcut).font(AS.footnote).foregroundStyle(AS.textTertiary).padding(.horizontal, 3)
                }
            }
            .padding(.horizontal, 5)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.black.opacity(0.22)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }
}

/// A small screen outline with the layout's area filled (24×16 grid).
struct LayoutPictogram: View {
    static let tint = Color(hex: 0xBD71E4)
    let action: WindowAction

    var body: some View {
        Canvas { context, _ in
            if let area {
                context.fill(Path(roundedRect: area, cornerRadius: 1.5, style: .continuous), with: .color(Self.tint))
            } else if let arrow {
                context.stroke(SVGPath(arrow, viewBox: CGSize(width: 24, height: 16)).path(in: CGRect(x: 0, y: 0, width: 24, height: 16)),
                               with: .color(Self.tint), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
            context.stroke(Path(roundedRect: CGRect(x: 1, y: 1, width: 22, height: 14), cornerRadius: 2.5, style: .continuous),
                           with: .color(.white.opacity(0.40)), lineWidth: 1.2)
        }
        .frame(width: 24, height: 16)
        .accessibilityHidden(true)
    }

    private var area: CGRect? {
        switch action {
        case .leftHalf: CGRect(x: 1.5, y: 1.5, width: 10.5, height: 13)
        case .rightHalf: CGRect(x: 12, y: 1.5, width: 10.5, height: 13)
        case .topHalf: CGRect(x: 1.5, y: 1.5, width: 21, height: 6.5)
        case .bottomHalf: CGRect(x: 1.5, y: 8, width: 21, height: 6.5)
        case .firstThird: CGRect(x: 1.5, y: 1.5, width: 7, height: 13)
        case .centerThird: CGRect(x: 8.5, y: 1.5, width: 7, height: 13)
        case .lastThird: CGRect(x: 15.5, y: 1.5, width: 7, height: 13)
        case .firstTwoThirds: CGRect(x: 1.5, y: 1.5, width: 14, height: 13)
        case .lastTwoThirds: CGRect(x: 8.5, y: 1.5, width: 14, height: 13)
        case .topLeft: CGRect(x: 1.5, y: 1.5, width: 10.5, height: 6.5)
        case .topRight: CGRect(x: 12, y: 1.5, width: 10.5, height: 6.5)
        case .bottomLeft: CGRect(x: 1.5, y: 8, width: 10.5, height: 6.5)
        case .bottomRight: CGRect(x: 12, y: 8, width: 10.5, height: 6.5)
        case .maximize: CGRect(x: 1.5, y: 1.5, width: 21, height: 13)
        case .center: CGRect(x: 5.7, y: 3.84, width: 12.6, height: 8.32)
        case .nextDisplay, .previousDisplay, .restore: nil
        }
    }

    private var arrow: String? {
        switch action {
        case .nextDisplay: "M7 8h10M13.5 4.8L17 8l-3.5 3.2"
        case .previousDisplay: "M17 8H7M10.5 4.8L7 8l3.5 3.2"
        case .restore: "M9 5.5L6.5 8 9 10.5M6.5 8h7a2.6 2.6 0 0 1 0 5.2"
        default: nil
        }
    }
}

/// The example at the top of the page: a window snapped to the left half.
struct WindowsHero: View {
    var body: some View {
        ASStage(tint: LayoutPictogram.tint.opacity(0.22 / 0.30)) {
            HStack(spacing: 6) {
                pane(filled: true)
                pane(filled: false)
            }
            .padding(8)
            .frame(width: 250, height: 132)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0x15161B)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Windows.heroLabel)
        .accessibilityAddTraits(.isImage)
    }

    private func pane(filled: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { _ in
                Circle().fill(filled ? Color.white : Color.white.opacity(0.5)).frame(width: 5, height: 5)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(filled ? LayoutPictogram.tint : Color.white.opacity(0.10)))
    }
}
