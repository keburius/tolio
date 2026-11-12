import AppKit
import FeatureClipboard
import FeatureDiagnostics
import FeaturePalette
import FeatureWindows
import OmniCore

/// Starts services and features, owns the status item and app windows.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let services = AppServices()
    private var statusItem: StatusItemController?
    private var settingsWindow: HostingWindowController<SettingsRootView>?
    private var onboardingWindow: HostingWindowController<OnboardingView>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerFeatures()
        registerAppCommands()
        services.features.activateWantedFeatures()
        statusItem = StatusItemController(
            onSettings: { [weak self] in self?.showSettings() },
            onOnboarding: { [weak self] in self?.showOnboarding() }
        )
        if !services.settings.value(AppServices.onboardingCompletedKey) {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        services.features.deactivateAll()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    /// Every feature module is registered here, in sidebar order.
    private func registerFeatures() {
        services.features.register(PaletteFeature())
        services.features.register(ClipboardHistoryFeature())
        services.features.register(SnippetsFeature())
        services.features.register(WindowsFeature())
        services.features.register(DiagnosticsFeature())
    }

    /// App-level commands, searchable in the palette.
    private func registerAppCommands() {
        let owner: FeatureID = "app"
        let commands = services.commands
        commands.register(Command(
            id: "app.settings", title: "Omni Settings", keywords: ["preferences"], symbolName: "gearshape"
        ) { [weak self] in self?.showSettings() }, owner: owner)
        commands.register(Command(
            id: "app.setup", title: "Omni Setup Guide", keywords: ["onboarding", "permissions"], symbolName: "sparkles"
        ) { [weak self] in self?.showOnboarding() }, owner: owner)
        commands.register(Command(
            id: "app.quit", title: "Quit Omni", symbolName: "power"
        ) { NSApp.terminate(nil) }, owner: owner)
    }

    /// `omni://palette` opens the palette and `omni://settings` the Settings
    /// window (for automation, e.g. Shortcuts). Only these fixed actions are
    /// exposed: a link can't run arbitrary commands.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "omni" {
            switch url.host {
            case "palette": services.commands.allCommands.first { $0.id == PaletteFeature.showCommandID }?.action()
            case "settings": showSettings()
            default: break
            }
        }
    }

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = HostingWindowController(
                title: "Omni Settings",
                size: NSSize(width: 720, height: 500),
                permissions: services.permissions,
                fullSizeContent: true,
                content: SettingsRootView(services: services, onShowOnboarding: { [weak self] in self?.showOnboarding() })
            )
        }
        settingsWindow?.show()
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = HostingWindowController(
                title: "Welcome to Omni",
                size: NSSize(width: 560, height: 520),
                permissions: services.permissions,
                content: OnboardingView(services: services, onFinish: { [weak self] in self?.finishOnboarding() })
            )
        }
        onboardingWindow?.show()
    }

    private func finishOnboarding() {
        services.settings.set(true, for: AppServices.onboardingCompletedKey)
        onboardingWindow?.close()
    }
}
