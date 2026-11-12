import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Opens the control panel and the small layout grid, and runs their actions.
@MainActor
final class ControlPanelController {
    private let services: AppServices
    private let menuBar: () -> MenuBarController?
    private let openSettings: (SettingsPage?) -> Void
    private let shortcuts: ShortcutLookup
    private let model = ControlPanelModel()
    private var panel: AnchoredPanel?
    private var layoutPanel: AnchoredPanel?
    private var timer: Timer?

    init(services: AppServices, menuBar: @escaping () -> MenuBarController?, openSettings: @escaping (SettingsPage?) -> Void) {
        self.services = services
        self.menuBar = menuBar
        self.openSettings = openSettings
        shortcuts = ShortcutLookup(services: services)
    }

    var isOpen: Bool { panel?.isVisible == true }

    func toggle(below button: NSView?, byKeyboard: Bool = false) {
        if isOpen { panel?.close() } else { open(below: button, byKeyboard: byKeyboard) }
    }

    // MARK: - Opening

    private func open(below button: NSView?, byKeyboard: Bool) {
        layoutPanel?.close()
        reload()
        model.turnOnPrompt = nil
        model.showsFocusRing = byKeyboard
        model.focus.focusFirst()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.show(below: button ?? menuBar()?.mainButton)
        statsProvider?.setLiveUpdates(true)
        startTimer()
    }

    private func makePanel() -> AnchoredPanel {
        let actions = ControlPanelActions(
            activate: { [weak self] target in self?.activate(target) },
            turnOn: { [weak self] id in self?.turnOn(id) },
            menu: { [weak self] id in self?.entry(id)?.item.menu() ?? [] },
            settingsShortcut: "⌘," // l10n-ignore
        )
        let panel = AnchoredPanel(content: ControlPanelView(model: model, actions: actions))
        panel.onKey = { [weak self] event in self?.handleKey(event) ?? false }
        panel.onClose = { [weak self] in
            self?.statsProvider?.setLiveUpdates(false)
            self?.timer?.invalidate()
            self?.timer = nil
        }
        return panel
    }

