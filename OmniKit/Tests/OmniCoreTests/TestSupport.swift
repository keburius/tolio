import Foundation
@testable import OmniCore
import SwiftUI

/// UserDefaults in a throwaway suite.
func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
    let defaults = UserDefaults(suiteName: "omni.tests.\(name)")!
    defaults.removePersistentDomain(forName: "omni.tests.\(name)")
    return defaults
}

@MainActor
final class FakePermissions: PermissionChecking {
    var states: [Permission: PermissionState] = [:]
    func state(of permission: Permission) -> PermissionState { states[permission] ?? .notDetermined }
    func request(_ permission: Permission) async -> PermissionState { state(of: permission) }
    func openSettings(for permission: Permission) {}
}

@MainActor
final class FakeHotkeys: HotkeyRegistering {
    var registered: [String: FeatureID] = [:]
    func register(_ action: HotkeyAction, owner: FeatureID, handler: @escaping @MainActor () -> Void) {
        registered[action.id] = owner
    }
    func unregisterAll(owner: FeatureID) {
        registered = registered.filter { $0.value != owner }
    }
}

struct EnableFailure: Error {}

@MainActor
final class FakeFeature: Feature {
    let id: FeatureID
    let displayName = "Fake"
    let summary = "Test double"
    let symbolName = "circle"
    let requiredPermissions: Set<Permission>
    let optionalPermissions: Set<Permission>
    let isEnabledByDefault: Bool
    var shouldThrow = false
    private(set) var enableCount = 0
    private(set) var disableCount = 0
    private(set) var resourceCancelled = 0

    init(
        _ id: FeatureID,
        required: Set<Permission> = [],
        optional: Set<Permission> = [],
        enabledByDefault: Bool = false
    ) {
        self.id = id
        self.requiredPermissions = required
        self.optionalPermissions = optional
        self.isEnabledByDefault = enabledByDefault
    }

    func enable(context: FeatureContext) throws {
        enableCount += 1
        context.registerHotkey(HotkeyAction(id: "\(id).hk", title: "HK", defaultCombo: nil)) {}
        context.registerCommand(Command(id: "\(id).cmd", title: "Cmd", symbolName: "circle") {})
        context.lifetime.add { [weak self] in self?.resourceCancelled += 1 }
        if shouldThrow { throw EnableFailure() }
    }

    func disable() { disableCount += 1 }
    func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
}
