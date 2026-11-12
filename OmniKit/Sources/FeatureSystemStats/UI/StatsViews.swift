import OmniCore
import OmniPlatform
import SwiftUI

/// Detail popover from the menu bar item.
struct StatsPopoverView: View {
    let feature: SystemStatsFeature

    var body: some View {
        let s = feature.snapshot
        VStack(alignment: .leading, spacing: OmniStyle.s3) {
            if let cpu = s.cpu {
                row(L10n.Stats.cpu, StatsFormat.percent(cpu), gauge: cpu)
            }
            if let used = s.memoryUsed, let total = s.memoryTotal, total > 0 {
                row(L10n.Stats.memory, L10n.Stats.usedOf(StatsFormat.bytes(used), StatsFormat.bytes(total)), gauge: Double(used) / Double(total))
            }
            if let free = s.diskFree, let total = s.diskTotal, total > 0 {
                row(L10n.Stats.startupDisk, L10n.Stats.freeOf(StatsFormat.storage(free), StatsFormat.storage(total)),
                    gauge: 1 - Double(free) / Double(total))
            }
            if let down = s.downloadRate, let up = s.uploadRate {
                row(L10n.Stats.network, "↓ \(StatsFormat.rate(down))   ↑ \(StatsFormat.rate(up))", gauge: nil)
            }
            if let battery = s.battery {
                let state = battery.isCharging ? L10n.Stats.charging : (battery.onAC ? L10n.Stats.onAdapter : L10n.Stats.onBattery)
                let time = battery.minutesRemaining.map { minutes in
                    let duration = StatsFormat.duration(minutes: minutes)
                    return battery.isCharging ? L10n.Stats.toFull(duration) : L10n.Stats.left(duration)
                }
                let value = (["\(battery.percent)%", state] + [time].compactMap { $0 }).joined(separator: " · ")
                row(L10n.Stats.battery, value, gauge: Double(battery.percent) / 100)
            }
            Text(L10n.Stats.noTemperatures)
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(OmniStyle.s4)
        .frame(width: 300)
    }

    private func row(_ title: String, _ value: String, gauge: Double?) -> some View {
        VStack(alignment: .leading, spacing: OmniStyle.s1) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(value).monospacedDigit().foregroundStyle(.secondary)
            }
            if let gauge { ProgressView(value: min(max(gauge, 0), 1)) }
        }
    }
}

struct SystemStatsSettingsView: View {
    let feature: SystemStatsFeature
    let settings: SettingsStore

    var body: some View {
        Section(L10n.Stats.showInMenuBar) {
            ForEach(StatItem.allCases, id: \.self) { item in
                Toggle(item.title, isOn: Binding(
                    get: { settings.value(SystemStatsFeature.itemsKey).contains(item) },
                    set: { on in
                        var items = settings.value(SystemStatsFeature.itemsKey)
                        if on { items.insert(item) } else { items.remove(item) }
                        settings.set(items, for: SystemStatsFeature.itemsKey)
                        feature.refreshTitle()
                    }
                ))
                .settingsAnchor(StatsAnchor.item(item))
            }
            Text(L10n.Stats.nothingSelectedHelp)
                .font(.caption).foregroundStyle(.secondary)
        }
        Picker(L10n.Stats.refreshEvery, selection: Binding(
            get: { settings.value(SystemStatsFeature.intervalKey) },
            set: { settings.set($0, for: SystemStatsFeature.intervalKey); feature.restartTimer() }
        )) {
            ForEach([1, 2, 5], id: \.self) { seconds in
                Text(L10n.Stats.seconds(seconds)).tag(Double(seconds))
            }
        }
        .settingsAnchor(StatsAnchor.interval)
        Text(L10n.Stats.refreshHelp)
            .font(.caption).foregroundStyle(.secondary)
        Text(L10n.Stats.temperaturesHelp)
            .font(.caption).foregroundStyle(.secondary)
    }
}
