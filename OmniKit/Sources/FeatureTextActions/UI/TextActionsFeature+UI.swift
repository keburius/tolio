import Foundation
import OmniCore

/// What the app shows for Text Actions: settings search, reset and erase.
/// No new behaviour.
public extension TextActionsFeature {
    var settingsEntries: [SettingsEntry] {
        var entries = [
            SettingsEntry(anchor: Anchor.mouseTrigger, label: L10n.TextActions.mouseTrigger, keywords: ["mouse", "drag", "double-click", "selection"]),
            SettingsEntry(anchor: Anchor.keyboardTrigger, label: L10n.TextActions.keyboardTrigger, keywords: ["keyboard", "shift", "arrows", "selection"]),
            SettingsEntry(anchor: Anchor.searchEngine, label: L10n.TextActions.searchWith, keywords: ["search engine", "google", "duckduckgo", "bing", "kagi"]),
            SettingsEntry(anchor: Anchor.copyFallback, label: L10n.TextActions.copyBriefly, keywords: ["copy", "clipboard", "chrome", "slack"]),
            SettingsEntry(anchor: Anchor.excludedApps, label: L10n.TextActions.neverShowIn, keywords: ["exclude", "ignore", "apps", "disable"]),
        ]
        entries += TextActionCatalog.builtIn.map {
            SettingsEntry(anchor: Anchor.action($0.id), label: $0.title, keywords: ["action", "button"])
        }
        return entries
    }

    var userContentSettingKeys: Set<String> { [Self.excludedKey.name] }

    var erasableDataDescription: String? {
        guard let settings else { return nil }
        let count = settings.value(Self.excludedKey).count
        return count > 0 ? L10n.TextActions.eraseDescription(count) : nil
    }

    func eraseData() {
        settings?.set([], for: Self.excludedKey)
    }
}

extension TextActionsFeature {
    /// Settings anchors (`.settingsAnchor(_:)`) on the settings page.
    enum Anchor {
        static let mouseTrigger = "textactions.mouseTrigger"
        static let keyboardTrigger = "textactions.keyboardTrigger"
        static let searchEngine = "textactions.searchEngine"
        static let copyFallback = "textactions.copyFallback"
        static let excludedApps = "textactions.excludedApps"
        static func action(_ id: String) -> String { "textactions.action.\(id)" }
    }
}
