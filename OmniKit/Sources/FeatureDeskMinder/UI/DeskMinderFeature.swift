import AppKit
import Observation
import OmniCore
import OmniPlatform
import os
import SwiftUI

/// Desk Minder: a bar above the Dock sets a reminder by stretching or by
/// typing a time. When it's due it fills the screen with Close and Snooze.
/// Optionally mirrored in Apple Reminders so other devices alert too.
@MainActor
@Observable
public final class DeskMinderFeature: Feature {
    public static var showHotkey: HotkeyAction {
        HotkeyAction(
            id: "deskminder.show", title: L10n.DeskMinder.hotkey,
            defaultCombo: KeyCombo(keyCode: 14, modifiers: [.control, .option, .command]) // ⌃⌥⌘E
        )
    }

    static let mindersKey = SettingKey.feature("deskminder", "minders", default: [Minder]())
    static let syncKey = SettingKey.feature("deskminder", "sync", default: true)
    static let keepBarKey = SettingKey.feature("deskminder", "keepBar", default: false)
    static let snoozeKey = SettingKey.feature("deskminder", "snooze", default: 10)
    static let soundsKey = SettingKey.feature("deskminder", "sounds", default: true)
    static let snoozeChoices = [5, 10, 15, 30, 60]

    enum Anchor {
        static let sync = "deskminder.sync"
        static let keepBar = "deskminder.keepBar"
        static let snooze = "deskminder.snooze"
        static let upcoming = "deskminder.upcoming"
    }

    public let id: FeatureID = "deskminder"
    public var displayName: String { L10n.DeskMinder.displayName }
    public var summary: String { L10n.DeskMinder.summary }
    public let symbolName = "alarm"
    public let requiredPermissions: Set<Permission> = []
    public var declaredHotkeys: [HotkeyAction] { [Self.showHotkey] }
    public var userContentSettingKeys: Set<String> { [Self.mindersKey.name] }

    /// Bumped when Reminders access changes, so Settings refreshes.
    private(set) var accessRevision = 0
    @ObservationIgnored private(set) var settings: SettingsStore?
    @ObservationIgnored let sync = RemindersSync()
    @ObservationIgnored private var windows: MinderWindows?
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var showing: Minder.ID?
    @ObservationIgnored private var log: Logger?

    public init() {}

