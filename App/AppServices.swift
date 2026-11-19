import OmniCore
import OmniPlatform

/// Composition root: builds the shared services once and wires them together.
@MainActor
final class AppServices {
    static let onboardingCompletedKey = SettingKey("app.onboardingCompleted", default: false)
    /// Set once the All Set (2.0) welcome guide has been shown, so people
    /// upgrading from Tolio see the new guide one time.
    static let allSetGuideSeenKey = SettingKey("app.allSetGuideSeen", default: false)
    /// Set once All Set has turned "Open at login" on by default, so turning
    /// it off later is respected.
    static let loginItemDefaultAppliedKey = SettingKey("app.loginItemDefaultApplied", default: false)

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
