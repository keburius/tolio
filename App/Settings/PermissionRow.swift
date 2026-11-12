import OmniCore
import OmniPlatform
import SwiftUI

/// One permission with its live state and a one-click fix.
struct PermissionRow: View {
    let permission: Permission
    let permissions: PermissionsManager
    var note: String?

    var body: some View {
        HStack(alignment: .top, spacing: OmniStyle.s3) {
            Image(systemName: symbol).foregroundStyle(color).font(.title3).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(permission.displayName).font(.headline)
                    Spacer()
                    Text(stateText).font(.caption.weight(.semibold)).foregroundStyle(color)
                }
                Text(permission.explanation).font(.callout).foregroundStyle(.secondary)
                if let note { Text(note).font(.caption).foregroundStyle(.secondary) }
                if state != .granted {
                    HStack {
                        Button(state == .notDetermined && permission.hasSystemPrompt ? L10n.Common.allow : L10n.Common.openSystemSettings) {
                            Task { _ = await permissions.request(permission) }
                        }
                        if state == .denied {
                            Button(L10n.Permissions.resetAndAskAgain) { Task { _ = await permissions.resetAndRequest(permission) } }
                                .help(L10n.Permissions.resetHelp)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, OmniStyle.s1)
        .accessibilityElement(children: .combine)
    }

    private var state: PermissionState { permissions.state(of: permission) }

    private var stateText: String {
        switch state {
        case .granted: L10n.Permissions.allowed
        case .denied: L10n.Permissions.notAllowed
        case .notDetermined: L10n.Permissions.notAskedYet
        case .unknown: L10n.Permissions.unknown
        }
    }

    private var symbol: String {
        switch state {
        case .granted: "checkmark.circle.fill"
        case .denied: "circle"
        case .notDetermined: "circle.dashed"
        case .unknown: "questionmark.circle"
        }
    }

    private var color: Color {
        switch state {
        case .granted: .green
        case .denied: .orange
        case .notDetermined, .unknown: .secondary
        }
    }
}
