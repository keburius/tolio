import AppKit
import Observation
import OmniCore
import OmniPlatform

/// What the menu bar can ask the app to do.
@MainActor
struct MenuBarActions {
    var openControlPanel: (NSStatusBarButton) -> Void
    var showLayoutGrid: (NSStatusBarButton) -> Void
    var openSettings: (SettingsPage?) -> Void
    var openOnboarding: () -> Void
}

/// The main Omni icon and the optional quick-access icons.
///
/// Left-click runs the main action, right-click (or ⌃-click) shows options.
/// Icons are rebuilt in the configured order whenever the configuration or
/// the set of running features changes; states (filled cup, recording timer)
/// update through observation.
@MainActor
final class MenuBarController: NSObject {
    private let services: AppServices
    private let actions: MenuBarActions
    private let shortcuts: ShortcutLookup
    private let main: NSStatusItem
    private var quick: [QuickAccessID: NSStatusItem] = [:]
    private var shownOrder: [QuickAccessID] = []
    private var timer: Timer?

    init(services: AppServices, actions: MenuBarActions) {
        self.services = services
        self.actions = actions
        shortcuts = ShortcutLookup(services: services)
        main = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = main.button {
            button.image = NSImage(systemSymbolName: "square.grid.3x3.square", accessibilityDescription: L10n.App.name)
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(mainClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel(L10n.App.name)
        }
        observe()
    }

    /// The main icon's button, to anchor the control panel.
    var mainButton: NSStatusBarButton? { main.button }

    // MARK: - Items

    struct Entry {
        let feature: any Feature
        let item: QuickAccessItem
    }

    /// Every quick-access item any feature offers, on or off.
    func entries() -> [QuickAccessID: Entry] {
        var result: [QuickAccessID: Entry] = [:]
        for feature in services.features.features where !feature.isHidden {
            for item in feature.quickAccessItems where result[item.id] == nil {
                result[item.id] = Entry(feature: feature, item: item)
            }
        }
        return result
    }

    private func isRunning(_ feature: any Feature) -> Bool {
        services.features.status(of: feature.id) == .running
    }

    // MARK: - Refresh

    /// Re-runs `refresh` whenever anything it read changes.
    private func observe() {
        withObservationTracking {
            refresh()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
    }

    private func refresh() {
        let config = services.settings.value(MenuBarConfiguration.key)
        let all = entries()
        let available = Set(all.filter { isRunning($0.value.feature) }.map(\.key))
        let order = config.iconsToShow(available: available)
        if order != shownOrder { rebuild(order) }
        var recordingStart: Date?
        for (id, entry) in all where isRunning(entry.feature) {
            let state = entry.item.state()
            if id == .recording { recordingStart = state.timerStart }
            if let button = quick[id]?.button { style(button, entry.item, state) }
        }
        updateRecordingIndicator(since: recordingStart, onRecordIcon: quick[.recording] != nil)
        for feature in services.features.features {
            (feature as? StatsLineProviding)?.setOwnMenuBarItemHidden(config.mode == .single)
        }
    }

    private func rebuild(_ order: [QuickAccessID]) {
        for item in quick.values { NSStatusBar.system.removeStatusItem(item) }
        quick.removeAll()
        // New status items appear to the left of existing ones, so create
        // right to left; the main icon (created first) stays rightmost.
        for id in order.reversed() {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self
            item.button?.action = #selector(quickClicked(_:))
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            item.button?.identifier = NSUserInterfaceItemIdentifier(id.rawValue)
            item.button?.imagePosition = .imageLeading
            quick[id] = item
        }
        shownOrder = order
    }

    private func style(_ button: NSStatusBarButton, _ item: QuickAccessItem, _ state: QuickAccessState) {
        let symbol = state.isActive ? (item.activeSymbolName ?? item.symbolName) : item.symbolName
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: item.title)
        button.image?.isTemplate = true
        var tip = item.title
        if let detail = state.detail { tip = L10n.App.iconTooltip(item.title, detail) }
        if let text = shortcuts.text(for: item.shortcutID) { tip += "  " + text }
        button.toolTip = tip
        button.setAccessibilityLabel(tip)
    }

    // MARK: - Recording timer

    private func updateRecordingIndicator(since start: Date?, onRecordIcon: Bool) {
        let target = onRecordIcon ? quick[.recording]?.button : main.button
        let other = onRecordIcon ? main.button : quick[.recording]?.button
        other?.attributedTitle = NSAttributedString()
        guard let start, let target else {
            target?.attributedTitle = NSAttributedString()
            timer?.invalidate()
            timer = nil
            return
        }
        let elapsed = Self.elapsed(since: start)
        let title = NSMutableAttributedString(string: " ● ", attributes: [.foregroundColor: NSColor.systemRed]) // l10n-ignore
        title.append(NSAttributedString(string: elapsed, attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)]))
        target.attributedTitle = title
        target.toolTip = L10n.App.recordingTooltip(elapsed)
        if timer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            timer.tolerance = 0.2
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    static func elapsed(since start: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60) // l10n-ignore
    }

    /// The running recording's start, if any (for the control panel).
    var recordingStart: Date? {
        guard let entry = entries()[.recording], isRunning(entry.feature) else { return nil }
        return entry.item.state().timerStart
    }

    // MARK: - Clicks

    private var isRightClick: Bool {
        guard let event = NSApp.currentEvent else { return false }
        return event.type == .rightMouseUp || event.modifierFlags.contains(.control)
    }

    @objc private func mainClicked(_ sender: NSStatusBarButton) {
        if isRightClick {
            show(mainMenu(), on: main)
        } else if let start = recordingStart, quick[.recording] == nil, Date().timeIntervalSince(start) >= 0,
                  let entry = entries()[.recording] {
            // The main icon shows the recording timer: a click stops it.
            entry.item.primary()
        } else {
            actions.openControlPanel(sender)
        }
    }

    @objc private func quickClicked(_ sender: NSStatusBarButton) {
        guard let raw = sender.identifier?.rawValue, let id = QuickAccessID(rawValue: raw),
              let entry = entries()[id], let statusItem = quick[id] else { return }
        if isRightClick {
            show(optionsMenu(for: entry), on: statusItem)
        } else if id == .windowLayouts {
            actions.showLayoutGrid(sender)
        } else {
            entry.item.primary()
        }
    }

    private func show(_ menu: NSMenu, on item: NSStatusItem) {
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    // MARK: - Menus

    func optionsMenu(for entry: Entry) -> NSMenu {
        var entries = entry.item.menu()
        entries.append(.separator)
        let featureID = entry.feature.id
        let actions = self.actions
        entries.append(.action(MenuAction(L10n.Common.featureSettings(entry.feature.displayName)) {
            actions.openSettings(.feature(featureID))
        }))
        let id = entry.item.id
        let settings = services.settings
        entries.append(.action(MenuAction(L10n.Common.hideThisIcon) {
            var config = settings.value(MenuBarConfiguration.key)
            config.setVisible(false, for: id)
            settings.set(config, for: MenuBarConfiguration.key)
        }))
        return MenuBuilder.menu(entries, shortcuts: shortcuts)
    }

    private func mainMenu() -> NSMenu {
        let menu = NSMenu()
        let panel = ActionMenuItem(L10n.App.openControlPanel) { [weak self] in
            guard let self, let button = self.main.button else { return }
            self.actions.openControlPanel(button)
        }
        ShortcutLookup.apply(shortcuts.combo(for: AppHotkeys.controlPanel.id), to: panel)
        menu.addItem(panel)
        menu.addItem(ActionMenuItem(L10n.App.settings, key: ",") { [actions] in actions.openSettings(nil) })
        menu.addItem(ActionMenuItem(L10n.App.setupGuide) { [actions] in actions.openOnboarding() })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(L10n.App.about) {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        menu.addItem(ActionMenuItem(L10n.App.quit, key: "q") { NSApp.terminate(nil) })
        return menu
    }
}
