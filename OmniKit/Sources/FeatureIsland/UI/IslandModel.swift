import AppKit
import Observation
import OmniCore

/// What every screen's island shares: the music, the Tray, widgets and their
/// data, the calendar and the settings.
@MainActor
@Observable
final class IslandServices {
    enum Look: String, CaseIterable, Codable, Sendable { case black, glass }
    /// How the island looks on a screen without a camera notch.
    enum NoNotchStyle: String, CaseIterable, Codable, Sendable { case notch, handle }

    struct Options: Equatable {
        var showHome = true
        var showMusic = true
        var showCalendar = true
        var showMirror = true
        var showTray = true
        var showWidgets = true
        var showFocus = true
        var musicSwipes = true
        var look: Look = .glass
        var noNotchStyle: NoNotchStyle = .notch
    }

    var options = Options()
    var calendarEvents: [CalendarSource.Item] = []
    var calendarAccess: CalendarSource.Access = .notAsked
    var volume: Double = 0
    var muted = false
    /// Final names of files downloading into Downloads now.
    var downloads: [String] = []
    /// Files being dragged somewhere on screen (opens the Tray near the notch).
    var fileDragActive = false

    let nowPlaying: NowPlaying
    let activities: LiveActivityCenter
    let tray: TrayStore
    let thumbnails = Thumbnails()
    let camera = CameraMirror()
    let workspace: IslandWorkspace
    let load = SystemLoad()
    let shortcuts = ShortcutsLibrary()

    /// Commands from other Tolio features (screenshot, Keep Awake…), by id.
    @ObservationIgnored var command: (String) -> Command? = { _ in nil }
    @ObservationIgnored var requestCalendar: () -> Void = {}
    @ObservationIgnored var openCalendarItem: (CalendarSource.Item) -> Void = { _ in }
    @ObservationIgnored var openSettings: () -> Void = {}
    @ObservationIgnored var airDrop: ([URL]) -> Void = { _ in }
    @ObservationIgnored var share: ([URL], NSView?) -> Void = { _, _ in }
    @ObservationIgnored var closeAll: () -> Void = {}

    init(nowPlaying: NowPlaying, activities: LiveActivityCenter, tray: TrayStore, workspace: IslandWorkspace) {
        self.nowPlaying = nowPlaying
        self.activities = activities
        self.tray = tray
        self.workspace = workspace
    }

    var pages: [IslandModel.Page] {
        var list: [IslandModel.Page] = []
        if options.showHome { list.append(.home) }
        if options.showMusic { list.append(.music) }
        if options.showCalendar { list.append(.calendar) }
        if options.showFocus { list.append(.focus) }
        if options.showTray { list.append(.tray) }
        if options.showWidgets { list.append(.widgets) }
        if options.showMirror { list.append(.mirror) }
        return list.isEmpty ? [.music] : list
    }
}

/// One screen's island: its place, what it's showing and whether the
/// pointer is on it.
@MainActor
@Observable
final class IslandModel {
    enum Page: Int, CaseIterable { case home, music, calendar, focus, tray, widgets, mirror }

    enum Mode: Equatable {
        /// Just the notch (or, with music or an activity, the notch with wings).
        case closed
        /// A short notice under the wings ("AirPods Pro connected").
        case notice
        /// Volume level under the wings.
        case volume
        /// Fully open on a page.
        case open
    }

    let services: IslandServices
    let screenID: CGDirectDisplayID
    var geometry = NotchGeometry(frame: .zero, leftArea: nil, rightArea: nil, menuBarHeight: 24)
    var mode: Mode = .closed
    var page: Page = .home
    var hovering = false
    /// Files are being dragged over the open island.
    var dropTargeted = false
    /// A swipe just skipped a track: which way, for a little nudge.
    var skipNudge: Int = 0

    @ObservationIgnored var onOpenChanged: (Bool) -> Void = { _ in }

    init(services: IslandServices, screenID: CGDirectDisplayID) {
        self.services = services
        self.screenID = screenID
    }

    var nowPlaying: NowPlaying { services.nowPlaying }
    var options: IslandServices.Options { services.options }
    var pages: [Page] { services.pages }

    /// A screen without a notch, shown as a thin handle.
    var isHandle: Bool { !geometry.hasHardwareNotch && options.noNotchStyle == .handle }

    /// The activity shown in the wings, if any.
    var activity: LiveActivity? { services.activities.current() }

    /// Music wings stay while a song is loaded (playing or paused).
    var showsMusicWings: Bool {
        options.showMusic && nowPlaying.hasTrack && (activity.map { $0.priority < .high && $0.expires == nil } ?? true)
    }

    var hasWings: Bool { activity != nil || showsMusicWings || mode == .volume }

    // MARK: Sizes

    static let wing: CGFloat = 38
    static let openWidth: CGFloat = 640
    /// The tab bar floating under the open island.
    static let tabBarHeight: CGFloat = 40
    static let tabBarGap: CGFloat = 10

