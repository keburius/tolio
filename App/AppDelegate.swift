import AppKit
import FeatureClipboard
import FeatureDiagnostics
import FeatureKeepAwake
import FeatureKeyboardClean
import FeatureScreenshots
import FeaturePalette
import FeatureShortcutOverlay
import FeatureSwitcher
import FeatureSystemStats
import FeatureTextActions
import FeatureWindows
import OmniCore

/// Starts services and features, owns the menu bar, control panel and app windows.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let services = AppServices()
    private var menuBar: MenuBarController?
    private var controlPanel: ControlPanelController?
    private let navigation = SettingsNavigation()
    private var settingsWindow: HostingWindowController<SettingsRootView>?
    private var onboardingWindow: HostingWindowController<OnboardingView>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerFeatures()
        migrateSettings()
        registerAppCommands()
        services.features.activateWantedFeatures()
        let controlPanel = ControlPanelController(
            services: services, menuBar: { [weak self] in self?.menuBar },
            openSettings: { [weak self] page in self?.showSettings(page) }
        )
        self.controlPanel = controlPanel
        menuBar = MenuBarController(services: services, actions: MenuBarActions(
            openControlPanel: { button in controlPanel.toggle(below: button) },
            showLayoutGrid: { button in controlPanel.showLayoutGrid(below: button) },
            openSettings: { [weak self] page in self?.showSettings(page) },
            openOnboarding: { [weak self] in self?.showOnboarding() }
        ))
        services.hotkeys.register(AppHotkeys.controlPanel, owner: AppHotkeys.owner) { [weak self] in
            self?.controlPanel?.toggle(below: self?.menuBar?.mainButton, byKeyboard: true)
        }
        if !services.settings.value(AppServices.onboardingCompletedKey) {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        services.features.deactivateAll()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(nil)
        return false
    }

    /// Diagnostics used to be on by default; it's now off for new users.
    /// Someone who already finished setup keeps what they had.
    private func migrateSettings() {
        guard services.settings.value(AppServices.onboardingCompletedKey) else { return }
        var wanted = services.settings.value(FeatureRegistry.wantedKey)
        if wanted["diagnostics"] == nil {
            wanted["diagnostics"] = true
            services.settings.set(wanted, for: FeatureRegistry.wantedKey)
        }
    }

    /// Every feature module is registered here, in sidebar order.
    private func registerFeatures() {
        services.features.register(PaletteFeature())
        services.features.register(ClipboardHistoryFeature())
        services.features.register(SnippetsFeature())
        services.features.register(WindowsFeature())
        services.features.register(SwitcherFeature())
        services.features.register(KeepAwakeFeature())
        services.features.register(KeyboardCleanFeature())
        services.features.register(SystemStatsFeature())
        services.features.register(ShortcutOverlayFeature())
        services.features.register(TextActionsFeature())
        services.features.register(ScreenshotsFeature())
        services.features.register(DiagnosticsFeature())
    }

    /// App-level commands, searchable in the Launcher.
    private func registerAppCommands() {
        let owner = AppHotkeys.owner
        let commands = services.commands
        commands.register(Command(
            id: "app.settings", title: L10n.App.settingsCommand, keywords: ["preferences"], symbolName: "gearshape"
        ) { [weak self] in self?.showSettings(nil) }, owner: owner)
        commands.register(Command(
            id: "app.setup", title: L10n.App.setupGuideCommand, keywords: ["onboarding", "permissions"], symbolName: "sparkles"
        ) { [weak self] in self?.showOnboarding() }, owner: owner)
        commands.register(Command(
            id: "app.controlPanel", title: L10n.App.openControlPanel, keywords: ["menu", "panel"], symbolName: "square.grid.3x3.square"
        ) { [weak self] in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                self?.controlPanel?.toggle(below: self?.menuBar?.mainButton, byKeyboard: true)
            }
        }, owner: owner)
        commands.register(Command(
            id: "app.quit", title: L10n.App.quit, symbolName: "power"
        ) { NSApp.terminate(nil) }, owner: owner)
    }

    /// `omni://palette` opens the Launcher, `omni://settings` Settings and
    /// `omni://panel` the control panel (for automation). Only these fixed
    /// actions are exposed: a link can't run arbitrary commands.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "omni" {
            switch url.host {
            case "palette": services.commands.allCommands.first { $0.id == PaletteFeature.showCommandID }?.action()
            case "settings": showSettings(nil)
            case "panel": controlPanel?.toggle(below: menuBar?.mainButton, byKeyboard: true)
            default: break
            }
        }
    }

    /// Opens Settings at `page` (or where it was). Holding ⌥ also lists Diagnostics.
    private func showSettings(_ page: SettingsPage?) {
        if NSEvent.modifierFlags.contains(.option) { navigation.showsHiddenFeatures = true }
        if let page { navigation.open(page) }
        if settingsWindow == nil {
            settingsWindow = HostingWindowController(
                title: L10n.SettingsUI.windowTitle,
                size: NSSize(width: 820, height: 580),
                permissions: services.permissions,
                fullSizeContent: true,
                content: SettingsRootView(
                    services: services, navigation: navigation,
                    menuBarEntries: { [weak self] in self?.menuBar?.entries() ?? [:] },
                    onShowOnboarding: { [weak self] in self?.showOnboarding() }
                ),
                onClose: { [weak self] in self?.navigation.showsHiddenFeatures = false }
            )
        }
        settingsWindow?.show()
    }

    private func showOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = HostingWindowController(
            title: L10n.Onboarding.windowTitle,
            size: NSSize(width: 640, height: 540),
            permissions: services.permissions,
            content: OnboardingView(services: services) { [weak self] openPanel in self?.finishOnboarding(openPanel: openPanel) }
        )
        onboardingWindow?.show()
    }

    private func finishOnboarding(openPanel: Bool) {
        services.settings.set(true, for: AppServices.onboardingCompletedKey)
        onboardingWindow?.close()
        guard openPanel else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            controlPanel?.toggle(below: menuBar?.mainButton, byKeyboard: true)
        }
    }
}
