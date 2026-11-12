import OmniCore
import OmniPlatform
import SwiftUI

/// Every permission, which features use it, and its current state.
struct PermissionsPane: View {
    let permissions: PermissionsManager
    let features: FeatureRegistry

    var body: some View {
        Form {
            Section {
                ForEach(Permission.allCases) { permission in
                    PermissionRow(permission: permission, permissions: permissions, note: usage(of: permission))
                }
            }
        }
        .formStyle(.grouped)
    }

    private func usage(of permission: Permission) -> String {
        let required = features.features.filter { $0.requiredPermissions.contains(permission) }.map(\.displayName)
        let optional = features.features.filter { $0.optionalPermissions.contains(permission) }.map(\.displayName)
        var parts: [String] = []
        if !required.isEmpty { parts.append("Needed by " + required.joined(separator: ", ")) }
        if !optional.isEmpty { parts.append("Optional for " + optional.joined(separator: ", ")) }
        return parts.isEmpty ? "No enabled feature uses this yet." : parts.joined(separator: ". ")
    }
}
