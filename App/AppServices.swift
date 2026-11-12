import OmniCore
import OmniPlatform

/// Composition root: builds the shared services once and wires them together.
@MainActor
final class AppServices {
    static let onboardingCompletedKey = SettingKey("app.onboardingCompleted", default: false)

    let settings: SettingsStore
    let permissions: PermissionsManager
    let hotkeys: HotkeyManager
    let commands: CommandRegistry
    let features: FeatureRegistry
    let launchAtLogin: LaunchAtLogin

    init() {
        settings = SettingsStore()
        permissions = PermissionsManager(settings: settings)
        hotkeys = HotkeyManager(backend: CarbonHotkeyBackend(), settings: settings)
        commands = CommandRegistry()
        features = FeatureRegistry(settings: settings, permissions: permissions, hotkeys: hotkeys, commands: commands)
        launchAtLogin = LaunchAtLogin()

        // A newly granted permission can unblock features waiting for it.
        permissions.onStatesChanged = { [features] in features.activateWantedFeatures() }
    }
}
