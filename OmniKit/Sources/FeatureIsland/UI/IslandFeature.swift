import AppKit
import EventKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Notch Island: the notch becomes a live island. Closed it's the notch
/// (with wings for music, timers, downloads, meetings or a notice). Pointing
/// at it makes it swell; a click opens it on Music, Calendar, Focus, the Mirror, the Tray (files you
/// park there, AirDrop) and Widgets (timers, to-dos, a note, quick actions,
/// shortcuts, stats). Every screen can have its own.
@MainActor
@Observable
public final class IslandFeature: Feature {
    public static var openHotkey: HotkeyAction {
        HotkeyAction(
            id: "island.open", title: L10n.Island.hotkey,
            defaultCombo: KeyCombo(keyCode: 34, modifiers: [.control, .option, .command]) // ⌃⌥⌘I
        )
    }

    static let homeKey = SettingKey.feature("island", "homePage", default: true)
    static let musicKey = SettingKey.feature("island", "music", default: true)
    static let calendarKey = SettingKey.feature("island", "calendar", default: true)
    static let mirrorKey = SettingKey.feature("island", "mirror", default: true)
    static let trayKey = SettingKey.feature("island", "tray", default: true)
    static let widgetsKey = SettingKey.feature("island", "widgetsPage", default: true)
    static let focusPageKey = SettingKey.feature("island", "focusPage", default: true)
    static let meetingKey = SettingKey.feature("island", "meetings", default: true)
    static let downloadsKey = SettingKey.feature("island", "downloads", default: false)
    static let virtualKey = SettingKey.feature("island", "virtualNotch", default: false)
    static let allDisplaysKey = SettingKey.feature("island", "allDisplays", default: false)
    static let hoverKey = SettingKey.feature("island", "openOnHover", default: false)
    static let hoverDelayKey = SettingKey.feature("island", "hoverDelay", default: 220)
    static let swipesKey = SettingKey.feature("island", "musicSwipes", default: true)
    static let lookKey = SettingKey.feature("island", "look", default: IslandServices.Look.glass.rawValue)
    static let noNotchStyleKey = SettingKey.feature("island", "noNotchStyle", default: IslandServices.NoNotchStyle.notch.rawValue)
    static let dragOpensKey = SettingKey.feature("island", "dragOpensTray", default: true)
    static let removeAfterDragKey = SettingKey.feature("island", "removeAfterDrag", default: false)
    static let timerSoundKey = SettingKey.feature("island", "timerSound", default: true)

    enum Anchor {
        static let music = "island.music"
        static let live = "island.live"
        static let hover = "island.hover"
        static let widgets = "island.widgets"
        static let tray = "island.tray"
        static let look = "island.look"
    }

    public let id: FeatureID = "island"
    public var displayName: String { L10n.Island.displayName }
    public var summary: String { L10n.Island.summary }
    public let symbolName = "rectangle.topthird.inset.filled"
    public let group: FeatureGroup = .island
    public let requiredPermissions: Set<Permission> = []
    public var declaredHotkeys: [HotkeyAction] { [Self.openHotkey] }

    @ObservationIgnored private(set) var settings: SettingsStore?
    @ObservationIgnored private(set) var services: IslandServices?
    @ObservationIgnored private var islands: [CGDirectDisplayID: (panel: IslandPanel, model: IslandModel)] = [:]
    @ObservationIgnored private let nowPlaying = NowPlaying()
    @ObservationIgnored private let calendar = CalendarSource()
    @ObservationIgnored private let downloads = DownloadsMonitor()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private var hoverTasks: [CGDirectDisplayID: Task<Void, Never>] = [:]
    @ObservationIgnored private var modeTask: Task<Void, Never>?
    @ObservationIgnored private var meetingTask: Task<Void, Never>?
    @ObservationIgnored private var openedBy: [CGDirectDisplayID: OpenReason] = [:]
    @ObservationIgnored private var dragPasteboardCount = NSPasteboard(name: .drag).changeCount
    @ObservationIgnored private var commandLookup: () -> [Command] = { [] }

