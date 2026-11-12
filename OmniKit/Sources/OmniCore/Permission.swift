import Foundation

/// A macOS privacy permission (TCC service) a feature may need.
public enum Permission: String, Codable, CaseIterable, Sendable, Identifiable {
    case accessibility
    case screenRecording
    case fullDiskAccess
    case microphone
    case appManagement

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .accessibility: "Accessibility"
        case .screenRecording: "Screen Recording"
        case .fullDiskAccess: "Full Disk Access"
        case .microphone: "Microphone"
        case .appManagement: "App Management"
        }
    }

    /// One sentence shown in onboarding and Settings explaining why Omni asks.
    public var explanation: String {
        switch self {
        case .accessibility:
            "Lets Omni move windows, read menus and selected text, and listen for shortcuts."
        case .screenRecording:
            "Lets Omni capture screenshots, recordings, and window thumbnails."
        case .fullDiskAccess:
            "Lets Omni read protected folders such as other apps' containers."
        case .microphone:
            "Lets Omni include your voice in screen recordings."
        case .appManagement:
            "Lets Omni move other apps to the Trash when you uninstall them."
        }
    }

    /// Anchor of the Privacy & Security pane for this permission.
    public var settingsAnchor: String {
        switch self {
        case .accessibility: "Privacy_Accessibility"
        case .screenRecording: "Privacy_ScreenCapture"
        case .fullDiskAccess: "Privacy_AllFiles"
        case .microphone: "Privacy_Microphone"
        case .appManagement: "Privacy_AppBundles"
        }
    }

    /// Deep link that opens System Settings at this permission's list.
    public var settingsURL: URL {
        // The string is a constant, so this cannot fail.
        URL(string: "x-apple.systempreferences:com.apple.preference.security?\(settingsAnchor)")!
    }

    /// Whether macOS shows its own prompt when asked. If not, the user must
    /// add Omni by hand in System Settings.
    public var hasSystemPrompt: Bool {
        switch self {
        case .accessibility, .screenRecording, .microphone: true
        case .fullDiskAccess, .appManagement: false
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