    public func enable(context: FeatureContext) throws {
        settings = context.settings
        log = context.log
        let windows = MinderWindows()
        self.windows = windows
        context.lifetime.add { [weak self] in
            LiveActivityCenter.shared.remove("deskminder.next")
            self?.timer?.cancel()
            self?.timer = nil
            windows.close()
        }
        context.registerHotkey(Self.showHotkey) { [weak self] in self?.toggleBar() }
        context.registerCommand(Command(
            id: "deskminder.show", title: L10n.DeskMinder.hotkey, keywords: ["remind", "reminder", "timer", "alarm"],
            symbolName: symbolName
        ) { [weak self] in self?.showBar(takeFocus: true) })
        let wake = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.reschedule() } }
        context.lifetime.add { NSWorkspace.shared.notificationCenter.removeObserver(wake) }
        if settings?.value(Self.keepBarKey) == true { showBar(takeFocus: false, idle: !minders.isEmpty) }
        reschedule()
    }

    public func disable() {
        windows = nil
        settings = nil
        showing = nil
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(DeskMinderSettingsView(feature: self, settings: settings))
    }

    public var tagline: String { L10n.DeskMinder.tagline }

    public func makeSettingsHero() -> AnyView? {
        AnyView(DeskMinderHero())
    }

    public var erasableDataDescription: String? {
        let count = minders.count
        return count == 0 ? nil : L10n.DeskMinder.erase(count)
    }

    public func eraseData() {
        minders.forEach(sync.remove)
        settings?.set([], for: Self.mindersKey)
        reschedule()
    }

    // MARK: Reminders

    var minders: [Minder] { (settings?.value(Self.mindersKey) ?? []).sorted { $0.due < $1.due } }

    private func save(_ list: [Minder]) {
        settings?.set(list, for: Self.mindersKey)
        reschedule()
    }

    func add(title: String, due: Date) {
        var minder = Minder(title: title, due: due)
        let wantsSync = settings?.value(Self.syncKey) == true
        if wantsSync { minder.reminderID = sync.add(minder) }
        save(minders + [minder])
        // First time: ask for Reminders access, then sync this one too.
        if wantsSync, sync.access == .notAsked {
            Task { @MainActor [weak self] in
                guard let self, await self.sync.requestAccess() else { return }
                self.accessRevision += 1
                self.attachSyncedCopy(to: minder.id)
            }
        }
        log?.notice("Desk Minder: reminder added (synced: \(minder.reminderID != nil, privacy: .public))")
        HUD.show(L10n.DeskMinder.added(MinderBarView.clock(due)), symbol: "alarm")
        if settings?.value(Self.keepBarKey) == true {
            // Rebuild so the [+] [count] shows the new count.
            showBar(takeFocus: false, idle: true)
        } else {
            // Let the bar fold into [+] [count] for a moment, then go.
            hideTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.6))
                guard !Task.isCancelled else { return }
                self?.windows?.hideBar()
            }
        }
    }

    /// Adds the Apple Reminders copy of a reminder saved before access was given.
    private func attachSyncedCopy(to id: Minder.ID) {
        var list = minders
        guard let index = list.firstIndex(where: { $0.id == id }), list[index].reminderID == nil,
              let reminderID = sync.add(list[index]) else { return }
        list[index].reminderID = reminderID
        save(list)
    }

    /// Deletes a reminder that hasn't come up yet (and its synced copy).
    func remove(_ minder: Minder) {
        sync.remove(minder)
        save(minders.filter { $0.id != minder.id })
    }

    // MARK: Bar

    func toggleBar() {
        guard let windows else { return }
        if windows.isBarShown, settings?.value(Self.keepBarKey) != true { windows.hideBar() } else { showBar(takeFocus: true) }
    }

    func showBar(takeFocus: Bool, idle: Bool = false) {
        hideTask?.cancel()
        windows?.showBar(
            MinderBarView(
                sounds: settings?.value(Self.soundsKey) ?? true,
                startIdle: idle,
                pending: minders.count,
                onAdd: { [weak self] title, due in self?.add(title: title, due: due) },
                onClose: { [weak self] in self?.closeBar() },
                onShowList: { [weak self] in
                    guard let self else { return }
                    QuickAccessCenter.openSettings?(self.id)
                }
            ),
            takeFocus: takeFocus,
            onCancel: { [weak self] in self?.closeBar() }
        )
    }

    func closeBar() {
        windows?.hideBar()
        if settings?.value(Self.keepBarKey) == true { settings?.set(false, for: Self.keepBarKey) }
    }

    func keepBarChanged(_ keep: Bool) {
        if keep { showBar(takeFocus: false, idle: !minders.isEmpty) } else { windows?.hideBar() }
    }

    // MARK: Due

    /// Waits for the next reminder; anything already due shows now.
    func reschedule() {
        timer?.cancel()
        // The next reminder counts down in Notch Island's wings (if that's on).
        if let next = minders.first, next.due.timeIntervalSinceNow < 3 * 3600 {
            LiveActivityCenter.shared.post(LiveActivity(
                id: "deskminder.next", leading: .symbol("alarm"), trailing: .countdown(next.due),
                title: next.title, tint: "orange", priority: .normal
            ))
        } else {
            LiveActivityCenter.shared.remove("deskminder.next")
        }
        guard showing == nil, let next = minders.first else { return }
        let wait = next.due.timeIntervalSinceNow
        timer = Task { @MainActor [weak self] in
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            self?.present(next.id)
        }
    }

    private func present(_ id: Minder.ID) {
        guard let minder = minders.first(where: { $0.id == id }), let windows else { return }
        showing = id
        NSSound(named: "Glass")?.play()
        windows.showAlert(
            MinderAlertView(
                title: minder.title,
                snoozeChoices: Self.snoozeChoices,
                defaultSnooze: settings?.value(Self.snoozeKey) ?? 10,
                onDone: { [weak self] in self?.finish(id) },
                onSnooze: { [weak self] minutes in self?.snooze(id, minutes: minutes) }
            ),
            onCancel: { [weak self] in self?.finish(id) }
        )
    }

    /// Close: the reminder is done (ticked off in Apple Reminders too).
    func finish(_ id: Minder.ID) {
        if let minder = minders.first(where: { $0.id == id }) { sync.complete(minder) }
        windows?.hideAlert()
        showing = nil
        save(minders.filter { $0.id != id })
    }

    func snooze(_ id: Minder.ID, minutes: Int) {
        var list = minders
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        list[index].due = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sync.update(list[index])
        windows?.hideAlert()
        showing = nil
        save(list)
        HUD.show(L10n.DeskMinder.snoozed(MinderBarView.clock(list[index].due)), symbol: "timer")
    }

    // MARK: Apple Reminders

    func requestRemindersAccess() {
        Task { @MainActor in
            _ = await sync.requestAccess()
            accessRevision += 1
        }
    }
}

extension DeskMinderFeature: NextReminderProviding {
    public var nextReminder: (title: String, due: Date)? {
        minders.first.map { ($0.title, $0.due) }
    }

    public func snoozeNextReminder() {
        guard let next = minders.first else { return }
        snooze(next.id, minutes: settings?.value(Self.snoozeKey) ?? 10)
    }
}
