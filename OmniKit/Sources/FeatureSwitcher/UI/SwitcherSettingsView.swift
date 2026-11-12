import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

extension SwitcherFeature {
    /// The trigger as a gesture row: the chosen keys while on, the default while off.
    public var gestures: [GestureShortcut] {
        let trigger = settings?.value(Self.triggerKey) ?? Self.triggerKey.defaultValue
        return [GestureShortcut(
            id: "switcher.trigger", title: L10n.Switcher.gestureTitle, gesture: trigger.keys, settingsAnchor: Anchor.trigger
        )]
    }

    public var settingsEntries: [SettingsEntry] {
        [
            SettingsEntry(anchor: Anchor.trigger, label: L10n.Switcher.trigger, keywords: ["alt tab", "option tab", "switch", "modifier"]),
            SettingsEntry(anchor: Anchor.thumbnails, label: L10n.Switcher.thumbnails, keywords: ["thumbnails", "preview", "screenshot"]),
            SettingsEntry(anchor: Anchor.minimized, label: L10n.Switcher.includeMinimized, keywords: ["dock", "minimise"]),
            SettingsEntry(anchor: Anchor.hidden, label: L10n.Switcher.includeHidden, keywords: ["hide"]),
            SettingsEntry(anchor: Anchor.otherSpaces, label: L10n.Switcher.includeOtherSpaces, keywords: ["desktops", "mission control"]),
        ]
    }
}

/// Palette results for "win …".
@MainActor
final class WindowSearchProvider: SearchProvider {
    let keyword = "win"
    var title: String { L10n.Switcher.searchTitle }
    private weak var controller: SwitcherController?

    init(controller: SwitcherController) {
        self.controller = controller
    }

    func results(for query: String, limit: Int) -> [SearchResult] {
        guard let controller else { return [] }
        let needle = query.lowercased()
        return controller.currentWindows()
            .filter { needle.isEmpty || $0.title.lowercased().contains(needle) || $0.appName.lowercased().contains(needle) }
            .prefix(limit)
            .map { record in
                let appURL = NSRunningApplication(processIdentifier: record.pid)?.bundleURL
                return SearchResult(
                    id: "\(record.id)", title: record.title,
                    subtitle: record.state == .normal ? record.appName : L10n.Switcher.appWithState(record.appName, record.state.label),
                    icon: appURL.map { .file($0) } ?? .symbol("macwindow"),
                    primaryAction: { [weak controller] in controller?.focus(record) }
                )
            }
    }
}

extension WindowState {
    var label: String {
        switch self {
        case .normal: L10n.Switcher.stateOpen
        case .minimized: L10n.Switcher.stateMinimized
        case .hidden: L10n.Switcher.stateHidden
        case .otherSpace: L10n.Switcher.stateOtherSpace
        }
    }
}

struct SwitcherSettingsView: View {
    let feature: SwitcherFeature
    let settings: SettingsStore

    var body: some View {
        Picker(L10n.Switcher.trigger, selection: settings.binding(SwitcherFeature.triggerKey)) {
            ForEach(SwitcherTrigger.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .settingsAnchor(SwitcherFeature.Anchor.trigger)
        Text(L10n.Switcher.triggerHelp)
            .font(.caption).foregroundStyle(.secondary)
        Toggle(L10n.Switcher.thumbnails, isOn: settings.binding(SwitcherFeature.thumbnailsKey))
            .settingsAnchor(SwitcherFeature.Anchor.thumbnails)
        Toggle(L10n.Switcher.includeMinimized, isOn: settings.binding(SwitcherFeature.minimizedKey))
            .settingsAnchor(SwitcherFeature.Anchor.minimized)
        Toggle(L10n.Switcher.includeHidden, isOn: settings.binding(SwitcherFeature.hiddenKey))
            .settingsAnchor(SwitcherFeature.Anchor.hidden)
        Toggle(L10n.Switcher.includeOtherSpaces, isOn: settings.binding(SwitcherFeature.otherSpacesKey))
            .settingsAnchor(SwitcherFeature.Anchor.otherSpaces)
        Text(L10n.Switcher.otherSpacesHelp)
            .font(.caption).foregroundStyle(.secondary)
        if feature.tapFailed {
            Text(L10n.Switcher.stoppedHelp)
                .font(.caption).foregroundStyle(.orange)
        }
    }
}
