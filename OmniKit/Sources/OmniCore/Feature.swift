import SwiftUI
import os

/// A user-togglable unit of functionality.
///
/// Contract: while disabled a feature holds no timers, event taps, or watchers.
/// Register teardown for anything started in `enable` with `context.lifetime`.
@MainActor
public protocol Feature: AnyObject {
    var id: FeatureID { get }
    var displayName: String { get }
    /// One sentence for the feature list.
    var summary: String { get }
    /// SF Symbol name.
    var symbolName: String { get }
    /// Permissions without which the feature can't start.
    var requiredPermissions: Set<Permission> { get }
    /// Permissions that unlock parts of the feature.
    var optionalPermissions: Set<Permission> { get }
    var isEnabledByDefault: Bool { get }

    func enable(context: FeatureContext) throws
    func disable()
    func makeSettingsView() -> AnyView

    // MARK: UI descriptions (no behaviour; see FeatureUI.swift)

    /// Every global shortcut the feature registers when on, known even while off.
    var declaredHotkeys: [HotkeyAction] { get }
    /// Shortcuts that aren't key combinations.
    var gestures: [GestureShortcut] { get }
    /// Searchable settings on the feature's page.
    var settingsEntries: [SettingsEntry] { get }
    /// Setting names (`SettingKey.name`) holding things the user made, which
    /// "Reset to Defaults" keeps. Everything else under `feature.<id>.` is reset.
    var userContentSettingKeys: Set<String> { get }
    /// What "Erase Data…" would delete, as a sentence fragment
    /// ("all 214 clipboard items, including pinned ones"), or nil if there is
    /// nothing to erase or the feature is off.
    var erasableDataDescription: String? { get }
    /// Deletes the feature's user content. Only called after confirmation.
    func eraseData()
    /// Menu bar icons and control panel tiles. Title, symbol, hint and
    /// shortcut must be valid while the feature is off; `state`, `primary` and
    /// `menu` are only called while it is on.
    var quickAccessItems: [QuickAccessItem] { get }
    /// True for internal features hidden from normal users (Diagnostics).
    var isHidden: Bool { get }
}

public extension Feature {
    var optionalPermissions: Set<Permission> { [] }
    var isEnabledByDefault: Bool { false }
    var declaredHotkeys: [HotkeyAction] { [] }
    var gestures: [GestureShortcut] { [] }
    var settingsEntries: [SettingsEntry] { [] }
    var userContentSettingKeys: Set<String> { [] }
    var erasableDataDescription: String? { nil }
    func eraseData() {}
    var quickAccessItems: [QuickAccessItem] { [] }
    var isHidden: Bool { false }
}

/// Services handed to a feature when it is enabled. Hotkeys and commands
/// registered through it are owned by the feature and removed on disable.
@MainActor
public struct FeatureContext {
    public let featureID: FeatureID
    public let settings: SettingsStore
    public let permissions: any PermissionChecking
    public let lifetime: Lifetime
    public let log: Logger
    private let hotkeys: any HotkeyRegistering
    private let commands: any CommandRegistering

    public init(
        featureID: FeatureID,
        settings: SettingsStore,
        permissions: any PermissionChecking,
        hotkeys: any HotkeyRegistering,
        commands: any CommandRegistering,
        lifetime: Lifetime
    ) {
        self.featureID = featureID
        self.settings = settings
        self.permissions = permissions
        self.hotkeys = hotkeys
        self.commands = commands
        self.lifetime = lifetime
        self.log = Log.logger(featureID.rawValue)
    }

    public func registerHotkey(_ action: HotkeyAction, handler: @escaping @MainActor () -> Void) {
        hotkeys.register(action, owner: featureID, handler: handler)
    }

    public func registerCommand(_ command: Command) {
        commands.register(command, owner: featureID)
    }

    /// Commands registered by all enabled features (and the app itself).
    public var availableCommands: [Command] { commands.allCommands }

    /// Adds dynamic palette results; removed automatically on disable.
    public func registerSearchProvider(_ provider: any SearchProvider) {
        commands.registerProvider(provider, owner: featureID)
    }

    /// Search providers of all enabled features.
    public var searchProviders: [any SearchProvider] { commands.allProviders }

    /// Opens the palette with `query` prefilled (no-op if the palette is off).
    public func openPalette(query: String) {
        commands.openPalette(query: query)
    }

    /// For the palette feature only: receives `openPalette` requests.
    /// Cleared automatically on disable.
    public func setPaletteHandler(_ handler: @escaping @MainActor (String) -> Void) {
        let commands = self.commands
        commands.paletteHandler = handler
        lifetime.add { commands.paletteHandler = nil }
    }
}
