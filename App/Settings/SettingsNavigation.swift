import Observation
import OmniCore
import OmniPlatform

/// Where Settings is and what it highlights. Shared by the sidebar, search and pages.
@MainActor
@Observable
final class SettingsNavigation {
    var page: SettingsPage = .overview
    var query = ""
    /// The anchor briefly highlighted after a search result is chosen.
    var highlight: String?
    /// Diagnostics is listed only when Settings was opened with ⌥ held.
    var showsHiddenFeatures = false

    func open(_ page: SettingsPage, anchor: String? = nil) {
        self.page = page
        query = ""
        highlight = anchor
        guard anchor != nil else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            if self?.highlight == anchor { self?.highlight = nil }
        }
    }
}

extension FeatureRegistry.Status {
    var badge: StatusBadgeKind {
        switch self {
        case .off: .off
        case .running: .working
        case .waitingForPermissions: .needsPermission
        case let .failed(message): .problem(message)
        }
    }
}

typealias StatusBadgeKind = StatusBadge.Kind

/// Feature lists as Settings shows them (hidden ones only on request).
@MainActor
extension AppServices {
    func visibleFeatures(includingHidden: Bool) -> [any Feature] {
        features.features.filter { includingHidden || !$0.isHidden }
    }

    /// The feature's main shortcut or gesture, for cards.
    func mainShortcutText(of feature: any Feature) -> String? {
        if let action = feature.declaredHotkeys.first, let combo = hotkeys.bindings.combo(for: action) {
            return combo.displayString
        }
        return feature.gestures.first?.gesture
    }

    /// Everything Settings search can find.
    func settingsIndex(includingHidden: Bool) -> SettingsIndex {
        var items: [SettingsIndex.Item] = [
            .init(page: .overview, pageTitle: L10n.SettingsUI.overview, label: L10n.SettingsUI.overview),
            .init(page: .menuBar, pageTitle: L10n.SettingsUI.menuBar, label: L10n.SettingsUI.separateIcons, keywords: ["status bar", "icons"], anchor: "menubar.mode"),
            .init(page: .menuBar, pageTitle: L10n.SettingsUI.menuBar, label: L10n.SettingsUI.oneIcon, keywords: ["single", "notch"], anchor: "menubar.mode"),
            .init(page: .menuBar, pageTitle: L10n.SettingsUI.menuBar, label: L10n.SettingsUI.quickActions, keywords: ["order", "reorder", "icons"], anchor: "menubar.items"),
            .init(page: .shortcuts, pageTitle: L10n.SettingsUI.shortcuts, label: L10n.SettingsUI.shortcuts, keywords: ["hotkeys", "keyboard", "conflict"]),
            .init(page: .permissions, pageTitle: L10n.SettingsUI.permissions, label: L10n.SettingsUI.permissions, keywords: ["privacy", "accessibility", "screen recording", "microphone"]),
            .init(page: .general, pageTitle: L10n.SettingsUI.general, label: L10n.SettingsUI.openAtLogin, keywords: ["startup", "launch", "login"], anchor: "general.login"),
            .init(page: .general, pageTitle: L10n.SettingsUI.general, label: L10n.SettingsUI.openSetupGuide, keywords: ["onboarding", "welcome", "tour"], anchor: "general.setup"),
            .init(page: .general, pageTitle: L10n.SettingsUI.general, label: L10n.SettingsUI.language, keywords: ["translation"], anchor: "general.language"),
            .init(page: .general, pageTitle: L10n.SettingsUI.general, label: L10n.SettingsUI.resetAllSettings, keywords: ["defaults"], anchor: "general.reset"),
        ]
        for feature in visibleFeatures(includingHidden: includingHidden) {
            let page = SettingsPage.feature(feature.id)
            items.append(.init(page: page, pageTitle: feature.displayName, label: feature.displayName, keywords: [feature.summary]))
            for entry in feature.settingsEntries {
                items.append(.init(page: page, pageTitle: feature.displayName, label: entry.label, keywords: entry.keywords, anchor: entry.anchor))
            }
            for action in feature.declaredHotkeys {
                items.append(.init(page: page, pageTitle: feature.displayName, label: action.title, keywords: ["shortcut"], anchor: "shortcut.\(action.id)"))
            }
        }
        return SettingsIndex(items: items)
    }
}
