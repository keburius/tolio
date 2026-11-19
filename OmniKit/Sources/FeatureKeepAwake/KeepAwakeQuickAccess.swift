import Foundation
import OmniCore

extension KeepAwakeFeature {
    public var settingsEntries: [SettingsEntry] {
        let synonyms = ["caffeine", "caffeinate", "insomnia", "amphetamine", "sleep", "awake"]
        return [
            SettingsEntry(anchor: Anchor.status, label: L10n.KeepAwake.status, keywords: synonyms + ["timer", "duration"]),
            SettingsEntry(anchor: Anchor.display, label: L10n.KeepAwake.keepDisplayOn, keywords: synonyms + ["screen", "monitor", "dim"]),
            SettingsEntry(anchor: Anchor.apps, label: L10n.KeepAwake.appsSection, keywords: synonyms + ["apps", "running", "rules"]),
        ]
    }

    public var userContentSettingKeys: Set<String> { [Self.ruleAppsKey.name] }

    public var erasableDataDescription: String? {
        guard let count = settings?.value(Self.ruleAppsKey).count, count > 0 else { return nil }
        return L10n.KeepAwake.eraseDescription(count)
    }

    public func eraseData() {
        removeAllRules()
    }

    /// The cup icon: click toggles like the hotkey; the menu offers durations.
    public var quickAccessItems: [QuickAccessItem] {
        [
            QuickAccessItem(
                id: .keepAwake, title: displayName, symbolName: symbolName, activeSymbolName: "bolt.fill",
                clickHint: L10n.KeepAwake.clickHint, shortcutID: Self.toggleHotkey.id,
                state: { [weak self] in self?.quickAccessState() ?? .idle },
                primary: { [weak self] in self?.toggle() },
                menu: { [weak self] in self?.quickAccessMenu() ?? [] }
            ),
        ]
    }

    /// The running session, if any, for display.
    var currentSession: KeepAwakeSession { KeepAwakePolicy.effective(session, now: Date()) }

    func quickAccessState() -> QuickAccessState {
        switch currentSession {
        case .off: QuickAccessState(isActive: false)
        case .indefinite: QuickAccessState(isActive: true, detail: L10n.KeepAwake.detailOn)
        case let .until(end): QuickAccessState(isActive: true, detail: L10n.KeepAwake.detailUntil(Self.shortTime(end)))
        }
    }

    func quickAccessMenu() -> [MenuEntry] {
        let session = currentSession
        var entries: [MenuEntry] = []
        switch session {
        case .off: entries.append(.header(L10n.Common.off))
        case .indefinite: entries.append(.header(L10n.KeepAwake.headerOnUntilOff))
        case let .until(end): entries.append(.header(L10n.KeepAwake.headerOnUntil(Self.shortTime(end))))
        }
        entries.append(.separator)
        if session != .off {
            entries.append(.action(MenuAction(L10n.KeepAwake.turnOff, shortcutID: Self.toggleHotkey.id) { [weak self] in
                self?.start(.off)
            }))
        }
        for minutes in KeepAwakePolicy.presetMinutes {
            let title = L10n.KeepAwake.forDuration(KeepAwakePolicy.durationTitle(minutes: minutes))
            entries.append(.action(MenuAction(title) { [weak self] in self?.start(minutes: minutes) }))
        }
        entries.append(.action(MenuAction(L10n.KeepAwake.untilTurnedOff) { [weak self] in
            self?.start(.indefinite)
        }))
        entries.append(.separator)
        let displayOn = settings?.value(Self.displayKey) ?? Self.displayKey.defaultValue
        entries.append(.action(MenuAction(L10n.KeepAwake.keepDisplayOnMenu, isChecked: displayOn) { [weak self] in
            self?.setKeepDisplayOn(!displayOn)
        }))
        return entries
    }

    /// Localized short time, e.g. "18:30" or "6:30 PM".
    static func shortTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
