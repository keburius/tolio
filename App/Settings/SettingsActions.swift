import OmniCore
import OmniPlatform

/// Reset and erase, shared by feature pages and General.
@MainActor
extension AppServices {
    /// Options and shortcuts back to defaults; on/off and user content kept.
    /// A running feature is restarted so it picks up the defaults.
    func resetToDefaults(_ feature: any Feature) {
        let keys = SettingsReset.keysToRemove(
            feature: feature.id,
            storedKeys: settings.storedKeys(withPrefix: "feature.\(feature.id.rawValue)."),
            keep: feature.userContentSettingKeys
        )
        for key in keys { settings.removeValue(named: key) }
        hotkeys.resetToDefaults(feature.declaredHotkeys.map(\.id))
        restartIfRunning(feature)
    }

    /// Every feature's options, all shortcuts and the menu bar layout.
    func resetAllSettings() {
        for feature in features.features {
            let keys = SettingsReset.keysToRemove(
                feature: feature.id,
                storedKeys: settings.storedKeys(withPrefix: "feature.\(feature.id.rawValue)."),
                keep: feature.userContentSettingKeys
            )
            for key in keys { settings.removeValue(named: key) }
        }
        settings.reset(HotkeyManager.bindingsKey)
        settings.reset(MenuBarConfiguration.key)
        hotkeys.resetToDefaults(features.features.flatMap(\.declaredHotkeys).map(\.id) + [AppHotkeys.controlPanel.id])
        for feature in features.features { restartIfRunning(feature) }
    }

    private func restartIfRunning(_ feature: any Feature) {
        guard features.status(of: feature.id) == .running else { return }
        features.setWanted(false, for: feature.id)
        features.setWanted(true, for: feature.id)
    }
}
