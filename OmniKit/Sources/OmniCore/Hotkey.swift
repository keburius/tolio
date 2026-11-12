/// A named global shortcut a feature offers. Users can rebind or clear it.
public struct HotkeyAction: Identifiable, Hashable, Sendable {
    /// Globally unique, e.g. `windows.leftHalf`. Used as the persistence key.
    public let id: String
    public let title: String
    public let defaultCombo: KeyCombo?

    public init(id: String, title: String, defaultCombo: KeyCombo?) {
        self.id = id
        self.title = title
        self.defaultCombo = defaultCombo
    }
}

/// User overrides of hotkey defaults. Absent entry = use the action's default.
public struct HotkeyBindings: Codable, Equatable, Sendable {
    /// One stored override. `combo == nil` means the user cleared the shortcut.
    public struct Override: Codable, Equatable, Sendable {
        public var combo: KeyCombo?
        public init(combo: KeyCombo?) { self.combo = combo }
    }

    public var overrides: [String: Override]

    public init(overrides: [String: Override] = [:]) {
        self.overrides = overrides
    }

    /// The combo that applies to `action` after user overrides.
    public func combo(for action: HotkeyAction) -> KeyCombo? {
        if let override = overrides[action.id] { return override.combo }
        return action.defaultCombo
    }

    public mutating func set(_ combo: KeyCombo?, for actionID: String) {
        overrides[actionID] = Override(combo: combo)
    }

    public mutating func reset(_ actionID: String) {
        overrides[actionID] = nil
    }
}

/// Registers global hotkeys on behalf of a feature. Implemented by `HotkeyManager`.
@MainActor
public protocol HotkeyRegistering: AnyObject {
    func register(_ action: HotkeyAction, owner: FeatureID, handler: @escaping @MainActor () -> Void)
    func unregisterAll(owner: FeatureID)
}
