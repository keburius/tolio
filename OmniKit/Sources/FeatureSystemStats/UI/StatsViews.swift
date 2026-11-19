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
        VStack(alignment: .leading, spacing: 14) {
            ASSection(L10n.Stats.showInMenuBar, footer: L10n.Stats.nothingSelectedHelp) {
                ForEach(StatItem.allCases, id: \.self) { item in
                    HStack(spacing: 12) {
                        Text(item.title).font(AS.body).foregroundStyle(AS.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ASSwitch(item.title, isOn: binding(item))
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 40)
                    .settingsAnchor(StatsAnchor.item(item))
                }
            }
            ASSection(footer: L10n.Stats.refreshHelp) {
                ASRow(L10n.Stats.refreshEvery) {
                    ASPopUp(L10n.Stats.refreshEvery, selection: Binding(
                        get: { settings.value(SystemStatsFeature.intervalKey) },
                        set: { settings.set($0, for: SystemStatsFeature.intervalKey); feature.restartTimer() }
                    ), options: [1, 2, 5].map { (Double($0), L10n.Stats.seconds($0)) })
                }
                .settingsAnchor(StatsAnchor.interval)
            }
        }
    }

    private func binding(_ item: StatItem) -> Binding<Bool> {
        Binding(
            get: { settings.value(SystemStatsFeature.itemsKey).contains(item) },
            set: { on in
                var items = settings.value(SystemStatsFeature.itemsKey)
                if on { items.insert(item) } else { items.remove(item) }
                settings.set(items, for: SystemStatsFeature.itemsKey)
                feature.refreshTitle()
            }
        )
    }
}

/// The example under the header: numbers as they appear in the menu bar,
/// over a small bar chart.
struct SystemStatsHero: View {
    private let green = Color(hex: 0x59D177)

    var body: some View {
        ASStage(tint: green) {
            VStack(spacing: 14) {
                HStack(spacing: 18) {
                    reading(L10n.Stats.heroCPU, StatsFormat.percent(0.12))
                    reading(L10n.Stats.heroMemory, StatsFormat.percent(0.61))
                    reading(L10n.Stats.heroNetwork, "↓ " + StatsFormat.rate(1_200_000))
                }
                .padding(.horizontal, 16)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(hex: 0x15161B)))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array([26.0, 48, 36, 70, 44, 58].enumerated()), id: \.offset) { index, height in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(index == 3 ? green : .white.opacity(0.24))
                            .frame(width: 16, height: height)
                    }
                }
                .frame(height: 70, alignment: .bottom)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Stats.heroLabel)
        .accessibilityAddTraits(.isImage)
    }

    private func reading(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(AS.textSecondary)
            Text(value).font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(.white)
        }
    }
}
