import OmniCore

/// Settings anchors of the Launcher's page.
enum PaletteAnchor {
    static let apps = "palette.apps"
    static let currencyFetch = "palette.currencyFetch"
    static let defaultCurrency = "palette.defaultCurrency"
    static let clearUsage = "palette.clearUsage"
}

/// What Settings, the Shortcuts page and Reset/Erase show for the Launcher.
public extension PaletteFeature {
    var declaredHotkeys: [HotkeyAction] { [Self.toggleHotkey] }

    var settingsEntries: [SettingsEntry] {
        [
            SettingsEntry(anchor: PaletteAnchor.apps, label: L10n.Launcher.appsFound, keywords: ["applications", "rescan"]),
            SettingsEntry(anchor: PaletteAnchor.currencyFetch, label: L10n.Launcher.downloadRates, keywords: ["exchange", "money", "internet"]),
            SettingsEntry(anchor: PaletteAnchor.defaultCurrency, label: L10n.Launcher.defaultCurrency, keywords: ["exchange", "money"]),
            SettingsEntry(anchor: PaletteAnchor.clearUsage, label: L10n.Launcher.clearUsage, keywords: ["recent", "history", "privacy"]),
        ]
    }

    /// The usage history is what the user did, so a reset keeps it.
    var userContentSettingKeys: Set<String> { [Self.usageKey.name] }

    var erasableDataDescription: String? {
        guard let settings = currentSettings, !settings.value(Self.usageKey).entries.isEmpty else { return nil }
        return L10n.Launcher.usageHistory
    }

    func eraseData() { clearUsage() }
}
