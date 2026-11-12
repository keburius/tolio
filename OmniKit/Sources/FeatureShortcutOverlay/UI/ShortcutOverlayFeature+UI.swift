import OmniCore

/// Settings anchors of the Shortcut Cheat Sheet page.
enum ShortcutOverlayAnchor {
    static let trigger = "shortcuts.trigger"
    static let includeDisabled = "shortcuts.includeDisabled"
}

/// What Settings and the Shortcuts page show for the Shortcut Cheat Sheet.
public extension ShortcutOverlayFeature {
    var declaredHotkeys: [HotkeyAction] { [Self.showHotkey] }

    /// The double-press-and-hold, as currently set ("⌘ ⌘ hold" while off).
    var gestures: [GestureShortcut] {
        let trigger = settings?.value(Self.triggerKey) ?? Self.triggerKey.defaultValue
        let text = trigger == .off ? L10n.Common.off : L10n.Cheatsheet.gesture(trigger.symbol)
        return [GestureShortcut(
            id: "shortcuts.hold", title: L10n.Cheatsheet.showTitle, gesture: text,
            settingsAnchor: ShortcutOverlayAnchor.trigger
        )]
    }

    var settingsEntries: [SettingsEntry] {
        [
            SettingsEntry(anchor: ShortcutOverlayAnchor.trigger, label: L10n.Cheatsheet.openWith,
                          keywords: ["double press", "hold", "command key"]),
            SettingsEntry(anchor: ShortcutOverlayAnchor.includeDisabled, label: L10n.Cheatsheet.includeDisabled,
                          keywords: ["dimmed", "grayed out"]),
        ]
    }
}