    /// Updates the recording timer and stats line while the panel is open.
    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLive() }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refreshLive() {
        model.tiles = makeTiles()
        model.statsLine = statsProvider?.statsLine
    }

    private func reload() {
        ShortcutLookupText.controlPanel = shortcuts.text(for: AppHotkeys.controlPanel.id)
        model.tiles = makeTiles()
        model.clips = makeClips()
        model.window = makeWindow()
        model.layouts = ControlPanelModel.layoutSpecs.map { spec in
            ControlPanelModel.Layout(id: spec.command, title: spec.title(), shortcut: shortcuts.text(for: spec.command), span: spec.span)
        }
        model.statsLine = statsProvider?.statsLine
        model.rebuildFocus()
    }

    // MARK: - Content

    private func entry(_ id: QuickAccessID) -> MenuBarController.Entry? {
        menuBar()?.entries()[id]
    }

    private func makeTiles() -> [ControlPanelModel.Tile] {
        let all = menuBar()?.entries() ?? [:]
        return ControlPanelModel.tileOrder.compactMap { id in
            guard let entry = all[id] else { return nil }
            let feature = entry.feature
            var state: ControlPanelModel.TileState
            switch services.features.status(of: feature.id) {
            case .running:
                let current = entry.item.state()
                if let start = current.timerStart {
                    state = .recording(elapsed: MenuBarController.elapsed(since: start))
                } else {
                    state = .ready(active: current.isActive, detail: current.isActive ? current.detail : nil)
                }
            case let .waitingForPermissions(missing):
                state = .needsPermission(feature: feature.displayName, permission: missing.sorted { $0.rawValue < $1.rawValue }.first ?? .accessibility)
            case .off, .failed:
                state = .off(feature: feature.displayName)
            }
            return .init(id: id, title: entry.item.title, symbol: entry.item.symbolName, shortcut: shortcuts.text(for: entry.item.shortcutID), state: state)
        }
    }

    private func makeClips() -> ControlPanelModel.ClipsState {
        guard let clipboard = services.features.feature("clipboard") else { return .empty }
        guard services.features.status(of: clipboard.id) == .running else { return .featureOff(clipboard.displayName) }
        guard let provider = services.commands.allProviders.first(where: { $0.keyword == "clip" }) else { return .empty }
        let results = provider.results(for: "", limit: 3)
        return results.isEmpty ? .empty : .items(results)
    }

    private func makeWindow() -> ControlPanelModel.WindowState {
        guard let windows = services.features.feature("windows") else { return .none }
        guard services.features.status(of: windows.id) == .running else { return .featureOff(windows.displayName) }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let window = AXWindow.focused() else { return .none }
        let title = window.title.flatMap { $0.isEmpty ? nil : $0 }
        return .window(app: app.localizedName ?? "", title: title)
    }

    private var statsProvider: StatsLineProviding? {
        services.features.features.first { services.features.status(of: $0.id) == .running && $0 is StatsLineProviding } as? StatsLineProviding
    }

    // MARK: - Actions

    private func activate(_ target: ControlPanelFocus.Target) {
        switch target {
        case let .tile(id):
            guard let tile = model.tiles.first(where: { $0.id == id }), let entry = entry(id) else { return }
            switch tile.state {
            case .off:
                model.turnOnPrompt = id
                panel?.refit()
            case let .needsPermission(_, permission):
                panel?.close()
                Task { _ = await services.permissions.request(permission) }
            case .ready, .recording:
                closeThen { entry.item.primary() }
            }
        case let .recent(index):
            guard case let .items(results) = model.clips, results.indices.contains(index) else { return }
            let action = results[index].primaryAction
            closeThen(action)
        case .showAllClips:
            guard let entry = entry(.clipboard) else { return }
            closeThen { entry.item.primary() }
        case let .layout(commandID):
            guard let command = services.commands.allCommands.first(where: { $0.id == commandID }) else { return }
            panel?.close()
            layoutPanel?.close()
            command.action()
        case .settings:
            panel?.close()
            openSettings(.overview)
        case .quit:
            NSApp.terminate(nil)
        }
    }

    /// Closes the panel, waits until it's gone (so it isn't captured), then acts.
    private func closeThen(_ action: @escaping @MainActor () -> Void) {
        panel?.close()
        layoutPanel?.close()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            action()
        }
    }

    private func turnOn(_ id: QuickAccessID) {
        guard let feature = entry(id)?.feature ?? (id == .clipboard ? services.features.feature("clipboard") : id == .windowLayouts ? services.features.feature("windows") : nil) else { return }
        services.features.setWanted(true, for: feature.id)
        if case let .waitingForPermissions(missing) = services.features.status(of: feature.id), let permission = missing.first {
            panel?.close()
            Task { _ = await services.permissions.request(permission) }
            return
        }
        model.turnOnPrompt = nil
        reload()
        panel?.refit()
    }

    // MARK: - Keyboard

    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case ",": activate(.settings); return true
            case "q": activate(.quit); return true
            default: return false
            }
        }
        model.showsFocusRing = true
        switch Int(event.keyCode) {
        case 123: model.focus.move(.left)
        case 124: model.focus.move(.right)
        case 125: model.focus.move(.down)
        case 126: model.focus.move(.up)
        case 36, 76, 49: // Return, Enter, Space
            guard let current = model.focus.current else { return true }
            if flags.contains(.shift), case let .tile(id) = current {
                showOptionsMenu(id)
            } else {
                activate(current)
            }
        default:
            if let digit = event.charactersIgnoringModifiers.flatMap(Int.init), (1...3).contains(digit) {
                activate(.recent(digit - 1))
                return true
            }
            return false
        }
        return true
    }

    private func showOptionsMenu(_ id: QuickAccessID) {
        guard let entry = entry(id), services.features.status(of: entry.feature.id) == .running,
              let menu = menuBar()?.optionsMenu(for: entry), let view = NSApp.keyWindow?.contentView else { return }
        menu.popUp(positioning: nil, at: CGPoint(x: 20, y: view.bounds.height - 120), in: view)
    }

    // MARK: - Layout grid (Window Layouts icon)

    func showLayoutGrid(below button: NSView) {
        if layoutPanel?.isVisible == true { layoutPanel?.close(); return }
        panel?.close()
        model.window = makeWindow()
        model.layouts = ControlPanelModel.layoutSpecs.map { spec in
            ControlPanelModel.Layout(id: spec.command, title: spec.title(), shortcut: shortcuts.text(for: spec.command), span: spec.span)
        }
        let view = LayoutGridPanel(model: model) { [weak self] id in self?.activate(.layout(id)) }
        let panel = AnchoredPanel(content: view)
        layoutPanel = panel
        panel.show(below: button)
    }
}

/// The Window Layouts icon's small grid.
private struct LayoutGridPanel: View {
    @Bindable var model: ControlPanelModel
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: OmniStyle.s2) {
            switch model.window {
            case let .window(app, title):
                SectionHeader(L10n.Panel.windowSection)
                Text(title.map { L10n.Panel.windowTitle(app, $0) } ?? app).font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).frame(maxWidth: 360, alignment: .leading)
                LayoutGrid(layouts: model.layouts, focused: nil, action: action)
            default:
                Text(L10n.Panel.noWindow).font(.callout).foregroundStyle(.secondary).frame(width: 300, alignment: .leading)
            }
        }
        .frame(width: 360, alignment: .leading)
        .padding(OmniStyle.s3)
        .omniPanelBackground()
    }
}
