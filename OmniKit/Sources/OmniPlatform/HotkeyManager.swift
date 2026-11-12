import Observation
import OmniCore

/// Central registry of global shortcuts. Resolves user overrides, detects
/// conflicts, and binds through a `HotkeyBackend`.
@MainActor
@Observable
public final class HotkeyManager: HotkeyRegistering {
    /// Binding state of one registered action.
    public enum BindingState: Equatable, Sendable {
        case active(KeyCombo)
        case unbound
        case conflict(KeyCombo, withActionID: String)
        /// The OS refused the shortcut, usually because another app owns it.
        case failed(KeyCombo, status: Int32)
    }

    /// One action a feature registered.
    public struct Registration: Identifiable {
        public let action: HotkeyAction
        public let owner: FeatureID
        public var state: BindingState
        public var id: String { action.id }
        let backendID: UInt32
        let handler: @MainActor () -> Void
    }

    /// Result of a user rebinding attempt.
    public enum RebindResult: Equatable, Sendable {
        case ok
        case invalid(KeyComboIssue)
        case conflict(withTitle: String)
        case systemRefused(status: Int32)
    }

    public static let bindingsKey = SettingKey<HotkeyBindings>("hotkeys.bindings", default: HotkeyBindings())

    public private(set) var registrations: [String: Registration] = [:]

    @ObservationIgnored private let backend: any HotkeyBackend
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var nextBackendID: UInt32 = 1
    @ObservationIgnored private let log = Log.logger("hotkeys")

    public init(backend: any HotkeyBackend, settings: SettingsStore) {
        self.backend = backend
        self.settings = settings
        backend.onPress = { [weak self] id in self?.handlePress(backendID: id) }
    }

    /// Registrations sorted for display.
    public var sortedRegistrations: [Registration] {
        registrations.values.sorted { ($0.owner.rawValue, $0.action.title) < ($1.owner.rawValue, $1.action.title) }
    }

    public func register(_ action: HotkeyAction, owner: FeatureID, handler: @escaping @MainActor () -> Void) {
        unregister(actionID: action.id)
        let backendID = nextBackendID
        nextBackendID += 1
        registrations[action.id] = Registration(
            action: action, owner: owner, state: .unbound, backendID: backendID, handler: handler
        )
        bind(action.id)
    }

    public func unregisterAll(owner: FeatureID) {
        for registration in registrations.values where registration.owner == owner {
            unregister(actionID: registration.action.id)
        }
    }

    /// Changes or clears (`nil`) the shortcut for an action and persists it.
    @discardableResult
    public func rebind(_ actionID: String, to combo: KeyCombo?) -> RebindResult {
        guard registrations[actionID] != nil else {
            // A feature that's off: just remember the choice for when it's on.
            if let combo, let issue = combo.issue { return .invalid(issue) }
            var bindings = settings.value(Self.bindingsKey)
            bindings.set(combo, for: actionID)
            settings.set(bindings, for: Self.bindingsKey)
            return .ok
        }
        if let combo {
            if let issue = combo.issue { return .invalid(issue) }
            if let other = activeRegistration(using: combo, excluding: actionID) {
                return .conflict(withTitle: other.action.title)
            }
        }
        var bindings = settings.value(Self.bindingsKey)
        bindings.set(combo, for: actionID)
        settings.set(bindings, for: Self.bindingsKey)
        bind(actionID)
        if case let .failed(_, status) = registrations[actionID]?.state {
            return .systemRefused(status: status)
        }
        return .ok
    }

    /// Restores the action's default shortcut.
    public func resetToDefault(_ actionID: String) {
        var bindings = settings.value(Self.bindingsKey)
        bindings.reset(actionID)
        settings.set(bindings, for: Self.bindingsKey)
        bind(actionID)
    }

    /// Restores the defaults of several actions (a feature's "Reset to Defaults").
    public func resetToDefaults(_ actionIDs: [String]) {
        var bindings = settings.value(Self.bindingsKey)
        for id in actionIDs { bindings.reset(id) }
        settings.set(bindings, for: Self.bindingsKey)
        for id in actionIDs { bind(id) }
    }

    /// The user's overrides (for the shortcuts table).
    public var bindings: HotkeyBindings { settings.value(Self.bindingsKey) }

    /// Registered actions macOS refused.
    public var refusedActionIDs: Set<String> {
        Set(registrations.values.compactMap { if case .failed = $0.state { $0.action.id } else { nil } })
    }

    private func unregister(actionID: String) {
        guard let registration = registrations.removeValue(forKey: actionID) else { return }
        backend.unregister(id: registration.backendID)
    }

    private func bind(_ actionID: String) {
        guard var registration = registrations[actionID] else { return }
        backend.unregister(id: registration.backendID)
        let combo = settings.value(Self.bindingsKey).combo(for: registration.action)
        if let combo {
            if let other = activeRegistration(using: combo, excluding: actionID) {
                registration.state = .conflict(combo, withActionID: other.action.id)
            } else {
                let status = backend.register(id: registration.backendID, combo: combo)
                registration.state = status == 0 ? .active(combo) : .failed(combo, status: status)
                if status != 0 {
                    log.error("Hotkey \(actionID, privacy: .public) \(combo.displayString, privacy: .public) refused: \(status)")
                }
            }
        } else {
            registration.state = .unbound
        }
        registrations[actionID] = registration
    }

    private func activeRegistration(using combo: KeyCombo, excluding actionID: String) -> Registration? {
        registrations.values.first { $0.action.id != actionID && $0.state == .active(combo) }
    }

    private func handlePress(backendID: UInt32) {
        guard let registration = registrations.values.first(where: { $0.backendID == backendID }) else { return }
        log.debug("Hotkey fired: \(registration.action.id, privacy: .public)")
        registration.handler()
    }
}
