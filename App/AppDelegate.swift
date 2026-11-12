import AppKit
import FeatureDiagnostics
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
        services.features.register(DiagnosticsFeature())
    }

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = HostingWindowController(
                title: "Omni Settings",
                size: NSSize(width: 720, height: 500),
                permissions: services.permissions,
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
