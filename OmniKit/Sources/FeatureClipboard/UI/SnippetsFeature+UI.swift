import Foundation
import OmniCore

/// What the app shows for Text Snippets: the "type its code" gesture,
/// settings search, reset and erase. No new behaviour.
public extension SnippetsFeature {
    var gestures: [GestureShortcut] {
        [GestureShortcut(
            id: "snippets.expand", title: L10n.Snippets.gestureTitle, gesture: L10n.Snippets.gestureHow,
            settingsAnchor: Anchor.list
        )]
    }

    var settingsEntries: [SettingsEntry] {
        [
            SettingsEntry(anchor: Anchor.list, label: L10n.Snippets.list, keywords: ["abbreviation", "code", "expand", "text", "add"]),
            SettingsEntry(anchor: Anchor.placeholders, label: L10n.Snippets.placeholders, keywords: ["date", "time", "cursor", "clipboard"]),
        ]
    }

    var userContentSettingKeys: Set<String> { [Self.snippetsKey.name] }

    var erasableDataDescription: String? {
        guard isOn, !snippets.isEmpty else { return nil }
        return L10n.Snippets.eraseDescription(snippets.count)
    }

    func eraseData() {
        guard isOn else { return }
        setSnippets([])
    }
}

extension SnippetsFeature {
    /// Settings anchors (`.settingsAnchor(_:)`) on the settings page.
    enum Anchor {
        static let list = "snippets.list"
        static let placeholders = "snippets.placeholders"
    }
}