    enum OpenReason { case hover, click, drag, key }

    public init() {}

    public func enable(context: FeatureContext) throws {
        settings = context.settings
        let directory = (try? AppPaths.applicationSupport())?.appendingPathComponent("Island", isDirectory: true)
        let workspace = IslandWorkspace(settings: context.settings)
        let services = IslandServices(
            nowPlaying: nowPlaying, activities: LiveActivityCenter.shared, tray: TrayStore(directory: directory), workspace: workspace
        )
        commandLookup = { context.availableCommands }
        services.command = { [weak self] id in self?.commandLookup().first { $0.id == id } }
        services.requestCalendar = { [weak self] in self?.requestCalendar() }
        services.openCalendarItem = { [weak self] item in self?.closeAll(); self?.calendar.open(item) }
        services.openSettings = { [weak self] in
            guard let self else { return }
            self.closeAll()
            QuickAccessCenter.openSettings?(self.id)
        }
        services.airDrop = { [weak self] urls in self?.airDrop(urls) }
        services.share = { [weak self] urls, view in self?.share(urls, from: view) }
        services.closeAll = { [weak self] in self?.closeAll() }
        workspace.onTimerDone = { [weak self] timer in self?.timerDone(timer) }
        self.services = services

        context.registerHotkey(Self.openHotkey) { [weak self] in self?.toggleOpen() }
        let keywords = ["notch", "island", "nook", "music"]
        context.registerCommand(Command(id: "island.open", title: L10n.Island.hotkey, keywords: keywords, symbolName: symbolName) { [weak self] in
            self?.toggleOpen()
        })
        context.registerCommand(Command(id: "island.tray", title: L10n.Island.openTray, keywords: ["notch", "tray", "shelf", "files", "airdrop"],
                                        symbolName: "tray.full") { [weak self] in self?.openPage(.tray) })
        context.registerCommand(Command(id: "island.widgets", title: L10n.Island.openWidgets, keywords: ["notch", "timer", "pomodoro", "todo", "notes"],
                                        symbolName: "square.grid.2x2") { [weak self] in self?.openPage(.widgets) })
        context.registerCommand(Command(id: "island.focus", title: L10n.Island.openFocus, keywords: ["notch", "focus", "pomodoro", "timer", "break"],
                                        symbolName: "timer") { [weak self] in self?.openPage(.focus) })
        context.registerCommand(Command(id: "island.mirror", title: L10n.Island.openMirror, keywords: ["notch", "camera", "mirror"],
                                        symbolName: "camera") { [weak self] in self?.openMirror() })

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.place() }
        })
        observers.append(center.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshCalendar() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshCalendar(); self?.place() }
        })
        startDragWatch()
        context.lifetime.add { [weak self] in self?.teardown() }

        applySettings()
        services.tray.prune()
    }

    public func disable() {
        settings = nil
        services = nil
    }

    private func teardown() {
        observers.forEach {
            NotificationCenter.default.removeObserver($0)
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        observers.removeAll()
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        hoverTasks.values.forEach { $0.cancel() }
        modeTask?.cancel()
        meetingTask?.cancel()
        nowPlaying.stop()
        downloads.stop()
        services?.camera.stop()
        services?.load.setLive(false)
        for (panel, _) in islands.values { panel.orderOut(nil) }
        islands.removeAll()
        for id in ["island.timer", "island.meeting", "island.download", "island.stopwatch"] { LiveActivityCenter.shared.remove(id) }
    }

    public func makeSettingsView() -> AnyView {
        guard let settings, let services else { return AnyView(EmptyView()) }
        return AnyView(IslandSettingsView(feature: self, settings: settings, workspace: services.workspace))
    }

    // MARK: Settings

    /// Starts only the watchers the settings ask for.
    func applySettings() {
        guard let settings, let services else { return }
        services.options = .init(
            showHome: settings.value(Self.homeKey), showMusic: settings.value(Self.musicKey), showCalendar: settings.value(Self.calendarKey),
            showMirror: settings.value(Self.mirrorKey), showTray: settings.value(Self.trayKey),
            showWidgets: settings.value(Self.widgetsKey), showFocus: settings.value(Self.focusPageKey),
            musicSwipes: settings.value(Self.swipesKey),
            look: IslandServices.Look(rawValue: settings.value(Self.lookKey)) ?? .glass,
            noNotchStyle: IslandServices.NoNotchStyle(rawValue: settings.value(Self.noNotchStyleKey)) ?? .notch
        )
        if settings.value(Self.musicKey) { nowPlaying.start() } else { nowPlaying.stop() }

        if settings.value(Self.downloadsKey) {
            downloads.onChange = { [weak self] active, finished in self?.downloadsChanged(active, finished: finished) }
            downloads.start()
        } else {
            downloads.stop()
            LiveActivityCenter.shared.remove("island.download")
        }

        meetingTask?.cancel()
        if settings.value(Self.calendarKey), settings.value(Self.meetingKey) {
            meetingTask = Task { @MainActor [weak self] in
                var minute = 0
                while !Task.isCancelled {
                    if minute % 5 == 0 { self?.refreshCalendar() }
                    self?.updateMeeting()
                    minute += 1
                    try? await Task.sleep(for: .seconds(30))
                }
            }
        } else {
            LiveActivityCenter.shared.remove("island.meeting")
        }
        place()
    }

    // MARK: Windows

    /// One island per chosen screen: screens with a notch, or every screen;
    /// with no notch anywhere, the main screen when that setting is on.
    func place() {
        guard let services, let settings else { return }
        let screens = NSScreen.screens
        var chosen = settings.value(Self.allDisplaysKey) ? screens : screens.filter { $0.safeAreaInsets.top > 0 }
        if chosen.isEmpty, settings.value(Self.virtualKey), let main = NSScreen.main ?? screens.first { chosen = [main] }

        let wanted = Set(chosen.map(Self.displayID))
        for (id, island) in islands where !wanted.contains(id) {
            island.panel.orderOut(nil)
            islands[id] = nil
        }
        for screen in chosen {
            let id = Self.displayID(screen)
            let island = islands[id] ?? makeIsland(id: id, services: services)
            let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
            island.model.geometry = NotchGeometry(
                frame: screen.frame, leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea,
                menuBarHeight: menuBar > 0 ? menuBar : 24
            )
            island.panel.setFrame(island.model.geometry.windowFrame(openSize: IslandModel.windowContentSize), display: true)
            island.panel.orderFrontRegardless()
            islands[id] = island
        }
    }

    var hasHardwareNotch: Bool { NSScreen.screens.contains { $0.safeAreaInsets.top > 0 } }

    private static func displayID(_ screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    private func makeIsland(id: CGDirectDisplayID, services: IslandServices) -> (panel: IslandPanel, model: IslandModel) {
        let model = IslandModel(services: services, screenID: id)
        model.onOpenChanged = { [weak self] _ in self?.openChanged() }
        let panel = IslandPanel()
        let host = IslandHostingView(rootView: IslandRoot(model: model, feature: self))
        panel.onGesture = { [weak self, weak model] gesture in
            guard let self, let model else { return }
            self.gesture(gesture, on: model)
        }
        panel.contentView = host
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self, weak model] _ in
            MainActor.assumeIsolated {
                guard let self, let model, model.mode == .open, !model.hovering else { return }
                self.close(model)
            }
        })
        return (panel, model)
    }

    private var models: [IslandModel] { islands.values.map(\.model) }

    /// The island under the pointer, else the one on the main screen, else any.
    private var focusedModel: IslandModel? {
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }), let island = islands[Self.displayID(screen)] {
            return island.model
        }
        if let main = NSScreen.main, let island = islands[Self.displayID(main)] { return island.model }
        return islands.values.first?.model
    }

    // MARK: Opening

    func hoverChanged(_ inside: Bool, on model: IslandModel) {
        model.hovering = inside
        let id = model.screenID
        hoverTasks[id]?.cancel()
        if inside {
            guard settings?.value(Self.hoverKey) == true, model.mode != .open else { return }
            let delay = settings?.value(Self.hoverDelayKey) ?? 220
            hoverTasks[id] = Task { @MainActor [weak self, weak model] in
                try? await Task.sleep(for: .milliseconds(delay))
                guard !Task.isCancelled, let model else { return }
                self?.open(model, reason: .hover)
            }
        } else if model.mode == .open, !model.dropTargeted {
            // Typing in a note or to-do: stay open until you click elsewhere.
            if let panel = islands[id]?.panel, panel.isKeyWindow, panel.firstResponder is NSText { return }
            let delay = switch openedBy[id] ?? .hover {
            case .hover: 350
            case .drag: 900
            case .click, .key: 700
            }
            hoverTasks[id] = Task { @MainActor [weak self, weak model] in
                try? await Task.sleep(for: .milliseconds(delay))
                guard !Task.isCancelled, let model, !model.hovering, !model.dropTargeted else { return }
                self?.close(model)
            }
        }
    }

    func clicked(_ model: IslandModel) {
        guard model.mode != .open else { return }
        open(model, reason: .click)
    }

    func toggleOpen() {
        guard let model = focusedModel else { return }
        if model.mode == .open { close(model) } else { open(model, reason: .key) }
    }

    func openPage(_ page: IslandModel.Page) {
        guard let model = focusedModel, model.pages.contains(page) else { return }
        model.page = page
        if model.mode != .open { open(model, reason: .key) }
    }

    private func openMirror() {
        guard let model = focusedModel, services?.options.showMirror == true else { return }
        model.page = .mirror
        if model.mode != .open { open(model, reason: .key) }
        openChanged()
    }

    func open(_ model: IslandModel, reason: OpenReason) {
        guard islands[model.screenID]?.panel.isVisible == true else { return }
        openedBy[model.screenID] = reason
        if !model.pages.contains(model.page) { model.page = model.pages.first ?? .music }
        model.mode = .open
        AppFeel.tap(.levelChange)
        if reason == .key { islands[model.screenID]?.panel.makeKey() }
        openChanged()
    }

    func close(_ model: IslandModel) {
        guard model.mode == .open else { return }
        model.mode = .closed
        model.dropTargeted = false
        openChanged()
    }

    func closeAll() { models.forEach(close) }

    /// Starts live updates only while some island is open.
    func openChanged() {
        guard let services else { return }
        let open = models.filter { $0.mode == .open }
        nowPlaying.setLive(!open.isEmpty)
        if !open.isEmpty { refreshCalendar() }
        let widgetsShown = open.contains { $0.page == .widgets }
        services.load.setLive(widgetsShown && services.workspace.layout.contains(.stats))
        if widgetsShown, services.workspace.layout.contains(.shortcuts), !services.shortcuts.loaded { services.shortcuts.load() }
        if open.contains(where: { $0.page == .tray }) { services.tray.prune() }
        if open.contains(where: { $0.page == .mirror }) { services.camera.start() } else { services.camera.stop() }
        if open.isEmpty { islands.values.forEach { $0.panel.resignKey() } }
    }

    // MARK: Gestures

    private func gesture(_ gesture: SwipeReader.Gesture, on model: IslandModel) {
        if model.mode == .open {
            switch gesture {
            case .left: model.turnPage(1); AppFeel.tick()
            case .right: model.turnPage(-1); AppFeel.tick()
            case .up: close(model)
            case .down: break
            }
            openChanged()
            return
        }
        switch gesture {
        case .down: open(model, reason: .click)
        case .left, .right:
            guard services?.options.musicSwipes == true, nowPlaying.hasTrack else { return }
            if gesture == .left { nowPlaying.next() } else { nowPlaying.previous() }
            model.skipNudge = gesture == .left ? 1 : -1
            AppFeel.tap(.generic)
            Task { @MainActor [weak model] in
                try? await Task.sleep(for: .milliseconds(260))
                model?.skipNudge = 0
            }
        case .up: break
        }
    }

    // MARK: Dragging files to the notch

    /// While files are dragged anywhere, an island whose notch the pointer
    /// comes near opens on the Tray.
    private func startDragWatch() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated { self?.mouseEvent(type) }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp, .leftMouseDown], handler: handler) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp, .leftMouseDown], handler: { event in
            handler(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func mouseEvent(_ type: NSEvent.EventType) {
        guard let services else { return }
        if type == .leftMouseDown {
            // A click on the closed island, right up to the screen's top edge
            // (where the window itself may not get the click).
            let mouse = NSEvent.mouseLocation
            for model in models where model.mode != .open && Self.clickZone(notch: model.geometry.notch, size: model.size).contains(mouse) {
                clicked(model)
            }
            return
        }
        let pasteboard = NSPasteboard(name: .drag)
        if type == .leftMouseUp {
            dragPasteboardCount = pasteboard.changeCount
            guard services.fileDragActive else { return }
            services.fileDragActive = false
            // Islands opened by the drag close shortly after unless the pointer stays.
            for model in models where openedBy[model.screenID] == .drag && model.mode == .open {
                model.dropTargeted = false
                if !model.hovering { hoverChanged(false, on: model) }
            }
            return
        }
        guard settings?.value(Self.dragOpensKey) == true, services.options.showTray else { return }
        if !services.fileDragActive {
            guard pasteboard.changeCount != dragPasteboardCount,
                  pasteboard.types?.contains(.fileURL) == true || pasteboard.types?.contains(.URL) == true else { return }
            services.fileDragActive = true
        }
        let mouse = NSEvent.mouseLocation
        for model in models where model.mode != .open {
            if Self.dragZone(notch: model.geometry.notch).contains(mouse) {
                model.page = .tray
                open(model, reason: .drag)
            }
        }
    }

    /// The closed island's area for clicks: its current size, centred on the
    /// notch, reaching a little past the top edge of the screen.
    nonisolated static func clickZone(notch: CGRect, size: CGSize) -> CGRect {
        let width = max(size.width, notch.width)
        let height = max(size.height, notch.height)
        return CGRect(x: notch.midX - width / 2, y: notch.maxY - height, width: width, height: height + 4)
    }

    /// Where a file drag opens the Tray: as wide as the open island and well
    /// below the top edge, so you can drop before reaching the edge (touching
    /// it makes macOS show the Spaces bar).
    nonisolated static func dragZone(notch: CGRect, openSize: CGSize = CGSize(width: 640, height: 200)) -> CGRect {
        let width = max(openSize.width, notch.width)
        let depth: CGFloat = 150
        return CGRect(x: notch.midX - width / 2, y: notch.maxY - depth, width: width, height: depth + 2)
    }

    // MARK: Sharing

    private func airDrop(_ urls: [URL]) {
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        NSApp.activate()
        closeAll()
        service.perform(withItems: urls)
    }

    private func share(_ urls: [URL], from view: NSView?) {
        guard !urls.isEmpty else { return }
        let anchor = view ?? islands[focusedModel?.screenID ?? 0]?.panel.contentView
        guard let anchor else { return }
        NSApp.activate()
        let picker = NSSharingServicePicker(items: urls)
        picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
    }

    // MARK: Calendar

    private func refreshCalendar() {
        guard let services, settings?.value(Self.calendarKey) == true else { return }
        services.calendarAccess = calendar.access
        // The whole month (for the dots on busy days) and the week ahead.
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let monthStart = cal.dateInterval(of: .month, for: today)?.start ?? today
        let monthEnd = cal.dateInterval(of: .month, for: today)?.end ?? today
        let until = max(monthEnd, cal.date(byAdding: .day, value: 8, to: today) ?? today)
        let days = max(cal.dateComponents([.day], from: monthStart, to: until).day ?? 7, 7)
        services.calendarEvents = calendar.events(from: monthStart, days: days)
        updateMeeting()
    }

    private func requestCalendar() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.calendar.requestAccess()
            self.refreshCalendar()
        }
    }

    /// The next meeting within 10 minutes counts down in the wings.
    private func updateMeeting() {
        guard let services, settings?.value(Self.meetingKey) == true,
              let next = MeetingCountdown.next(services.calendarEvents, now: Date(), start: \.start, allDay: \.allDay) else {
            LiveActivityCenter.shared.remove("island.meeting")
            return
        }
        let started = next.start <= Date()
        LiveActivityCenter.shared.post(LiveActivity(
            id: "island.meeting", leading: .symbol(next.callURL != nil ? "video.fill" : "calendar"),
            trailing: started ? .text(L10n.Island.now) : .countdown(next.start),
            title: next.title, tint: "blue", priority: .normal
        ))
    }

    // MARK: Notices

    /// A short notice: wings plus a line of text under them for a few seconds.
    private func notice(id: String, symbol: String, title: String, tint: String, trailing: LiveActivity.Content? = nil, seconds: Double = 3.5) {
        let until = Date().addingTimeInterval(seconds)
        LiveActivityCenter.shared.post(LiveActivity(
            id: id, leading: .symbol(symbol), trailing: trailing ?? .symbol("checkmark.circle.fill"),
            title: title, tint: tint, priority: .high, expires: until
        ))
        show(.notice, for: seconds) { LiveActivityCenter.shared.remove(id) }
    }

    /// Shows a temporary mode (a notice) on every island that isn't open.
    private func show(_ mode: IslandModel.Mode, for seconds: Double, then done: @escaping @MainActor () -> Void = {}) {
        for model in models where model.mode != .open { model.mode = mode }
        modeTask?.cancel()
        modeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            done()
            for model in self?.models ?? [] where model.mode == mode { model.mode = .closed }
        }
    }

    private func downloadsChanged(_ active: [String], finished: [URL]) {
        services?.downloads = active
        if let first = active.first {
            LiveActivityCenter.shared.post(LiveActivity(
                id: "island.download", leading: .symbol("arrow.down.circle.fill"),
                trailing: .text(active.count > 1 ? "\(active.count)" : ""),
                title: L10n.Island.downloading(first), tint: "blue", priority: .normal
            ))
        } else {
            LiveActivityCenter.shared.remove("island.download")
        }
        if let done = finished.first {
            notice(id: "island.downloaded", symbol: "arrow.down.circle.fill", title: L10n.Island.downloaded(done.lastPathComponent), tint: "blue")
        }
    }

    private func timerDone(_ timer: IslandTimer) {
        if settings?.value(Self.timerSoundKey) == true { NSSound(named: "Glass")?.play() }
        let title = switch timer.kind {
        case .plain: L10n.Island.timeUp
        case .focus: L10n.Island.focusDone
        case .rest: L10n.Island.breakOver
        }
        notice(id: "island.timerDone", symbol: "timer", title: title, tint: "orange", seconds: 5)
    }

    // Tray settings the views read.
    var removesAfterDrag: Bool { settings?.value(Self.removeAfterDragKey) ?? false }
}

