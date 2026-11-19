import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

extension DeskMinderFeature {
    public var settingsEntries: [SettingsEntry] {
        [
            SettingsEntry(anchor: Anchor.sync, label: L10n.DeskMinder.sync, keywords: ["icloud", "iphone", "reminders", "sync", "apple"]),
            SettingsEntry(anchor: Anchor.keepBar, label: L10n.DeskMinder.keepBar, keywords: ["dock", "bar", "always"]),
            SettingsEntry(anchor: Anchor.snooze, label: L10n.DeskMinder.snoozeLength, keywords: ["snooze", "later"]),
            SettingsEntry(anchor: Anchor.upcoming, label: L10n.DeskMinder.upcoming, keywords: ["list", "delete", "reminders"]),
        ]
    }
}

struct DeskMinderSettingsView: View {
    let feature: DeskMinderFeature
    let settings: SettingsStore

    private enum Icons {
        static let clock = "M8 2.5a5.5 5.5 0 1 0 .01 0M8 5v3.2l2 1.3"
        static let remove = "M8 2.5a5.5 5.5 0 1 0 .01 0M5.5 8h5"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ASSection {
                ASToggleRow(L10n.DeskMinder.keepBar, subtitle: L10n.DeskMinder.keepBarHelp, isOn: Binding(
                    get: { settings.value(DeskMinderFeature.keepBarKey) },
                    set: { settings.set($0, for: DeskMinderFeature.keepBarKey); feature.keepBarChanged($0) }
                ))
                .settingsAnchor(DeskMinderFeature.Anchor.keepBar)
                ASToggleRow(L10n.DeskMinder.sounds, isOn: settings.binding(DeskMinderFeature.soundsKey))
                ASToggleRow(L10n.DeskMinder.sync, subtitle: L10n.DeskMinder.syncHelp, isOn: settings.binding(DeskMinderFeature.syncKey))
                    .settingsAnchor(DeskMinderFeature.Anchor.sync)
                syncAccessRow
                ASRow(L10n.DeskMinder.snoozeLength) {
                    ASPopUp(
                        L10n.DeskMinder.snoozeLength, selection: settings.binding(DeskMinderFeature.snoozeKey),
                        options: DeskMinderFeature.snoozeChoices.map {
                            ($0, StretchScale.label(minutes: $0, minuteFormat: L10n.DeskMinder.minutes, hourFormat: L10n.DeskMinder.hours))
                        }
                    )
                }
                .settingsAnchor(DeskMinderFeature.Anchor.snooze)
            }
            upcoming
        }
    }

    /// Asks for, or points to, Reminders access while syncing is on.
    @ViewBuilder private var syncAccessRow: some View {
        let _ = feature.accessRevision
        if settings.value(DeskMinderFeature.syncKey) {
            switch feature.sync.access {
            case .allowed:
                EmptyView()
            case .notAsked:
                HStack {
                    Spacer()
                    Button(L10n.DeskMinder.allowReminders) { feature.requestRemindersAccess() }
                        .buttonStyle(.asSecondary)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
            case .denied:
                HStack(alignment: .top, spacing: 10) {
                    LineIcon(ASIcon.warning, size: 14, lineWidth: 2, color: AS.orange).padding(.top, 1)
                    Text(L10n.DeskMinder.remindersDenied)
                        .font(AS.footnote).foregroundStyle(AS.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(L10n.Common.openSystemSettings) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.asSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    private var upcoming: some View {
        let list = feature.minders
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                ASSectionTitle(L10n.DeskMinder.upcoming)
                Spacer()
                Button(L10n.DeskMinder.showBar) { feature.showBar(takeFocus: true) }
                    .buttonStyle(ASButtonStyle(.secondary, height: 22, fontSize: 12))
            }
            .settingsAnchor(DeskMinderFeature.Anchor.upcoming)
            ASCard {
                ASDividedStack {
                    if list.isEmpty {
                        Text(L10n.DeskMinder.noUpcoming)
                            .font(AS.body).foregroundStyle(AS.textTertiary)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    ForEach(list) { minder in
                        HStack(spacing: 10) {
                            LineIcon(Icons.clock, size: 16, color: AS.orange)
                            Text(minder.title).font(AS.body).foregroundStyle(AS.text).lineLimit(1)
                            if minder.reminderID != nil {
                                Image(systemName: "icloud").font(.system(size: 11)).foregroundStyle(AS.textTertiary)
                            }
                            Spacer()
                            Text(MinderBarView.clock(minder.due)).font(AS.body).monospacedDigit().foregroundStyle(AS.textSecondary)
                            Button { feature.remove(minder) } label: {
                                LineIcon(Icons.remove, size: 15, color: AS.textSecondary)
                                    .frame(width: 22, height: 22)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(L10n.Common.remove)
                            .accessibilityLabel(L10n.Common.remove)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                    }
                }
            }
        }
    }
}

/// The example at the top of the page: the bar above the Dock, stretched
/// to 3:15 (the design's 420×164 drawing).
struct DeskMinderHero: View {
    var body: some View {
        ASStage(tint: Color(hex: 0xFF9F0A).opacity(0.8)) {
            Canvas { context, size in
                let orange = Color(hex: 0xFF9F0A)
                func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
                    Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r, style: .continuous)
                }
                func svg(_ data: String) -> Path { SVGPath(data, viewBox: size).path(in: CGRect(origin: .zero, size: size)) }
                let round = StrokeStyle(lineWidth: 2.4, lineCap: .round)

                // The time bubble.
                context.fill(rect(174, 18, 72, 30, 15), with: .color(orange))
                context.draw(Text(verbatim: "3:15").font(AS.font(15, .bold)).foregroundStyle(Color(hex: 0x3A2400)),
                             at: CGPoint(x: 210, y: 33), anchor: .center)
                context.fill(svg("M204 48l6 7 6-7z"), with: .color(orange))

                // The bar.
                context.fill(rect(60, 66, 300, 46, 23), with: .color(Color(hex: 0x15161B)))
                context.stroke(rect(60, 66, 300, 46, 23), with: .color(.white.opacity(0.12)), lineWidth: 1.2)
                context.stroke(Path(ellipseIn: CGRect(x: 79, y: 80, width: 18, height: 18)), with: .color(orange), lineWidth: 2.4)
                context.stroke(svg("M88 84.5v4.8l3 2"), with: .color(orange), style: round)
                context.fill(rect(110, 85, 206, 8, 4), with: .color(.white.opacity(0.12)))
                context.fill(rect(110, 85, 96, 8, 4), with: .color(orange))
                context.stroke(svg("M330 82v14M337 82v14"), with: .color(.white.opacity(0.35)), style: round)
                context.stroke(svg("M40 78l-11 11 11 11M380 78l11 11-11 11"), with: .color(orange),
                               style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                // The Dock.
                context.fill(rect(110, 134, 200, 50, 16), with: .color(.white.opacity(0.08)))
                for x in stride(from: CGFloat(126), through: 266, by: 35) {
                    context.fill(rect(x, 144, 26, 26, 7), with: .color(.white.opacity(0.16)))
                }
            }
            .frame(width: 420, height: 164)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.DeskMinder.heroDescription)
        .accessibilityAddTraits(.isImage)
    }
}
