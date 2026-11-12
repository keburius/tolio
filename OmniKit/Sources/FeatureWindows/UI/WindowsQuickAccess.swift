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
    let feature: WindowsFeature
    let settings: SettingsStore

    var body: some View {
        Picker(L10n.Windows.gap, selection: settings.binding(WindowsFeature.gapKey)) {
            ForEach(WindowsFeature.gapChoices, id: \.self) { Text(WindowsFeature.gapTitle($0)).tag($0) }
        }
        .settingsAnchor(WindowsFeature.Anchor.gap)
        Toggle(L10n.Windows.dragToEdge, isOn: Binding(
            get: { settings.value(WindowsFeature.dragSnapKey) },
            set: { feature.setDragSnapping($0) }
        ))
        .settingsAnchor(WindowsFeature.Anchor.dragToEdge)
        Text(L10n.Windows.dragToEdgeHelp)
            .font(.caption).foregroundStyle(.secondary)
        if let error = feature.dragError {
            Text(error).font(.caption).foregroundStyle(.red)
        }
        Text(L10n.Windows.shortcutsHelp)
            .font(.caption).foregroundStyle(.secondary)
    }
}
