import OmniCore
import OmniPlatform
import SwiftUI

extension KeyboardCleanFeature {
    public var settingsEntries: [SettingsEntry] {
        [
            SettingsEntry(anchor: Anchor.duration, label: L10n.LockKeyboard.unlockAfter, keywords: ["time limit", "timeout", "clean", "wipe"]),
            SettingsEntry(anchor: Anchor.lockNow, label: L10n.LockKeyboard.lockNow, keywords: ["clean", "wipe", "disable keyboard"]),
        ]
    }

    /// The keyboard icon: click locks (after the same short delay as the hotkey).
    public var quickAccessItems: [QuickAccessItem] {
        [
            QuickAccessItem(
                id: .lockKeyboard, title: displayName, symbolName: symbolName,
                clickHint: L10n.LockKeyboard.clickHint, shortcutID: Self.startHotkey.id,
                state: { [weak self] in QuickAccessState(isActive: self?.controller?.isActive ?? false) },
                primary: { [weak self] in self?.startSoon() },
                menu: { [weak self] in self?.quickAccessMenu() ?? [] }
            ),
        ]
    }

    func quickAccessMenu() -> [MenuEntry] {
        let current = settings?.value(Self.durationKey) ?? Self.durationKey.defaultValue
        return [
            .action(MenuAction(L10n.LockKeyboard.lockNow, shortcutID: Self.startHotkey.id) { [weak self] in self?.startSoon() }),
            .separator,
            .submenu(title: L10n.LockKeyboard.unlockAfterMenu, entries: CleaningSession.durationChoices.map { seconds in
                .action(MenuAction(Self.durationTitle(seconds), isChecked: seconds == current) { [weak self] in
                    self?.settings?.set(seconds, for: Self.durationKey)
                })
            }),
        ]
    }
}

struct KeyboardCleanSettingsView: View {
    let feature: KeyboardCleanFeature
    let settings: SettingsStore

    var body: some View {
        Picker(L10n.LockKeyboard.unlockAfter, selection: settings.binding(KeyboardCleanFeature.durationKey)) {
            ForEach(CleaningSession.durationChoices, id: \.self) { seconds in
                Text(KeyboardCleanFeature.durationTitle(seconds)).tag(seconds)
            }
        }
        .settingsAnchor(KeyboardCleanFeature.Anchor.duration)
        Button(L10n.LockKeyboard.lockNow) { feature.startSoon() }
            .settingsAnchor(KeyboardCleanFeature.Anchor.lockNow)
        Text(L10n.LockKeyboard.help)
            .font(.caption).foregroundStyle(.secondary)
    }
}