    /// Each page is as tall as it needs; the island grows to fit.
    static func openHeight(_ page: Page) -> CGFloat {
        switch page {
        case .home: 206
        case .music: 178
        case .calendar: 282
        case .focus: 218
        case .mirror: 236
        case .tray: 204
        case .widgets: 226
        }
    }

    /// Room the window needs: the tallest page plus the tab bar under it.
    static var windowContentSize: CGSize {
        CGSize(width: openWidth, height: Page.allCases.map(openHeight).max()! + tabBarGap + tabBarHeight + 10)
    }

    /// How much a closed island swells under the pointer.
    static let hoverGrowth = CGSize(width: 12, height: 3)
    static let handleSize = CGSize(width: 96, height: 7)

    /// The notch's own size (the handle's when this screen shows a handle).
    var notchSize: CGSize { isHandle ? Self.handleSize : geometry.notch.size }

    /// The band at the top that lines up with the menu bar.
    var bandHeight: CGFloat { isHandle ? max(geometry.notch.height, 26) : geometry.notch.height }

    /// The black shape's size for the current mode.
    var size: CGSize {
        let notch = isHandle && mode != .closed ? CGSize(width: 190, height: bandHeight) : notchSize
        switch mode {
        case .open:
            return CGSize(width: max(Self.openWidth, notch.width + 2 * Self.wing), height: Self.openHeight(page))
        case .notice:
            return CGSize(width: notch.width + 2 * Self.wing + 70, height: notch.height + 30)
        case .volume:
            return CGSize(width: notch.width + 2 * Self.wing + 20, height: notch.height + 22)
        case .closed:
            if isHandle {
                if hasWings { return CGSize(width: 190 + 2 * Self.wing, height: bandHeight) }
                return hovering ? CGSize(width: notch.width + 24, height: notch.height + 3) : notch
            }
            // Pointing at the island makes it swell a little (it opens on click).
            let grow = hovering ? Self.hoverGrowth : .zero
            if hasWings { return CGSize(width: notch.width + 2 * Self.wing + grow.width, height: notch.height + grow.height) }
            return CGSize(width: notch.width + grow.width, height: notch.height + grow.height)
        }
    }

    func turnPage(_ step: Int) {
        let list = pages
        guard let index = list.firstIndex(of: page), !list.isEmpty else { return }
        let next = min(max(index + step, 0), list.count - 1)
        if list[next] != page { show(list[next]) }
    }

    /// Which way the last page change went: pages further right come in
    /// from the right, earlier ones from the left.
    var pageForward = true

    /// Switches page with a slide in the direction of travel. The direction is
    /// set first and the page a moment later, so the outgoing page (whose
    /// slide was fixed when it last drew) leaves the same way.
    func show(_ target: Page) {
        guard target != page else { return }
        let list = pages
        let forward = (list.firstIndex(of: target) ?? 0) > (list.firstIndex(of: page) ?? 0)
        pageForward = forward
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.page = target
                // Live updates (camera, stats, Shortcuts) follow the new page.
                self?.onOpenChanged(true)
            }
        }
    }
}

/// The Widgets page's data: layout, timers, to-dos, the note and favourite
/// shortcuts. Saved in settings as it changes.
@MainActor
@Observable
final class IslandWorkspace {
    static let layoutKey = SettingKey.feature("island", "widgets", default: IslandWidget.defaultLayout.map(\.rawValue))
    static let timersKey = SettingKey.feature("island", "timers", default: [IslandTimer]())
    static let todosKey = SettingKey.feature("island", "todos", default: [IslandTodo]())
    static let noteKey = SettingKey.feature("island", "note", default: "")
    static let shortcutsKey = SettingKey.feature("island", "favoriteShortcuts", default: [String]())
    static let focusKey = SettingKey.feature("island", "focusMinutes", default: 25)
    static let restKey = SettingKey.feature("island", "restMinutes", default: 5)

    @ObservationIgnored private let settings: SettingsStore

    var layout: [IslandWidget] { didSet { settings.set(layout.map(\.rawValue), for: Self.layoutKey) } }
    var timers: [IslandTimer] { didSet { settings.set(timers, for: Self.timersKey) } }
    var todos: [IslandTodo] { didSet { settings.set(todos, for: Self.todosKey) } }
    var note: String { didSet { settings.set(note, for: Self.noteKey) } }
    var favoriteShortcuts: [String] { didSet { settings.set(favoriteShortcuts, for: Self.shortcutsKey) } }
    /// Minutes the timer wheel is set to for the next new timer.
    var nextMinutes = 5

    /// Called when a timer runs out (sound, notice).
    @ObservationIgnored var onTimerDone: (IslandTimer) -> Void = { _ in }
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(settings: SettingsStore) {
        self.settings = settings
        layout = IslandWidget.layout(from: settings.value(Self.layoutKey))
        timers = settings.value(Self.timersKey)
        todos = settings.value(Self.todosKey)
        note = settings.value(Self.noteKey)
        favoriteShortcuts = settings.value(Self.shortcutsKey)
        focusSetting = max(settings.value(Self.focusKey), 1)
        restSetting = max(settings.value(Self.restKey), 1)
        tick()
    }

