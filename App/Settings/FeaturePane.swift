import OmniCore
import OmniPlatform
import SwiftUI

/// Toggle, status, permissions, and the feature's own settings.
struct FeaturePane: View {
    let feature: any Feature
    let features: FeatureRegistry
    let permissions: PermissionsManager

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { features.isWanted(feature.id) },
                    set: { features.setWanted($0, for: feature.id) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(feature.displayName, systemImage: feature.symbolName).font(.headline)
                        Text(feature.summary).font(.callout).foregroundStyle(.secondary)
                    }
                }
                let status = features.status(of: feature.id)
                if status != .off && status != .running {
                    Text(status.label).font(.callout).foregroundStyle(status.color)
                }
            }
            let needed = feature.requiredPermissions.union(feature.optionalPermissions)
            if !needed.isEmpty {
                Section("Permissions") {
                    ForEach(needed.sorted { $0.rawValue < $1.rawValue }) { permission in
                        PermissionRow(
                            permission: permission,
                            permissions: permissions,
                            note: feature.requiredPermissions.contains(permission) ? "Required" : "Optional"
                        )
                    }
                }
            }
            if features.status(of: feature.id) == .running {
                Section("Settings") {
                    feature.makeSettingsView()
                }
            }
        }
        .formStyle(.grouped)
    }
}
