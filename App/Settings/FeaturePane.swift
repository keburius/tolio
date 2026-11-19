import OmniCore
import OmniPlatform
import SwiftUI

/// One feature's page: icon, name, main shortcut and switch; its example
/// illustration; its own settings; shortcuts; permissions; Reset / Erase.
struct FeaturePane: View {
    let feature: any Feature
    let services: AppServices
    let navigation: SettingsNavigation
    @State private var confirmReset = false
    @State private var confirmErase = false

    private var status: FeatureRegistry.Status { services.features.status(of: feature.id) }

    var body: some View {
        ScrollViewReader { proxy in
            PageScaffold(feature.displayName) {
                header(proxy)
                banner
                if let hero = feature.makeSettingsHero() { hero }
                if status == .running {
                    feature.makeSettingsView()
                } else {
                    ASCard(padding: 12) {
                        Text(L10n.AllSet.turnOnToChange).font(AS.body).foregroundStyle(AS.textSecondary)
                    }
                }
                shortcuts
                permissionCard
                footer
            }
            .environment(\.settingsHighlight, navigation.highlight)
            .environment(\.shortcutEditor) { [services] id in
                AnyView(ShortcutPill(id: id, services: services))
            }
            .onChange(of: navigation.highlight, initial: true) { _, anchor in
                guard let anchor else { return }
                if OmniStyle.reduceMotion { proxy.scrollTo(anchor, anchor: .center) } else { withAnimation { proxy.scrollTo(anchor, anchor: .center) } }
            }
        }
    }

    private func header(_ proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 14) {
            FeatureIcon(feature.id, size: 48, fallbackSymbol: feature.symbolName)
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.displayName).font(AS.heroTitle).tracking(-0.2).foregroundStyle(AS.text)
                Text(feature.summary).font(AS.body).foregroundStyle(AS.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let action = feature.declaredHotkeys.first, let shortcut = services.mainShortcutText(of: feature) {
                Button {
                    navigation.open(.feature(feature.id), anchor: "shortcut.\(action.id)")
                } label: {
                    KeyCaps(shortcut, spacing: 4)
                }
                .buttonStyle(.plain)
                .help(L10n.AllSet.changeShortcut(action.title))
                .accessibilityLabel(L10n.AllSet.changeShortcut(action.title))
            } else if let gesture = feature.gestures.first {
                KeyCaps(gesture.gesture, spacing: 4)
            }
            ASSwitch(feature.displayName, isOn: Binding(
                get: { services.features.isWanted(feature.id) },
                set: { services.features.setWanted($0, for: feature.id) }
            ))
        }
    }

    @ViewBuilder private var banner: some View {
        switch status {
        case let .waitingForPermissions(missing):
            ForEach(missing.sorted { $0.rawValue < $1.rawValue }) { permission in
                ASCard(padding: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        LineIcon(ASIcon.warning, size: 14, lineWidth: 2, color: AS.orange).padding(.top, 1)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.SettingsUI.pausedBanner(permission.displayName, permission.explanation))
                                .font(AS.body).foregroundStyle(AS.text).fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Button(L10n.Common.openSystemSettings) { Task { _ = await services.permissions.request(permission) } }
                                    .buttonStyle(.asPrimary)
                                Text(L10n.SettingsUI.updatesByItself).font(AS.footnote).foregroundStyle(AS.textTertiary)
                            }
                        }
                    }
                }
            }
        case let .failed(message):
            ASCard(padding: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    ASStatusLabel(.problem, L10n.Status.problem(message), fontSize: 13)
                    Text(L10n.SettingsUI.problemTurnOffOn).font(AS.footnote).foregroundStyle(AS.textTertiary)
                }
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var shortcuts: some View {
        if !feature.settingsViewEditsShortcuts, !feature.declaredHotkeys.isEmpty || !feature.gestures.isEmpty {
            ASSection(L10n.AllSet.shortcutsSection) {
                ForEach(feature.declaredHotkeys, id: \.id) { action in
                    ShortcutEditorRow(action: action, services: services).settingsAnchor("shortcut.\(action.id)")
                }
                ForEach(feature.gestures) { gesture in
                    ASRow(gesture.title) { KeyCaps(gesture.gesture) }
                }
            }
        }
    }

    @ViewBuilder private var permissionCard: some View {
        let needed = feature.requiredPermissions.union(feature.optionalPermissions)
        if !needed.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ASSectionTitle(L10n.SettingsUI.permissionsSection)
                VStack(spacing: 8) {
                    ForEach(Permission.allCases.filter(needed.contains)) { permission in
                        FeaturePermissionCard(
                            permission: permission, permissions: services.permissions,
                            isRequired: feature.requiredPermissions.contains(permission)
                        )
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(L10n.SettingsUI.resetToDefaults) { confirmReset = true }
                .buttonStyle(.asSecondary)
                .confirmationDialog(L10n.SettingsUI.resetQuestion(feature.displayName), isPresented: $confirmReset) {
                    Button(L10n.Common.reset) { services.resetToDefaults(feature) }
                    Button(L10n.Common.cancel, role: .cancel) {}
                } message: {
                    Text(L10n.SettingsUI.resetExplanation)
                }
            Spacer()
            if let description = feature.erasableDataDescription {
                Button(L10n.SettingsUI.eraseData) { confirmErase = true }
                    .buttonStyle(.asDestructive)
                    .confirmationDialog(L10n.SettingsUI.eraseQuestion(description), isPresented: $confirmErase) {
                        Button(L10n.SettingsUI.erase, role: .destructive) { feature.eraseData() }
                        Button(L10n.Common.cancel, role: .cancel) {}
                    } message: {
                        Text(L10n.SettingsUI.cannotUndo)
                    }
            }
        }
        .padding(.top, 2)
    }
}

