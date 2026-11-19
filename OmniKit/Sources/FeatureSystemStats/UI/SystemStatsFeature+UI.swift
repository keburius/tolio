import OmniCore
import SwiftUI

/// Settings anchors of the System Stats page.
enum StatsAnchor {
    static let interval = "systemstats.interval"

    static func item(_ item: StatItem) -> String { "systemstats.item.\(item.rawValue)" }
}

/// What Settings search shows for System Stats.
public extension SystemStatsFeature {
    func makeSettingsHero() -> AnyView? { AnyView(SystemStatsHero()) }

    var settingsEntries: [SettingsEntry] {
        let synonyms: [StatItem: [String]] = [
            .cpu: ["processor", "load"],
            .memory: ["ram"],
            .disk: ["storage", "ssd", "free space"],
            .network: ["internet", "speed", "upload", "download"],
            .battery: ["charge", "power"],
        ]
        let items = StatItem.allCases.map { item in
            SettingsEntry(anchor: StatsAnchor.item(item), label: item.title, keywords: synonyms[item] ?? [])
        }
        return items + [
            SettingsEntry(anchor: StatsAnchor.interval, label: L10n.Stats.refreshEvery, keywords: ["interval", "update", "energy"]),
        ]
    }
}
