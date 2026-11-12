import OmniCore
import OmniPlatform
import SwiftUI

/// Which quick-access icons show, their order, or one icon only.
struct MenuBarPane: View {
    let services: AppServices
    let entries: () -> [QuickAccessID: MenuBarController.Entry]

    private var config: MenuBarConfiguration { services.settings.value(MenuBarConfiguration.key) }

    private func update(_ change: (inout MenuBarConfiguration) -> Void) {
        var copy = config
        change(&copy)
        services.settings.set(copy, for: MenuBarConfiguration.key)
    }

    var body: some View {
        let all = entries()
        Form {
            Section(L10n.SettingsUI.iconsInMenuBar) {
                Picker(L10n.SettingsUI.iconsInMenuBar, selection: Binding(get: { config.mode }, set: { mode in update { $0.mode = mode } })) {
                    Text(L10n.SettingsUI.separateIcons).tag(MenuBarConfiguration.Mode.separate)
                    Text(L10n.SettingsUI.oneIcon).tag(MenuBarConfiguration.Mode.single)
                }
                .pickerStyle(.radioGroup).labelsHidden()
            }
            .settingsAnchor("menubar.mode")
            Section {
                List {
                    ForEach(config.entries, id: \.id) { entry in
                        if let info = all[entry.id] { row(entry, info) }
                    }
                    .onMove { source, destination in update { $0.move(fromOffsets: source, toOffset: destination) } }
                }
                .frame(minHeight: CGFloat(config.entries.count) * 44)
                .disabled(config.mode == .single)
                .opacity(config.mode == .single ? 0.5 : 1)
            } header: {
                Text(L10n.SettingsUI.quickActions)
            } footer: {
                Text(L10n.SettingsUI.quickActionsHelp).font(.caption).foregroundStyle(.secondary)
            }
            .settingsAnchor("menubar.items")
            Section {
                Text(L10n.SettingsUI.statsNote).font(.callout).foregroundStyle(.secondary)
                Text(L10n.SettingsUI.notchNote).font(.callout).foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Spacer()
                    Button(L10n.SettingsUI.resetToDefaults) { services.settings.reset(MenuBarConfiguration.key) }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ entry: MenuBarConfiguration.Entry, _ info: MenuBarController.Entry) -> some View {
        let isOn = services.features.status(of: info.feature.id) == .running
        return HStack(spacing: OmniStyle.s2) {
            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary).accessibilityHidden(true)
            Toggle(info.item.title, isOn: Binding(
                get: { entry.isVisible },
                set: { visible in update { $0.setVisible(visible, for: entry.id) } }
            ))
            .toggleStyle(.checkbox).labelsHidden()
            Image(systemName: info.item.symbolName).frame(width: 20)
            Text(info.item.title)
            Spacer()
            if isOn {
                Text(L10n.SettingsUI.clickDoes(info.item.clickHint)).font(.caption).foregroundStyle(.secondary)
            } else {
                Text(L10n.App.featureIsOff(info.feature.displayName)).font(.caption).foregroundStyle(.secondary)
                Button(L10n.Common.turnOn) { services.features.setWanted(true, for: info.feature.id) }.controlSize(.small)
            }
        }
        .contextMenu {
            Button(L10n.SettingsUI.moveLeft) { update { $0.move(entry.id, by: -1) } }
            Button(L10n.SettingsUI.moveRight) { update { $0.move(entry.id, by: 1) } }
        }
        .accessibilityAction(named: Text(L10n.SettingsUI.moveLeft)) { update { $0.move(entry.id, by: -1) } }
        .accessibilityAction(named: Text(L10n.SettingsUI.moveRight)) { update { $0.move(entry.id, by: 1) } }
    }
}