/// A permission on a feature page: name, live state, why, and required or optional.
private struct FeaturePermissionCard: View {
    let permission: Permission
    let permissions: PermissionsManager
    let isRequired: Bool

    var body: some View {
        let state = permissions.state(of: permission)
        ASCard(padding: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(permission.displayName).font(AS.font(13, .semibold)).foregroundStyle(AS.text)
                    Spacer()
                    PermissionStateLabel(state: state)
                    if state != .granted {
                        Button(L10n.AllSet.allowEllipsis) { Task { _ = await permissions.request(permission) } }
                            .buttonStyle(.asSecondary)
                    }
                }
                Text(permission.explanation).font(AS.footnote).foregroundStyle(AS.textTertiary).fixedSize(horizontal: false, vertical: true)
                Text(isRequired ? L10n.AllSet.required : L10n.AllSet.optional).font(AS.footnote).foregroundStyle(AS.textTertiary)
            }
        }
    }
}

/// "Allowed" / "Needs permission" / "Not asked yet" as the design shows them.
struct PermissionStateLabel: View {
    let state: PermissionState

    var body: some View {
        switch state {
        case .granted:
            ASStatusLabel(.good, L10n.AllSet.allowed)
        case .denied:
            ASStatusLabel(.warning, L10n.AllSet.needsPermission)
        case .notDetermined, .unknown:
            HStack(spacing: 5) {
                Circle().strokeBorder(AS.textSecondary, lineWidth: 1.4).frame(width: 11, height: 11)
                Text(state == .unknown ? L10n.Permissions.unknown : L10n.AllSet.notAskedYet)
            }
            .font(.system(size: 12))
            .foregroundStyle(AS.textSecondary)
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title).font(AS.body).foregroundStyle(AS.text)
                if let warning = row.flatMap(ShortcutsPane.warning) {
                    Text(warning).font(AS.footnote).foregroundStyle(AS.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HotkeyRecorderView(combo: row?.combo) { combo in
                ShortcutsPane.rebind(action.id, to: combo, services: services, table: table)
            }
            Button { services.hotkeys.resetToDefaults([action.id]) } label: {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AS.textSecondary)
            .help(L10n.Common.resetToDefault)
            .accessibilityLabel(L10n.Common.resetToDefault)
            .opacity(row?.isDefault ?? true ? 0 : 1)
            .disabled(row?.isDefault ?? true)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
    }
}

/// A shortcut recorder in a dark pill, with a reset arrow when changed
/// (Shortcuts page and grids inside feature pages).
struct ShortcutPill: View {
    let id: String
    let services: AppServices

    var body: some View {
        let table = services.shortcutTable(includingHidden: true)
        let row = table.rows.first { $0.id == id }
        HStack(spacing: 6) {
            if let row, !row.isDefault {
                Button { services.hotkeys.resetToDefaults([id]) } label: {
                    Image(systemName: "arrow.uturn.backward").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AS.textSecondary)
                .help(L10n.Common.resetToDefault)
                .accessibilityLabel(L10n.Common.resetToDefault)
            }
            HotkeyRecorderView(combo: row?.combo) { ShortcutsPane.rebind(id, to: $0, services: services, table: table) }
                .padding(.horizontal, 2)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.black.opacity(0.22)))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
    }
}
