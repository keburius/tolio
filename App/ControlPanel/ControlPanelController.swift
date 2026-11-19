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
        model.grid = makeActions(ControlPanelModel.gridSpecs)
        model.more = makeActions(ControlPanelModel.moreSpecs)
        let running = makeRunning()
        if running != model.running {
            model.running = running
            model.rebuildFocus()
        }
    }

    private func reload() {
        ShortcutLookupText.controlPanel = shortcuts.text(for: AppHotkeys.controlPanel.id)
        model.grid = makeActions(ControlPanelModel.gridSpecs)
        model.more = makeActions(ControlPanelModel.moreSpecs)
        model.running = makeRunning()
        model.layouts = ControlPanelModel.layoutSpecs.map { spec in
            ControlPanelModel.Layout(id: spec.command, title: spec.title(), shortcut: shortcuts.text(for: spec.command), span: spec.span)
        }
        model.rebuildFocus()
    }

    // MARK: - Content

    private func entry(_ id: QuickAccessID) -> MenuBarController.Entry? {
        menuBar()?.entries()[id]
    }

    /// A feature's quick-access item, known even while the feature is off.
    private func quickAccess(_ id: QuickAccessID, of feature: any Feature) -> QuickAccessItem? {
        entry(id)?.item ?? feature.quickAccessItems.first { $0.id == id }
    }

    /// Buttons for the features that exist (hidden or missing ones are left out).
    private func makeActions(_ specs: [ControlPanelModel.Spec]) -> [ControlPanelModel.Action] {
        specs.compactMap { spec in
            guard let feature = services.features.feature(spec.featureID) else { return nil }
            var state: ControlPanelModel.ActionState
            var shortcut: String?
            switch spec.kind {
            case let .quickAccess(id):
                let item = quickAccess(id, of: feature)
                shortcut = shortcuts.text(for: item?.shortcutID) ?? services.mainShortcutText(of: feature).flatMap { KeyCaps.isProse($0) ? nil : $0 }
                state = .ready(active: false)
                if services.features.status(of: feature.id) == .running, let current = item?.state() {
                    state = current.timerStart.map { .recording(elapsed: MenuBarController.elapsed(since: $0)) } ?? .ready(active: current.isActive)
                }
            case .command:
                shortcut = services.mainShortcutText(of: feature).flatMap { KeyCaps.isProse($0) ? nil : $0 }
                state = .ready(active: false)
            }
            switch services.features.status(of: feature.id) {
            case .running: break
            case let .waitingForPermissions(missing):
                state = .needsPermission(feature: feature.displayName, permission: missing.sorted { $0.rawValue < $1.rawValue }.first ?? .accessibility)
            case .off, .failed:
                state = .off(feature: feature.displayName)
            }
            return .init(id: spec.id, featureID: feature.id, title: spec.title(), kind: spec.kind, shortcut: shortcut, state: state)
        }
    }

    /// Energy Mode, the next reminder and System Stats, while they're on.
    private func makeRunning() -> [ControlPanelModel.Running] {
        var rows: [ControlPanelModel.Running] = []
        if let feature = services.features.feature("keepawake"), services.features.status(of: feature.id) == .running,
           let item = quickAccess(.keepAwake, of: feature) {
            let state = item.state()
            rows.append(.init(
                id: "energy", featureID: feature.id,
                title: state.isActive ? L10n.PanelUI.stayingAwake : feature.displayName,
                detail: state.isActive ? (state.detail ?? L10n.PanelUI.on) : L10n.PanelUI.off,
                control: .toggle(isOn: state.isActive)
            ))
        }
        if let feature = services.features.feature("deskminder"), services.features.status(of: feature.id) == .running,
           let provider = feature as? NextReminderProviding, let next = provider.nextReminder {
            let time = next.due.formatted(date: Calendar.current.isDateInToday(next.due) ? .omitted : .abbreviated, time: .shortened)
            rows.append(.init(
                id: "reminder", featureID: feature.id, title: L10n.PanelUI.nextReminderAt(time), detail: next.title,
                control: .button(L10n.PanelUI.snooze)
            ))
        }
        if let stats = statsProvider, let line = stats.statsLine,
           let feature = services.features.features.first(where: { $0 === stats as AnyObject }) {
            rows.append(.init(id: "stats", featureID: feature.id, title: feature.displayName, detail: line, control: .none))
        }
        return rows
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
        case let .action(id):
            guard let action = model.action(id) else { return }
            switch action.state {
            case .off:
                model.turnOnPrompt = id
                panel?.refit()
            case let .needsPermission(_, permission):
                panel?.close()
                Task { _ = await services.permissions.request(permission) }
            case .ready, .recording:
                run(action)
            }
        case let .running(id):
            switch id {
            case "energy":
                if let feature = services.features.feature("keepawake") { quickAccess(.keepAwake, of: feature)?.primary() }
                refreshLive()
            case "reminder":
                (services.features.feature("deskminder") as? NextReminderProviding)?.snoozeNextReminder()
                refreshLive()
                panel?.refit()
            default: break
            }
        case let .tile(id):
            guard let entry = entry(id) else { return }
            closeThen { entry.item.primary() }
        case let .layout(commandID):
            guard let command = services.commands.allCommands.first(where: { $0.id == commandID }) else { return }
            panel?.close()
            layoutPanel?.close()
            command.action()
        case .recent, .showAllClips:
            break
        case .settings:
            panel?.close()
            openSettings(.overview)
        case .quit:
            NSApp.terminate(nil)
        }
    }

    private func run(_ action: ControlPanelModel.Action) {
        switch action.kind {
        case .quickAccess(.windowLayouts):
            // Layouts opens the small grid under the main icon.
            guard let button = menuBar()?.mainButton else { return }
            panel?.close()
            showLayoutGrid(below: button)
        case let .quickAccess(id):
            guard let feature = services.features.feature(action.featureID), let item = quickAccess(id, of: feature) else { return }
            closeThen { item.primary() }
        case let .command(commandID):
            guard let command = services.commands.allCommands.first(where: { $0.id == commandID }) else { return }
            closeThen { command.action() }
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

    private func turnOn(_ id: String) {
        guard let action = model.action(id), let feature = services.features.feature(action.featureID) else { return }
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
            if flags.contains(.shift), case let .action(id) = current,
               let action = model.action(id), case let .quickAccess(qa) = action.kind {
                showOptionsMenu(qa)
            } else {
                activate(current)
            }
        default:
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
        VStack(alignment: .leading, spacing: 8) {
            switch model.window {
            case let .window(app, title):
                Text(L10n.Panel.windowSection).font(AS.font(11.5, .semibold)).foregroundStyle(AS.textSecondary)
                Text(title.map { L10n.Panel.windowTitle(app, $0) } ?? app).font(AS.font(12.5)).foregroundStyle(AS.text)
                    .lineLimit(1).truncationMode(.middle).frame(maxWidth: 360, alignment: .leading)
                LayoutGrid(layouts: model.layouts, focused: nil, action: action)
            default:
                Text(L10n.Panel.noWindow).font(AS.font(12.5)).foregroundStyle(AS.textSecondary).frame(width: 300, alignment: .leading)
            }
        }
        .frame(width: 360, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AS.panel))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        .allSetWindowStyle()
    }
}
