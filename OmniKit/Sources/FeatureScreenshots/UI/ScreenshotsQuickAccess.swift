import AppKit
import OmniCore
import OmniPlatform

/// The Screenshot and Screen Recording menu bar icons / control panel tiles.
/// Every action reuses the shortcut's action, started once the menu or
/// panel has closed so it isn't captured.
extension ScreenshotsFeature {
    public var quickAccessItems: [QuickAccessItem] { [screenshotItem, recordingItem] }

    private typealias S = L10n.Screenshots

    private var screenshotItem: QuickAccessItem {
        QuickAccessItem(
            id: .screenshot, title: S.screenshotTitle, symbolName: "camera.viewfinder",
            clickHint: S.screenshotClickHint, shortcutID: Self.areaHotkey.id,
            primary: { [weak self] in self?.perform(\.area) },
            menu: { [weak self] in self?.screenshotMenu() ?? [] }
        )
    }

    private var recordingItem: QuickAccessItem {
        QuickAccessItem(
            id: .recording, title: S.recordingTitle, symbolName: "record.circle",
            clickHint: S.recordingClickHint, shortcutID: Self.recordHotkey.id,
            state: { [weak self] in self?.recordingState ?? .idle },
            primary: { [weak self] in self?.perform(\.record) },
            menu: { [weak self] in self?.recordingMenu() ?? [] }
        )
    }

    /// Active with a running timer while a recording is in progress.
    var recordingState: QuickAccessState {
        guard let recording, recording.isRecording else { return .idle }
        return QuickAccessState(isActive: true, timerStart: recording.startDate)
    }

    private var isRecording: Bool { recording?.isRecording ?? false }

    private func perform(_ action: KeyPath<Actions, Action>) {
        guard let actions else { return }
        Self.afterUICloses(actions[keyPath: action])()
    }

    private func item(_ title: String, _ hotkey: HotkeyAction, _ action: KeyPath<Actions, Action>) -> MenuEntry {
        .action(MenuAction(title, shortcutID: hotkey.id) { [weak self] in self?.perform(action) })
    }

    func screenshotMenu() -> [MenuEntry] {
        guard let settings else { return [] }
        var entries: [MenuEntry] = [
            item(S.captureArea, Self.areaHotkey, \.area),
            item(S.captureScreen, Self.screenHotkey, \.screen),
            item(S.copyTextFromScreen, Self.textHotkey, \.text),
        ]
        if settings.value(Self.scrollingKey) {
            entries.append(item(S.scrollingCapture, Self.scrollingHotkey, \.scrolling))
        }
        let after = settings.value(Self.afterKey)
        entries += [
            .separator,
            item(isRecording ? S.stopRecording : S.recordScreen, Self.recordHotkey, \.record),
            .separator,
            .submenu(title: S.afterCapturingMenu, entries: AfterCapture.allCases.map { choice in
                .action(MenuAction(choice.menuTitle, isChecked: choice == after) { settings.set(choice, for: Self.afterKey) })
            }),
            .action(MenuAction(S.openScreenshotsFolder) { Self.openFolder(settings) }),
        ]
        return entries
    }

    func recordingMenu() -> [MenuEntry] {
        guard let settings else { return [] }
        let fps = settings.value(Self.fpsKey)
        return [
            item(isRecording ? S.stopRecording : S.recordScreenEllipsis, Self.recordHotkey, \.record),
            .separator,
            .submenu(title: S.frameRateMenu, entries: [30, 60].map { value in
                .action(MenuAction(S.fps(value), isChecked: fps == value) { settings.set(value, for: Self.fpsKey) })
            }),
            toggle(S.showPointerMenu, Self.recordCursorKey, settings),
            toggle(S.systemAudioMenu, Self.systemAudioKey, settings),
            toggle(S.microphoneMenu, Self.microphoneKey, settings),
            .action(MenuAction(S.openRecordingsFolder) { Self.openFolder(settings) }),
        ]
    }

    private func toggle(_ title: String, _ key: SettingKey<Bool>, _ settings: SettingsStore) -> MenuEntry {
        let isOn = settings.value(key)
        return .action(MenuAction(title, isChecked: isOn) { settings.set(!isOn, for: key) })
    }

    /// Shows the folder captures and recordings are saved to in Finder.
    static func openFolder(_ settings: SettingsStore) {
        let url = folder(settings)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
}
