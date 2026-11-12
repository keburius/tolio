import OmniCore
import OmniPlatform
import SwiftUI

/// Every permission, which features use it, and its current state.
struct PermissionsPane: View {
    let services: AppServices
    let navigation: SettingsNavigation

    var body: some View {
        Form {
            Section {
                Text(L10n.Permissions.nothingLeavesMac).font(.callout).foregroundStyle(.secondary)
            }
            Section {
                ForEach(Permission.allCases) { permission in
                    PermissionRow(permission: permission, permissions: services.permissions, note: usage(of: permission))
                }
            }
        }
        .formStyle(.grouped)
    }

    private func usage(of permission: Permission) -> String {
        let features = services.visibleFeatures(includingHidden: navigation.showsHiddenFeatures)
            .filter { services.features.isWanted($0.id) }
        let required = features.filter { $0.requiredPermissions.contains(permission) }.map(\.displayName)
        let optional = features.filter { $0.optionalPermissions.contains(permission) }.map(\.displayName)
        let list = ListFormatter()
        var parts: [String] = []
        if let text = list.string(from: required), !required.isEmpty { parts.append(L10n.Permissions.usedBy(text)) }
        if let text = list.string(from: optional), !optional.isEmpty { parts.append(L10n.Permissions.optionalFor(text)) }
        return parts.isEmpty ? L10n.Permissions.unused : parts.joined(separator: " · ")
    }
}
