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

/// All shortcuts in one table with conflict warnings, plus gestures.
struct ShortcutsPane: View {
    let services: AppServices
    let navigation: SettingsNavigation
    @State private var filter = ""
    @State private var onlyOn = false
    @State private var confirmResetAll = false

    var body: some View {
        let table = services.shortcutTable(includingHidden: navigation.showsHiddenFeatures)
        let rows = table.rows.filter(matches)
        VStack(alignment: .leading, spacing: OmniStyle.s3) {
            HStack {
                Text(L10n.SettingsUI.shortcuts).font(.title2.weight(.semibold))
                Spacer()
                Picker("", selection: $onlyOn) { // l10n-ignore
                    Text(L10n.SettingsUI.showAll).tag(false)
                    Text(L10n.SettingsUI.showOnOnly).tag(true)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                TextField(L10n.SettingsUI.filter, text: $filter).textFieldStyle(.roundedBorder).frame(width: 160)
            }
            if rows.isEmpty {
                EmptyState(symbol: "keyboard", message: L10n.SettingsUI.noShortcutsMatch(filter))
            } else {
                Table(rows) {
                    TableColumn(L10n.SettingsUI.action) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: OmniStyle.s1) {
                                if Self.warning(for: row) != nil { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                                Text(row.title)
                            }
                            if let warning = Self.warning(for: row) { Text(warning).font(.caption).foregroundStyle(.orange) }
                        }
                        .foregroundStyle(row.featureIsOn ? .primary : .secondary)
                    }
                    TableColumn(L10n.SettingsUI.feature) { row in
                        Text(row.featureIsOn ? row.featureName : "\(row.featureName) \(L10n.SettingsUI.featureOffSuffix)")
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 120, ideal: 160)
                    TableColumn(L10n.SettingsUI.shortcut) { row in
                        HStack {
                            HotkeyRecorderView(combo: row.combo) { Self.rebind(row.id, to: $0, services: services, table: table) }
                            Button { services.hotkeys.resetToDefaults([row.id]) } label: { Image(systemName: "arrow.uturn.backward") }
                                .buttonStyle(.borderless).disabled(row.isDefault)
                                .help(L10n.Common.resetToDefault).accessibilityLabel(L10n.Common.resetToDefault)
                        }
                    }
                    .width(min: 170, ideal: 190)
                }
                .frame(minHeight: 260)
            }
            gestures
            HStack {
                Text(L10n.SettingsUI.offNote).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L10n.SettingsUI.resetAllShortcuts) { confirmResetAll = true }
                    .confirmationDialog(L10n.SettingsUI.resetAllShortcutsQuestion, isPresented: $confirmResetAll) {
                        Button(L10n.Common.reset) { services.hotkeys.resetToDefaults(table.rows.map(\.id)) }
                        Button(L10n.Common.cancel, role: .cancel) {}
                    }
            }
        }
        .padding(OmniStyle.s5)
    }

    @ViewBuilder private var gestures: some View {
        let items = services.visibleFeatures(includingHidden: navigation.showsHiddenFeatures).flatMap { feature in
            feature.gestures.map { (feature, $0) }
        }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: OmniStyle.s1) {
                SectionHeader(L10n.SettingsUI.gestures)
                ForEach(items, id: \.1.id) { feature, gesture in
                    HStack {
                        Text(gesture.title)
                        Text(feature.displayName).foregroundStyle(.secondary)
                        Spacer()
                        ShortcutChip(gesture.gesture)
                        Button { navigation.open(.feature(feature.id), anchor: gesture.settingsAnchor) } label: { Image(systemName: "arrow.right.circle") }
                            .buttonStyle(.borderless).help(L10n.Common.featureSettings(feature.displayName))
                    }
                }
            }
        }
    }

    private func matches(_ row: ShortcutTable.Row) -> Bool {
        if onlyOn && !row.featureIsOn { return false }
        let needle = filter.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }
        return row.title.localizedCaseInsensitiveContains(needle) || row.featureName.localizedCaseInsensitiveContains(needle)
            || (row.combo?.displayString.localizedCaseInsensitiveContains(needle) ?? false)
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
