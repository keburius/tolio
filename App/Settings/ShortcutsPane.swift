import OmniCore
import OmniPlatform
import SwiftUI

@MainActor
extension AppServices {
    /// Every declared shortcut (features on or off) plus the app's own.
    func shortcutTable(includingHidden: Bool) -> ShortcutTable {
        var sources = [ShortcutTable.Source(action: AppHotkeys.controlPanel, featureID: AppHotkeys.owner, featureName: L10n.App.name, featureIsOn: true)]
        for feature in visibleFeatures(includingHidden: includingHidden) {
            let isOn = features.status(of: feature.id) == .running
            sources += feature.declaredHotkeys.map {
                ShortcutTable.Source(action: $0, featureID: feature.id, featureName: feature.displayName, featureIsOn: isOn)
            }
        }
        return ShortcutTable(sources: sources, bindings: hotkeys.bindings, refused: hotkeys.refusedActionIDs)
    }
}

/// Every shortcut as key caps you click to change: one per feature, then
/// Window Layouts' own, with conflict warnings and Reset to Defaults.
struct ShortcutsPane: View {
    let services: AppServices
    let navigation: SettingsNavigation
    @State private var confirmResetAll = false

    /// One line on the page.
    private struct Item: Identifiable {
        enum Kind { case hotkey(ShortcutTable.Row), gesture(GestureShortcut) }
        let id: String
        let title: String
        let featureID: FeatureID
        let isOn: Bool
        let kind: Kind
    }

    var body: some View {
        let table = services.shortcutTable(includingHidden: navigation.showsHiddenFeatures)
        let (featureItems, layoutItems) = items(table)
        PageScaffold(L10n.SettingsUI.shortcuts) {
            Text(L10n.ShortcutsUI.intro).font(AS.body).foregroundStyle(AS.textBody)
            section(L10n.AllSet.features, featureItems, table)
            if !layoutItems.isEmpty {
                section(services.features.feature("windows")?.displayName ?? L10n.Windows.displayName, layoutItems, table)
            }
            HStack {
                Text(L10n.SettingsUI.offNote).font(AS.footnote).foregroundStyle(AS.textTertiary)
                Spacer()
                Button(L10n.SettingsUI.resetToDefaults) { confirmResetAll = true }
                    .buttonStyle(.asSecondary)
                    .confirmationDialog(L10n.SettingsUI.resetAllShortcutsQuestion, isPresented: $confirmResetAll) {
                        Button(L10n.Common.reset) { services.hotkeys.resetToDefaults(table.rows.map(\.id)) }
                        Button(L10n.Common.cancel, role: .cancel) {}
                    }
            }
        }
    }

    /// Feature shortcuts (one per feature, or each action when a feature has
    /// several), the control panel, then Window Layouts' actions separately.
    private func items(_ table: ShortcutTable) -> ([Item], [Item]) {
        var main: [Item] = []
        var layouts: [Item] = []
        for feature in services.sidebarFeatures(includingHidden: navigation.showsHiddenFeatures) {
            let isOn = services.features.status(of: feature.id) == .running
            let rows = feature.declaredHotkeys.compactMap { action in table.rows.first { $0.id == action.id } }
            let single = rows.count + feature.gestures.count == 1
            var lines = rows.map { Item(id: $0.id, title: single ? feature.displayName : $0.title, featureID: feature.id, isOn: isOn, kind: .hotkey($0)) }
            lines += feature.gestures.map { Item(id: "gesture.\($0.id)", title: single ? feature.displayName : $0.title, featureID: feature.id, isOn: isOn, kind: .gesture($0)) }
            if feature.id == "windows" { layouts += lines } else { main += lines }
        }
        if let row = table.rows.first(where: { $0.id == AppHotkeys.controlPanel.id }) {
            main.append(Item(id: row.id, title: L10n.ShortcutsUI.controlPanel, featureID: AppHotkeys.owner, isOn: true, kind: .hotkey(row)))
        }
        return (main, layouts)
    }

    private func section(_ title: String, _ items: [Item], _ table: ShortcutTable) -> some View {
        let half = (items.count + 1) / 2
        return VStack(alignment: .leading, spacing: 6) {
            ASSectionTitle(title)
            HStack(alignment: .top, spacing: 12) {
                column(Array(items.prefix(half)), table)
                column(Array(items.dropFirst(half)), table)
            }
        }
    }

    private func column(_ items: [Item], _ table: ShortcutTable) -> some View {
        ASCard {
            ASDividedStack {
                ForEach(items) { item in line(item, table) }
            }
        }
    }

    private func line(_ item: Item, _ table: ShortcutTable) -> some View {
        HStack(spacing: 10) {
            if item.featureID == AppHotkeys.owner {
                LineIconTile(ASIcon.menuBar, size: 22, iconSize: 13)
            } else {
                FeatureIcon(item.featureID, size: 22)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(AS.body).foregroundStyle(item.isOn ? AS.text : AS.textTertiary).lineLimit(1)
                if case let .hotkey(row) = item.kind, let warning = Self.warning(for: row) {
                    Text(warning).font(.system(size: 10.5)).foregroundStyle(AS.orange).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            switch item.kind {
            case let .hotkey(row):
                if !row.isDefault {
                    Button { services.hotkeys.resetToDefaults([row.id]) } label: {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AS.textSecondary)
                    .help(L10n.Common.resetToDefault)
                    .accessibilityLabel(L10n.Common.resetToDefault)
                }
                HotkeyRecorderView(combo: row.combo) { Self.rebind(row.id, to: $0, services: services, table: table) }
                    .padding(.horizontal, 2)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.black.opacity(0.22)))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                    .help(L10n.ShortcutsUI.change(item.title))
            case let .gesture(gesture):
                Button {
                    navigation.open(.feature(item.featureID), anchor: gesture.settingsAnchor)
                } label: {
                    KeyCaps(gesture.gesture, spacing: 3)
                        .padding(.horizontal, 5)
                        .frame(height: 26)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.black.opacity(0.22)))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(L10n.Common.featureSettings(item.title))
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(minHeight: 36)
        .settingsAnchor("shortcut.\(item.id)")
    }

    static func warning(for row: ShortcutTable.Row) -> String? {
        switch row.status {
        case .ok, .unassigned: nil
        case let .conflict(other, otherIsOn): otherIsOn && row.featureIsOn ? L10n.SettingsUI.sameAs(other) : L10n.SettingsUI.sameAsOff(other)
        case .usedByAnotherApp: L10n.SettingsUI.usedByAnotherApp
        }
    }

    /// Rebinds; returns a message for the recorder if refused.
    static func rebind(_ id: String, to combo: KeyCombo?, services: AppServices, table: ShortcutTable) -> String? {
        if let combo, let owner = table.owner(of: combo, excluding: id) {
            return L10n.SettingsUI.alreadyUsedBy(owner.title)
        }
        switch services.hotkeys.rebind(id, to: combo) {
        case .ok: return nil
        case let .invalid(issue): return issue.message
        case let .conflict(title): return L10n.SettingsUI.alreadyUsedBy(title)
        case .systemRefused: return L10n.SettingsUI.refusedByMac
        }
    }
}
