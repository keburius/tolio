import AppKit
import FeatureClipboard
import FeatureDeskMinder
import FeatureDiagnostics
import FeatureDropRing
import FeatureIsland
import FeatureKeepAwake
import FeatureKeyboardClean
import FeatureScreenshots
import FeatureStickyNotes
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
        NSApp.mainMenu = Self.makeMainMenu()
        registerFeatures()
        migrateSettings()
        registerAppCommands()
        services.features.activateWantedFeatures()
        let controlPanel = ControlPanelController(
            services: services, menuBar: { [weak self] in self?.menuBar },
            openSettings: { [weak self] page in self?.showSettings(page) }
        )
        self.controlPanel = controlPanel
        QuickAccessCenter.openSettings = { [weak self] id in self?.showSettings(.feature(id)) }
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

    /// A menu bar app has no visible menu, but text fields only get ⌘A, ⌘C,
    /// ⌘V, ⌘X and ⌘Z through an Edit menu, so Omni installs one.
    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu()
        appItem.submenu?.addItem(NSMenuItem(title: L10n.App.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: L10n.App.editMenu)
        edit.addItem(NSMenuItem(title: L10n.App.undo, action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: L10n.App.redo, action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: L10n.App.cut, action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: L10n.App.copy, action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: L10n.App.paste, action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: L10n.App.selectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = edit
        main.addItem(editItem)
        return main
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
        removeLauncherLeftovers()
        guard services.settings.value(AppServices.onboardingCompletedKey) else { return }
        var wanted = services.settings.value(FeatureRegistry.wantedKey)
        // Capture Text used to be part of Screenshots & Recording; it stays
        // on for people who had that on.
        if wanted["capturetext"] == nil, wanted["screenshots"] == true {
            wanted["capturetext"] = true
            services.settings.set(wanted, for: FeatureRegistry.wantedKey)
        }
        if wanted["diagnostics"] == nil {
            wanted["diagnostics"] = true
            services.settings.set(wanted, for: FeatureRegistry.wantedKey)
        }
    }

    /// The Launcher was removed in 1.1. Forgets its settings and moves its
    /// cached currency rates to the Trash (never deleted outright).
    private func removeLauncherLeftovers() {
        let settings = services.settings
        var wanted = settings.value(FeatureRegistry.wantedKey)
        if wanted.removeValue(forKey: "palette") != nil { settings.set(wanted, for: FeatureRegistry.wantedKey) }
        for name in settings.storedKeys(withPrefix: "feature.palette.") { settings.removeValue(named: name) }
        guard let support = try? AppPaths.applicationSupport() else { return }
        for file in ["currency-rates.json", "currency-rates-nbg.json"] {
            let url = support.appendingPathComponent(file)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                Log.logger("app").notice("Moved the old Launcher file \(file, privacy: .public) to the Trash")
            } catch {
                Log.logger("app").error("Couldn't move \(file, privacy: .public) to the Trash: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Every feature module is registered here. Settings lists them by
    /// `FeatureGroup`, in this order within each group.
    private func registerFeatures() {
        // Clipboard
        services.features.register(ClipboardHistoryFeature())
        services.features.register(SnippetsFeature())
        // Windows
        services.features.register(WindowsFeature())
        services.features.register(SwitcherFeature())
        // Keyboard
        services.features.register(KeyboardCleanFeature())
        // Capture
        services.features.register(ScreenshotsFeature())
        services.features.register(CaptureTextFeature())
        // Files
        services.features.register(DropRingFeature())
        // Island
        services.features.register(IslandFeature())
        // Energy
        services.features.register(KeepAwakeFeature())
        // Extras
        services.features.register(StickyNotesFeature())
        services.features.register(DeskMinderFeature())
        services.features.register(ShortcutOverlayFeature())
        services.features.register(TextActionsFeature())
        services.features.register(SystemStatsFeature())
        services.features.register(DiagnosticsFeature())
    }

    /// App-level commands.
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

    /// `tolio://settings` opens Settings (`tolio://settings/clipboard` a
    /// feature's page), `tolio://panel` the control panel and `tolio://dropring`
    /// the Drop Ring and `tolio://reminder` the Desk Minder bar and
    /// `tolio://island` Notch Island (for automation). Only these fixed
    /// actions are exposed: a link can't run arbitrary commands.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "tolio" {
            switch url.host {
            case "settings":
                // tolio://settings/<feature id or page> opens that page.
                let name = url.lastPathComponent
                let pages: [String: SettingsPage] = [
                    "overview": .overview, "menubar": .menuBar, "shortcuts": .shortcuts,
                    "permissions": .permissions, "general": .general, "profile": .profile,
                ]
                let id = FeatureID(rawValue: name)
                showSettings(pages[name] ?? (services.features.feature(id) == nil ? nil : .feature(id)))
            case "panel": controlPanel?.toggle(below: menuBar?.mainButton, byKeyboard: true)
            case "dropring": services.commands.allCommands.first { $0.id == "dropring.show" }?.action()
            case "reminder": services.commands.allCommands.first { $0.id == "deskminder.show" }?.action()
            case "island": services.commands.allCommands.first { $0.id == "island.open" }?.action()
            case NoteURL.host: newStickyNote(from: url)
            default: break
            }
        }
    }

    /// "New Sticky Note" from the desktop's right-click menu (Finder extension).
    /// Turns Sticky Notes on if needed: choosing the menu item is consent.
    private func newStickyNote(from url: URL) {
        guard case let .some(point) = NoteURL.newNotePoint(url),
              let feature = services.features.feature("stickynotes") as? StickyNotesFeature else { return }
        if !services.features.isWanted(feature.id) { services.features.setWanted(true, for: feature.id) }
        feature.newNote(at: point)
    }

    /// Opens Settings at `page` (or where it was). Holding ⌥ also lists Diagnostics.
    private func showSettings(_ page: SettingsPage?) {
        if NSEvent.modifierFlags.contains(.option) { navigation.showsHiddenFeatures = true }
        if let page { navigation.open(page) }
        if settingsWindow == nil {
            settingsWindow = HostingWindowController(
                title: L10n.SettingsUI.windowTitle,
                size: NSSize(width: 1000, height: 720),
                permissions: services.permissions,
                allSetChrome: true,
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
            title: L10n.OnboardingUI.windowTitle,
            size: NSSize(width: 760, height: 580),
            permissions: services.permissions,
            allSetChrome: true,
            resizable: false,
            content: OnboardingView(services: services) { [weak self] openSettings in self?.finishOnboarding(openSettings: openSettings) }
        )
        onboardingWindow?.show()
    }

    private func finishOnboarding(openSettings: Bool) {
        services.settings.set(true, for: AppServices.onboardingCompletedKey)
        onboardingWindow?.close()
        if openSettings { showSettings(.overview) }
    }

}
