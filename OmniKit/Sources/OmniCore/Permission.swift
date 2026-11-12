import Foundation

/// A macOS privacy permission (TCC service) a feature may need.
public enum Permission: String, Codable, CaseIterable, Sendable, Identifiable {
    case accessibility
    case screenRecording
    case microphone

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .accessibility: L10n.Permissions.accessibility
        case .screenRecording: L10n.Permissions.screenRecording
        case .microphone: L10n.Permissions.microphone
        }
    }

    /// One sentence shown in onboarding and Settings explaining why Omni asks.
    public var explanation: String {
        switch self {
        case .accessibility: L10n.Permissions.accessibilityWhy
        case .screenRecording: L10n.Permissions.screenRecordingWhy
        case .microphone: L10n.Permissions.microphoneWhy
        }
    }

    /// Anchor of the Privacy & Security pane for this permission.
    public var settingsAnchor: String {
        switch self {
        case .accessibility: "Privacy_Accessibility"
        case .screenRecording: "Privacy_ScreenCapture"
        case .microphone: "Privacy_Microphone"
        }
    }

    /// Deep link that opens System Settings at this permission's list.
    public var settingsURL: URL {
        // The string is a constant, so this cannot fail.
        URL(string: "x-apple.systempreferences:com.apple.preference.security?\(settingsAnchor)")!
    }

    /// The TCC service name `tccutil` uses for this permission.
    public var tccService: String {
        switch self {
        case .accessibility: "Accessibility"
        case .screenRecording: "ScreenCapture"
        case .microphone: "Microphone"
        }
    }

    /// Whether macOS shows its own prompt when asked. If not, the user must
    /// add Omni by hand in System Settings.
    public var hasSystemPrompt: Bool {
        switch self {
        case .accessibility, .screenRecording, .microphone: true
        }
    }
}

/// Current state of a permission as far as Omni can tell.
public enum PermissionState: String, Codable, Sendable {
    case granted
    case denied
    case notDetermined
    /// No API reports this permission and the heuristic was inconclusive.
    case unknown

    /// A feature may start in this state. `unknown` does not block, because
    /// some permissions can never be read reliably.
    public var allowsUse: Bool { self == .granted || self == .unknown }
}

/// Checks and requests permissions. Implemented by `PermissionsManager`.
@MainActor
public protocol PermissionChecking: AnyObject {
    func state(of permission: Permission) -> PermissionState
    func request(_ permission: Permission) async -> PermissionState
    func openSettings(for permission: Permission)
}

public extension PermissionChecking {
    /// The subset of `permissions` that currently blocks use.
    func missing(_ permissions: Set<Permission>) -> Set<Permission> {
        permissions.filter { !state(of: $0).allowsUse }
    }
}
