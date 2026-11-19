import OmniCore
import OmniPlatform
import SwiftUI

extension KeyboardCleanFeature {
    public var settingsEntries: [SettingsEntry] {
        [
            SettingsEntry(anchor: Anchor.duration, label: L10n.LockKeyboard.unlockAfter, keywords: ["time limit", "timeout", "clean", "wipe"]),
            SettingsEntry(anchor: Anchor.lockNow, label: L10n.LockKeyboard.lockNow, keywords: ["clean", "wipe", "disable keyboard"]),
        ]
    }

    /// The keyboard icon: click locks (after the same short delay as the hotkey).
    public var quickAccessItems: [QuickAccessItem] {
        [
            QuickAccessItem(
                id: .lockKeyboard, title: displayName, symbolName: symbolName,
                clickHint: L10n.LockKeyboard.clickHint, shortcutID: Self.startHotkey.id,
                state: { [weak self] in QuickAccessState(isActive: self?.controller?.isActive ?? false) },
                primary: { [weak self] in self?.startSoon() },
                menu: { [weak self] in self?.quickAccessMenu() ?? [] }
            ),
        ]
    }

    func quickAccessMenu() -> [MenuEntry] {
        let current = settings?.value(Self.durationKey) ?? Self.durationKey.defaultValue
        return [
            .action(MenuAction(L10n.LockKeyboard.lockNow, shortcutID: Self.startHotkey.id) { [weak self] in self?.startSoon() }),
            .separator,
            .submenu(title: L10n.LockKeyboard.unlockAfterMenu, entries: CleaningSession.durationChoices.map { seconds in
                .action(MenuAction(Self.durationTitle(seconds), isChecked: seconds == current) { [weak self] in
                    self?.settings?.set(seconds, for: Self.durationKey)
                })
            }),
        ]
    }
}

struct KeyboardCleanSettingsView: View {
    let feature: KeyboardCleanFeature
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ASSection(footer: L10n.LockKeyboard.help) {
                ASRow(L10n.LockKeyboard.unlockAfter) {
                    ASPopUp(
                        L10n.LockKeyboard.unlockAfter, selection: settings.binding(KeyboardCleanFeature.durationKey),
                        options: CleaningSession.durationChoices.map { ($0, KeyboardCleanFeature.durationTitle($0)) }
                    )
                }
                .settingsAnchor(KeyboardCleanFeature.Anchor.duration)
                ASRow(L10n.LockKeyboard.lockNow, subtitle: L10n.LockKeyboard.lockNowSubtitle) {
                    Button(L10n.LockKeyboard.lockNow) { feature.startSoon() }
                        .buttonStyle(.asSecondary)
                }
                .settingsAnchor(KeyboardCleanFeature.Anchor.lockNow)
            }
        }
    }
}

/// The example at the top of the page: a keyboard with a lock over it.
struct KeyboardCleanHero: View {
    var body: some View {
        ASStage(tint: Color(hex: 0xAEAEB2).opacity(0.26 / 0.30)) {
            Canvas { context, _ in
                let key = Color.white.opacity(0.12)
                let body = Path(roundedRect: CGRect(x: 1, y: 1, width: 282, height: 132), cornerRadius: 16, style: .continuous)
                context.fill(body, with: .color(Color(hex: 0x15161B)))
                context.stroke(body, with: .color(.white.opacity(0.12)), lineWidth: 1.2)
                for row in 0 ..< 3 {
                    for column in 0 ..< 9 {
                        let rect = CGRect(x: 14 + CGFloat(column) * 29, y: 14 + CGFloat(row) * 28, width: 22, height: 22)
                        context.fill(Path(roundedRect: rect, cornerRadius: 5.5, style: .continuous), with: .color(key))
                    }
                }
                context.fill(Path(roundedRect: CGRect(x: 72, y: 100, width: 140, height: 20), cornerRadius: 6, style: .continuous), with: .color(key))
                // The lock badge.
                let badge = Path(ellipseIn: CGRect(x: 142 - 36, y: 67 - 36, width: 72, height: 72))
                context.fill(badge, with: .color(Color(hex: 0xAEAEB2)))
                context.stroke(badge, with: .color(AS.stage), lineWidth: 5)
                let lockColor = Color(hex: 0x1C1C1E)
                context.fill(Path(roundedRect: CGRect(x: 128, y: 63, width: 28, height: 23), cornerRadius: 5.5, style: .continuous), with: .color(lockColor))
                var shackle = Path()
                shackle.move(to: CGPoint(x: 134, y: 63))
                shackle.addLine(to: CGPoint(x: 134, y: 56))
                shackle.addArc(center: CGPoint(x: 142, y: 56), radius: 8, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                shackle.addLine(to: CGPoint(x: 150, y: 63))
                context.stroke(shackle, with: .color(lockColor), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            }
            .frame(width: 284, height: 134)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.LockKeyboard.heroLabel)
        .accessibilityAddTraits(.isImage)
    }
}
