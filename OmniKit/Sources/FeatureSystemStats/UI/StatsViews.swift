import OmniCore
import OmniPlatform
import SwiftUI

/// Detail popover from the menu bar item.
struct StatsPopoverView: View {
    let feature: SystemStatsFeature

    var body: some View {
        let s = feature.snapshot
        VStack(alignment: .leading, spacing: 12) {
            if let cpu = s.cpu {
                row("CPU", StatsFormat.percent(cpu), gauge: cpu)
            }
            if let used = s.memoryUsed, let total = s.memoryTotal, total > 0 {
                row("Memory", "\(StatsFormat.bytes(used)) of \(StatsFormat.bytes(total))", gauge: Double(used) / Double(total))
            }
            if let free = s.diskFree, let total = s.diskTotal, total > 0 {
                row("Disk (startup)", "\(StatsFormat.storage(free)) free of \(StatsFormat.storage(total))",
                    gauge: 1 - Double(free) / Double(total))
            }
            if let down = s.downloadRate, let up = s.uploadRate {
                row("Network", "↓ \(StatsFormat.rate(down))   ↑ \(StatsFormat.rate(up))", gauge: nil)
            }
            if let battery = s.battery {
                let state = battery.isCharging ? "Charging" : (battery.onAC ? "On power adapter" : "On battery")
                let time = battery.minutesRemaining.map { " · \(StatsFormat.duration(minutes: $0)) \(battery.isCharging ? "to full" : "left")" } ?? ""
                row("Battery", "\(battery.percent)% · \(state)\(time)", gauge: Double(battery.percent) / 100)
            }
            Text("Temperatures and fans aren't shown: on Apple silicon they're only available through undocumented interfaces.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 300)
    }

    private func row(_ title: String, _ value: String, gauge: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
        Section("Show in the menu bar") {
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
            }
            Text("With nothing selected, the menu bar shows an icon; click it for details.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Picker("Refresh every", selection: Binding(
            get: { settings.value(SystemStatsFeature.intervalKey) },
            set: { settings.set($0, for: SystemStatsFeature.intervalKey); feature.restartTimer() }
        )) {
            Text("1 second").tag(1.0)
            Text("2 seconds").tag(2.0)
            Text("5 seconds").tag(5.0)
        }
        Text("Reading the numbers is nearly free. Each time the menu bar text changes, macOS redraws the item's copies (about 30 ms of CPU), so a longer interval uses less energy. Measured: about 1.7% CPU at 2 s, 0.7% at 5 s, 0.2% with icon only.")
            .font(.caption).foregroundStyle(.secondary)
        Text("Temperatures and fan speeds are left out on purpose: on Apple silicon they can only be read through undocumented, chip-specific interfaces that aren't reliable.")
            .font(.caption).foregroundStyle(.secondary)
    }
}
