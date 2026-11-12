import OmniCore
import OmniPlatform
import SwiftUI

/// One permission with its state and a button to grant it.
struct PermissionRow: View {
    let permission: Permission
    let permissions: PermissionsManager
    var note: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(permission.displayName).font(.headline)
                Text(permission.explanation).font(.callout).foregroundStyle(.secondary)
                if let note {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                PermissionBadge(state: state)
                if state != .granted {
                    Button(permission.hasSystemPrompt && state == .notDetermined ? "Grant…" : "Open Settings") {
                        Task { _ = await permissions.request(permission) }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var state: PermissionState { permissions.state(of: permission) }
}

/// Colored state label.
struct PermissionBadge: View {
    let state: PermissionState

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }

    private var text: String {
        switch state {
        case .granted: "Granted"
        case .denied: "Not granted"
        case .notDetermined: "Not requested"
        case .unknown: "Can't check"
        }
    }

    private var symbol: String {
        switch state {
        case .granted: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .notDetermined: "circle.dashed"
        case .unknown: "questionmark.circle"
        }
    }

    private var color: Color {
        switch state {
        case .granted: .green
        case .denied: .red
        case .notDetermined: .orange
        case .unknown: .secondary
        }
    }
}
