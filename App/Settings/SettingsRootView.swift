import OmniCore
import SwiftUI

/// Sidebar destinations of the Settings window.
enum SettingsPane: Hashable {
    case general
    case permissions
    case shortcuts
    case feature(FeatureID)
}

/// Settings window: app panes plus one pane per feature.
struct SettingsRootView: View {
    let services: AppServices
    let onShowOnboarding: () -> Void
    @State private var selection: SettingsPane? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Omni") {
                    Label("General", systemImage: "gearshape").tag(SettingsPane.general)
                    Label("Permissions", systemImage: "lock.shield").tag(SettingsPane.permissions)
                    Label("Shortcuts", systemImage: "keyboard").tag(SettingsPane.shortcuts)
                }
                Section("Features") {
                    ForEach(services.features.features, id: \.id) { feature in
                        FeatureSidebarRow(feature: feature, status: services.features.status(of: feature.id))
                            .tag(SettingsPane.feature(feature.id))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            detail
        }
    }

    @ViewBuilder private var detail: some View {
        switch selection ?? .general {
        case .general:
            GeneralPane(launchAtLogin: services.launchAtLogin, onShowOnboarding: onShowOnboarding)
        case .permissions:
            PermissionsPane(permissions: services.permissions, features: services.features)
        case .shortcuts:
            ShortcutsPane(hotkeys: services.hotkeys, features: services.features)
        case let .feature(id):
            if let feature = services.features.feature(id) {
                FeaturePane(feature: feature, features: services.features, permissions: services.permissions)
            }
        }
    }
}

private struct FeatureSidebarRow: View {
    let feature: any Feature
    let status: FeatureRegistry.Status

    var body: some View {
        HStack {
            Label(feature.displayName, systemImage: feature.symbolName)
            Spacer()
            Circle().fill(status.color).frame(width: 7, height: 7).help(status.label)
        }
    }
}

extension FeatureRegistry.Status {
    var color: Color {
        switch self {
        case .off: .secondary.opacity(0.4)
        case .running: .green
        case .waitingForPermissions: .orange
        case .failed: .red
        }
    }

    var label: String {
        switch self {
        case .off: "Off"
        case .running: "On"
        case let .waitingForPermissions(missing):
            "Waiting for " + missing.map(\.displayName).sorted().joined(separator: ", ")
        case let .failed(reason): "Failed: \(reason)"
        }
    }
}
