import Observation
import ServiceManagement

/// Registers the app as a login item with `SMAppService.mainApp`.
@MainActor
@Observable
public final class LaunchAtLogin {
    public private(set) var status: SMAppService.Status = .notRegistered
    public private(set) var lastError: String?

    public init() { refresh() }

    public var isEnabled: Bool { status == .enabled }

    /// True when the user must approve the login item in System Settings.
    public var needsApproval: Bool { status == .requiresApproval }

    public func refresh() { status = SMAppService.mainApp.status }

    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    public func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
