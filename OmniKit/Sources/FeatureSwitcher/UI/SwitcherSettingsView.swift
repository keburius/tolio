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
        VStack(alignment: .leading, spacing: 14) {
            ASSection(footer: L10n.Switcher.otherSpacesHelp) {
                ASRow(L10n.Switcher.trigger, subtitle: L10n.Switcher.triggerHelp) {
                    ASPopUp(
                        L10n.Switcher.trigger, selection: settings.binding(SwitcherFeature.triggerKey),
                        options: SwitcherTrigger.allCases.map { ($0, $0.label) }
                    )
                }
                .settingsAnchor(SwitcherFeature.Anchor.trigger)
                ASToggleRow(L10n.Switcher.thumbnails, subtitle: L10n.Switcher.thumbnailsSubtitle, isOn: settings.binding(SwitcherFeature.thumbnailsKey))
                    .settingsAnchor(SwitcherFeature.Anchor.thumbnails)
                ASToggleRow(L10n.Switcher.includeMinimized, isOn: settings.binding(SwitcherFeature.minimizedKey))
                    .settingsAnchor(SwitcherFeature.Anchor.minimized)
                ASToggleRow(L10n.Switcher.includeHidden, isOn: settings.binding(SwitcherFeature.hiddenKey))
                    .settingsAnchor(SwitcherFeature.Anchor.hidden)
                ASToggleRow(L10n.Switcher.includeOtherSpaces, isOn: settings.binding(SwitcherFeature.otherSpacesKey))
                    .settingsAnchor(SwitcherFeature.Anchor.otherSpaces)
            }
            if feature.tapFailed {
                ASCard(padding: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        LineIcon(ASIcon.warning, size: 14, lineWidth: 2, color: AS.orange).padding(.top, 1)
                        Text(L10n.Switcher.stoppedHelp).font(AS.body).foregroundStyle(AS.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// The example at the top of the page: the switcher with three windows, the middle one chosen.
struct SwitcherHero: View {
    private static let tint = Color(hex: 0x7674DD)

    var body: some View {
        ASStage(tint: Self.tint.opacity(0.22 / 0.30)) {
            HStack(spacing: 12) {
                tile(selected: false)
                tile(selected: true)
                tile(selected: false)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: 0x15161B)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Switcher.heroLabel)
        .accessibilityAddTraits(.isImage)
    }

    private func tile(selected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return HStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { _ in
                Circle().fill(selected ? Color.white : Color.white.opacity(0.45)).frame(width: 5, height: 5)
            }
        }
        .padding(12) // 3 pt border + 9 pt padding
        .frame(width: 104, height: 74, alignment: .topLeading)
        .background(shape.fill(selected ? Self.tint : Color.white.opacity(0.10)))
        .overlay(shape.strokeBorder(selected ? Color.white : .clear, lineWidth: 3))
    }
}