    var focusMinutes: Int { max(settings.value(Self.focusKey), 1) }
    var restMinutes: Int { max(settings.value(Self.restKey), 1) }

    // MARK: Focus page

    /// Minutes set on the Focus page's ruler, kept per kind (saved).
    private(set) var focusSetting = 25
    private(set) var restSetting = 5

    func minutes(for kind: IslandTimer.Kind) -> Int { kind == .rest ? restSetting : focusSetting }

    func setMinutes(_ minutes: Int, for kind: IslandTimer.Kind) {
        let value = max(minutes, 1)
        if kind == .rest { restSetting = value; settings.set(value, for: Self.restKey) }
        else { focusSetting = value; settings.set(value, for: Self.focusKey) }
    }

    /// The running (or paused) focus or break, if any.
    var session: IslandTimer? { timers.first { $0.kind != .plain } }

    /// Starts a focus or a break; when it ends the other one follows.
    func startSession(_ kind: IslandTimer.Kind) {
        var timer = IslandTimer(kind: kind == .rest ? .rest : .focus, duration: TimeInterval(minutes(for: kind) * 60))
        timer.start(at: Date())
        timers.removeAll { $0.kind != .plain }
        timers.append(timer)
        tick()
    }

    /// Plays a sound when a timer ends (saved with the feature's settings).
    var soundOn: Bool {
        get { access(keyPath: \.soundOn); return settings.value(IslandFeature.timerSoundKey) }
        set { withMutation(keyPath: \.soundOn) { settings.set(newValue, for: IslandFeature.timerSoundKey) } }
    }

    /// When the stopwatch started; it counts up in the wings while it runs.
    private(set) var stopwatchStart: Date?

    func toggleStopwatch() {
        if stopwatchStart == nil {
            let start = Date()
            stopwatchStart = start
            LiveActivityCenter.shared.post(LiveActivity(
                id: "island.stopwatch", leading: .symbol("stopwatch"), trailing: .elapsed(start),
                title: L10n.Island.stopwatch, tint: "white", priority: .low
            ))
        } else {
            stopwatchStart = nil
            LiveActivityCenter.shared.remove("island.stopwatch")
        }
    }

    // MARK: Timers

    func addTimer(minutes: Int) {
        var timer = IslandTimer(duration: TimeInterval(max(minutes, 1) * 60))
        timer.start(at: Date())
        timers.append(timer)
        tick()
    }

    func startPomodoro() {
        var timer = IslandTimer(kind: .focus, duration: TimeInterval(focusMinutes * 60))
        timer.start(at: Date())
        timers.removeAll { $0.kind != .plain }
        timers.append(timer)
        tick()
    }

    func toggle(_ id: UUID) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        if timers[index].isRunning { timers[index].pause(at: Date()) } else { timers[index].start(at: Date()) }
        tick()
    }

    func removeTimer(_ id: UUID) {
        timers.removeAll { $0.id == id }
        tick()
    }

    /// Checks running timers once a second while any run; publishes the
    /// soonest one as a live activity in the wings.
    private func tick() {
        ticker?.cancel()
        publishActivity()
        guard timers.contains(where: \.isRunning) else { return }
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.checkFinished()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func checkFinished() {
        let now = Date()
        var changed = false
        for (index, timer) in timers.enumerated().reversed() where timer.isFinished(at: now) {
            onTimerDone(timer)
            changed = true
            if var next = timer.nextPomodoro(focus: TimeInterval(focusMinutes * 60), rest: TimeInterval(restMinutes * 60)) {
                next.start(at: now)
                timers[index] = next
            } else {
                timers.remove(at: index)
            }
        }
        if changed { tick() }
    }

    private func publishActivity() {
        let now = Date()
        guard let soonest = timers.filter(\.isRunning).min(by: { $0.timeLeft(at: now) < $1.timeLeft(at: now) }),
              let end = soonest.endsAt else {
            LiveActivityCenter.shared.remove("island.timer")
            return
        }
        let symbol = soonest.kind == .focus ? "brain.head.profile" : (soonest.kind == .rest ? "cup.and.saucer.fill" : "timer")
        LiveActivityCenter.shared.post(LiveActivity(
            id: "island.timer", leading: .symbol(symbol), trailing: .countdown(end),
            title: L10n.Island.timer, tint: soonest.kind == .rest ? "green" : "orange", priority: .low
        ))
    }

    // MARK: To-dos

    func addTodo(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        todos.insert(IslandTodo(title: trimmed), at: 0)
    }

    func toggleTodo(_ id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].done.toggle()
    }

    func removeTodo(_ id: UUID) { todos.removeAll { $0.id == id } }

    func clearDone() { todos.removeAll(where: \.done) }

    // MARK: Layout

    func toggleWidget(_ widget: IslandWidget) {
        if layout.contains(widget) { layout.removeAll { $0 == widget } } else { layout.append(widget) }
    }

    func move(_ widget: IslandWidget, by step: Int) {
        layout = IslandWidget.move(widget, by: step, in: layout)
    }

    func resetLayout() { layout = IslandWidget.defaultLayout }
}
