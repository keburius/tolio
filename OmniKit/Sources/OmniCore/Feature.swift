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
}

public extension Feature {
    var optionalPermissions: Set<Permission> { [] }
    var isEnabledByDefault: Bool { false }
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
