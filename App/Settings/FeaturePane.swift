import OmniCore
import OmniPlatform
import SwiftUI

/// One feature: switch, permission banner, shortcuts, its settings,
/// permissions, and Reset / Erase.
struct FeaturePane: View {
    let feature: any Feature
    let services: AppServices
    let navigation: SettingsNavigation
    @State private var confirmReset = false
    @State private var confirmErase = false

    private var status: FeatureRegistry.Status { services.features.status(of: feature.id) }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                header
                banner
                shortcuts
                Section(L10n.SettingsUI.settingsSection) {
                    if status == .running {
                        feature.makeSettingsView()
                    } else {
                        Text(L10n.Common.turnOnFeatureToChange(feature.displayName)).foregroundStyle(.secondary)
                    }
                }
                permissionRows
                footer
            }
            .formStyle(.grouped)
            .environment(\.settingsHighlight, navigation.highlight)
            .onChange(of: navigation.highlight, initial: true) { _, anchor in
                guard let anchor else { return }
                if OmniStyle.reduceMotion { proxy.scrollTo(anchor, anchor: .center) } else { withAnimation { proxy.scrollTo(anchor, anchor: .center) } }
            }
        }
    }

    private var header: some View {
        Section {
            Toggle(isOn: Binding(
                get: { services.features.isWanted(feature.id) },
                set: { services.features.setWanted($0, for: feature.id) }
            )) {
                VStack(alignment: .leading, spacing: OmniStyle.s1) {
                    Label(feature.displayName, systemImage: feature.symbolName).font(.title3.weight(.semibold)).symbolRenderingMode(.hierarchical)
                    Text(feature.summary).font(.callout).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
    }

    @ViewBuilder private var banner: some View {
        switch status {
        case let .waitingForPermissions(missing):
            ForEach(missing.sorted { $0.rawValue < $1.rawValue }) { permission in
                Section {
                    VStack(alignment: .leading, spacing: OmniStyle.s2) {
                        Label(L10n.SettingsUI.pausedBanner(permission.displayName, permission.explanation), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        HStack {
                            Button(L10n.Common.openSystemSettings) { Task { _ = await services.permissions.request(permission) } }
                                .buttonStyle(.borderedProminent)
                            Spacer()
                            Text(L10n.SettingsUI.updatesByItself).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        case let .failed(message):
            Section {
                Label(L10n.Status.problem(message), systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                Text(L10n.SettingsUI.problemTurnOffOn).font(.caption).foregroundStyle(.secondary)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var shortcuts: some View {
        if !feature.declaredHotkeys.isEmpty || !feature.gestures.isEmpty {
            Section(L10n.SettingsUI.shortcutsSection) {
                ForEach(feature.declaredHotkeys, id: \.id) { action in
                    ShortcutEditorRow(action: action, services: services).settingsAnchor("shortcut.\(action.id)")
                }
                ForEach(feature.gestures) { gesture in
                    HStack {
                        Text(gesture.title)
                        Spacer()
                        ShortcutChip(gesture.gesture)
                    }
                }
            }
        }
    }

    @ViewBuilder private var permissionRows: some View {
        let needed = feature.requiredPermissions.union(feature.optionalPermissions)
        if !needed.isEmpty {
            Section(L10n.SettingsUI.permissionsSection) {
                ForEach(Permission.allCases.filter(needed.contains)) { permission in
                    PermissionRow(
                        permission: permission, permissions: services.permissions,
                        note: feature.requiredPermissions.contains(permission) ? L10n.Permissions.required : L10n.Permissions.optional
                    )
                }
            }
        }
    }

    private var footer: some View {
        Section {
            HStack {
                Button(L10n.SettingsUI.resetToDefaults) { confirmReset = true }
                Spacer()
                if let description = feature.erasableDataDescription {
                    Button(L10n.SettingsUI.eraseData, role: .destructive) { confirmErase = true }
                        .foregroundStyle(.red)
                        .confirmationDialog(L10n.SettingsUI.eraseQuestion(description), isPresented: $confirmErase) {
                            Button(L10n.SettingsUI.erase, role: .destructive) { feature.eraseData() }
                            Button(L10n.Common.cancel, role: .cancel) {}
                        } message: {
                            Text(L10n.SettingsUI.cannotUndo)
                        }
                }
            }
            .confirmationDialog(L10n.SettingsUI.resetQuestion(feature.displayName), isPresented: $confirmReset) {
                Button(L10n.Common.reset) { services.resetToDefaults(feature) }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.SettingsUI.resetExplanation)
            }
        }
    }
}

/// A shortcut with its recorder, reset button and conflict warning.
struct ShortcutEditorRow: View {
    let action: HotkeyAction
    let services: AppServices

    var body: some View {
        let table = services.shortcutTable(includingHidden: true)
        let row = table.rows.first { $0.id == action.id }
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                if let warning = row.flatMap(ShortcutsPane.warning) {
                    Text(warning).font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            HotkeyRecorderView(combo: row?.combo) { combo in
                ShortcutsPane.rebind(action.id, to: combo, services: services, table: table)
            }
            Button { services.hotkeys.resetToDefaults([action.id]) } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(.borderless)
                .help(L10n.Common.resetToDefault)
                .accessibilityLabel(L10n.Common.resetToDefault)
                .disabled(row?.isDefault ?? true)
        }
    }
}