/// Wires hover, clicks and actions on one island to the feature.
private struct IslandRoot: View {
    let model: IslandModel
    let feature: IslandFeature

    var body: some View {
        IslandView(model: model)
            .environment(\.islandActions, IslandActions(
                hover: { [weak model] inside in if let model { feature.hoverChanged(inside, on: model) } },
                click: { [weak model] in if let model { feature.clicked(model) } },
                close: { [weak model] in if let model { feature.close(model) } },
                pageChanged: { feature.openChanged() },
                removesAfterDrag: { feature.removesAfterDrag }
            ))
    }
}

/// What the island's views can ask the feature to do.
struct IslandActions: @unchecked Sendable {
    var hover: @MainActor (Bool) -> Void = { _ in }
    var click: @MainActor () -> Void = {}
    var close: @MainActor () -> Void = {}
    /// Call after changing page or the mirror so live updates follow.
    var pageChanged: @MainActor () -> Void = {}
    var removesAfterDrag: @MainActor () -> Bool = { false }
}

private struct IslandActionsKey: EnvironmentKey {
    static let defaultValue = IslandActions()
}

extension EnvironmentValues {
    var islandActions: IslandActions {
        get { self[IslandActionsKey.self] }
        set { self[IslandActionsKey.self] = newValue }
    }
}
