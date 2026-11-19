import OmniCore
import OmniPlatform
import SwiftUI

extension IslandFeature {
    public var settingsEntries: [SettingsEntry] {
        [
            SettingsEntry(anchor: Anchor.music, label: L10n.Island.nowPlaying, keywords: ["spotify", "music", "now playing", "controls", "calendar", "mirror", "camera", "nook"]),
            SettingsEntry(anchor: Anchor.tray, label: L10n.Island.traySection, keywords: ["tray", "shelf", "files", "airdrop", "drop"]),
            SettingsEntry(anchor: Anchor.widgets, label: L10n.Island.widgetsSection, keywords: ["widgets", "timer", "pomodoro", "focus", "break", "stopwatch", "todo", "notes", "shortcuts", "stats"]),
            SettingsEntry(anchor: Anchor.volume, label: L10n.Island.liveActivities, keywords: ["hud", "sound", "battery", "airpods", "bluetooth", "downloads", "meeting"]),
            SettingsEntry(anchor: Anchor.look, label: L10n.Island.look, keywords: ["glass", "black", "handle", "pill", "displays"]),
            SettingsEntry(anchor: Anchor.hover, label: L10n.Island.openOnHover, keywords: ["hover", "click", "swipe", "notch", "dynamic island"]),
        ]
    }

    public var tagline: String { L10n.Island.tagline }

    public func makeSettingsHero() -> AnyView? { AnyView(IslandHero()) }
}

// MARK: - Hero

/// The open island playing a song, hanging from the top of the stage.
private struct IslandHero: View {
    var body: some View {
        ASStage(tint: Color(hex: 0x8E8E93)) {
            VStack(spacing: 0) {
                island
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Island.heroDescription)
    }

    private var island: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xFF9500), Color(hex: 0xFF2D55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.Island.heroSong).font(AS.font(13, .semibold)).foregroundStyle(.white)
                    Text(L10n.Island.heroArtist).font(AS.font(12)).foregroundStyle(AS.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .bottom, spacing: 2.5) {
                    ForEach([8.0, 16, 11, 14], id: \.self) { height in
                        RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xFF9500)).frame(width: 3, height: height)
                    }
                }
                .frame(height: 16, alignment: .bottom)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0x3A3A3C))
                    Capsule().fill(.white).frame(width: proxy.size.width * 0.38)
                }
            }
            .frame(height: 4)
            HStack(spacing: 30) {
                SVGPath("M12 1L2 8l10 7zM22 1L12 8l10 7z", viewBox: CGSize(width: 24, height: 16)).fill(.white).frame(width: 20, height: 13.3)
                SVGPath("M1 1h3.4v14H1zM7.6 1H11v14H7.6z", viewBox: CGSize(width: 12, height: 16)).fill(.white).frame(width: 11.25, height: 15)
                SVGPath("M2 1l10 7-10 7zM12 1l10 7-10 7z", viewBox: CGSize(width: 24, height: 16)).fill(.white).frame(width: 20, height: 13.3)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 22)
        .frame(width: 340, height: 132, alignment: .top)
        .background(UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26, style: .continuous).fill(.black))
    }
}

// MARK: - Settings

struct IslandSettingsView: View {
    enum Tab: Int, Hashable { case nook, tray, widgets, live, look }

    let feature: IslandFeature
    let settings: SettingsStore
    let workspace: IslandWorkspace
    @State private var tab: Tab = .nook
    @Environment(\.settingsHighlight) private var highlight

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !feature.hasHardwareNotch {
                ASCard(padding: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle").foregroundStyle(AS.textSecondary)
                        Text(L10n.Island.noNotchHere).font(AS.footnote).foregroundStyle(AS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            ASSegmented(feature.displayName, selection: $tab, options: [
                (Tab.nook, L10n.Island.tabNook),
                (Tab.tray, L10n.Island.traySection),
                (Tab.widgets, L10n.Island.widgetsSection),
                (Tab.live, L10n.Island.liveActivities),
                (Tab.look, L10n.Island.tabLookBehavior),
            ], size: .wide)
            switch tab {
            case .nook: nook
            case .tray: tray
            case .widgets: widgets
            case .live: live
            case .look: look
            }
        }
        .onChange(of: highlight, initial: true) { _, anchor in
            if let target = Self.tab(for: anchor) { tab = target }
        }
    }

    /// The tab that holds a search anchor.
    private static func tab(for anchor: String?) -> Tab? {
        switch anchor {
        case IslandFeature.Anchor.music: .nook
        case IslandFeature.Anchor.tray: .tray
        case IslandFeature.Anchor.widgets: .widgets
        case IslandFeature.Anchor.volume: .live
        case IslandFeature.Anchor.look, IslandFeature.Anchor.hover: .look
        default: nil
        }
    }

    // MARK: Tabs

    private var nook: some View {
        ASSection {
            ASToggleRow(L10n.Island.nowPlaying, subtitle: L10n.Island.nowPlayingHelp, isOn: binding(IslandFeature.musicKey))
                .settingsAnchor(IslandFeature.Anchor.music)
            ASToggleRow(L10n.Island.showCalendarSetting, subtitle: L10n.Island.calendarHelp, isOn: binding(IslandFeature.calendarKey))
            ASToggleRow(L10n.Island.mirrorSetting, subtitle: L10n.Island.mirrorHelp, isOn: binding(IslandFeature.mirrorKey))
            ASToggleRow(L10n.Island.homeSetting, subtitle: L10n.Island.homeHelp, isOn: binding(IslandFeature.homeKey))
            ASToggleRow(L10n.Island.focusPageSetting, subtitle: L10n.Island.focusPageHelp, isOn: binding(IslandFeature.focusPageKey))
        }
    }

    private var tray: some View {
        ASSection {
            ASToggleRow(L10n.Island.traySetting, subtitle: L10n.Island.trayHelp, isOn: binding(IslandFeature.trayKey))
            ASToggleRow(L10n.Island.dragOpensTray, isOn: binding(IslandFeature.dragOpensKey))
            ASToggleRow(L10n.Island.removeAfterDrag, isOn: binding(IslandFeature.removeAfterDragKey))
            SpacesToggle()
        }
        .settingsAnchor(IslandFeature.Anchor.tray)
    }

    private var widgets: some View {
        ASSection {
            ASToggleRow(L10n.Island.widgetsSetting, isOn: binding(IslandFeature.widgetsKey))
            WidgetLayoutEditor(workspace: workspace)
            ASRow(L10n.Island.focusLengthTitle) {
                MinuteStepper(
                    value: Binding(get: { workspace.minutes(for: .focus) }, set: { workspace.setMinutes($0, for: .focus) }),
                    range: 1 ... 90, moreLabel: L10n.Island.moreFocus, lessLabel: L10n.Island.lessFocus
                )
            }
            ASRow(L10n.Island.breakLengthTitle) {
                MinuteStepper(
                    value: Binding(get: { workspace.minutes(for: .rest) }, set: { workspace.setMinutes($0, for: .rest) }),
                    range: 1 ... 30, moreLabel: L10n.Island.moreBreak, lessLabel: L10n.Island.lessBreak
                )
            }
            ASToggleRow(L10n.Island.timerSound, isOn: Binding(get: { workspace.soundOn }, set: { workspace.soundOn = $0 }))
        }
        .settingsAnchor(IslandFeature.Anchor.widgets)
    }

    private var live: some View {
        ASSection {
            ASToggleRow(L10n.Island.meetingCountdown, subtitle: L10n.Island.meetingHelp, isOn: binding(IslandFeature.meetingKey))
            ASToggleRow(L10n.Island.batteryNotices, isOn: binding(IslandFeature.batteryKey))
            ASToggleRow(L10n.Island.bluetoothNotices, subtitle: L10n.Island.bluetoothHelpAllSet, isOn: binding(IslandFeature.bluetoothKey))
            ASToggleRow(L10n.Island.volumeChanges, subtitle: L10n.Island.volumeHelp, isOn: binding(IslandFeature.volumeKey))
            ASToggleRow(L10n.Island.downloadsSetting, subtitle: L10n.Island.downloadsHelpAllSet, isOn: binding(IslandFeature.downloadsKey))
        }
        .settingsAnchor(IslandFeature.Anchor.volume)
    }

    private var look: some View {
        let hover = settings.value(IslandFeature.hoverKey)
        return ASSection {
            ASRow(L10n.Island.style) {
                ASSegmented(L10n.Island.style, selection: stringBinding(IslandFeature.lookKey), options: [
                    (IslandServices.Look.black.rawValue, L10n.Island.lookBlack),
                    (IslandServices.Look.glass.rawValue, L10n.Island.lookGlass),
                ])
            }
            .settingsAnchor(IslandFeature.Anchor.look)
            ASRow(L10n.Island.noNotchStyle) {
                ASPopUp(L10n.Island.noNotchStyle, selection: stringBinding(IslandFeature.noNotchStyleKey), options: [
                    (IslandServices.NoNotchStyle.notch.rawValue, L10n.Island.noNotchShape),
                    (IslandServices.NoNotchStyle.handle.rawValue, L10n.Island.noNotchHandle),
                ])
            }
            ASToggleRow(L10n.Island.allDisplays, subtitle: L10n.Island.allDisplaysHelp, isOn: binding(IslandFeature.allDisplaysKey))
            ASToggleRow(L10n.Island.virtualNotch, isOn: binding(IslandFeature.virtualKey))
            ASToggleRow(L10n.Island.openOnHover, subtitle: L10n.Island.openOnHoverHelpShort, isOn: binding(IslandFeature.hoverKey))
                .settingsAnchor(IslandFeature.Anchor.hover)
            ASRow(L10n.Island.hoverDelay) {
                ASPopUp(L10n.Island.hoverDelay, selection: intBinding(IslandFeature.hoverDelayKey), options: [
                    (120, L10n.Island.delayShort),
                    (220, L10n.Island.delayNormal),
                    (450, L10n.Island.delayLong),
                ])
                .disabled(!hover)
                .opacity(hover ? 1 : 0.4)
            }
            ASToggleRow(L10n.Island.musicSwipes, subtitle: L10n.Island.musicSwipesHelp, isOn: binding(IslandFeature.swipesKey))
        }
    }

    // MARK: Bindings

    private func binding(_ key: SettingKey<Bool>) -> Binding<Bool> {
        Binding(get: { settings.value(key) }, set: { settings.set($0, for: key); feature.applySettings() })
    }

    private func stringBinding(_ key: SettingKey<String>) -> Binding<String> {
        Binding(get: { settings.value(key) }, set: { settings.set($0, for: key); feature.applySettings() })
    }

    private func intBinding(_ key: SettingKey<Int>) -> Binding<Int> {
        Binding(get: { settings.value(key) }, set: { settings.set($0, for: key); feature.applySettings() })
    }
}

// MARK: - Widgets grid

/// Every widget in a 3-column grid: shown ones first in their order (drag to
/// reorder), then hidden ones. The checkbox shows or hides a widget.
private struct WidgetLayoutEditor: View {
    let workspace: IslandWorkspace

    var body: some View {
        let shown = workspace.layout
        let hidden = IslandWidget.allCases.filter { !shown.contains($0) }
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(shown + hidden, id: \.self) { widget in
                    cell(widget, on: shown.contains(widget))
                }
            }
            HStack(spacing: 12) {
                Text(L10n.Island.widgetsDragHelp).font(AS.footnote).foregroundStyle(AS.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(L10n.Island.resetWidgets) { workspace.resetLayout() }
                    .buttonStyle(ASButtonStyle(.secondary, height: 22, fontSize: 12))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func cell(_ widget: IslandWidget, on: Bool) -> some View {
        HStack(spacing: 8) {
            LineIcon("M3 5.5h10M3 8h10M3 10.5h10", size: 12, lineWidth: 1.6, color: Color(hex: 0x8E8E93))
                .opacity(on ? 1 : 0.4)
            WidgetCheckbox(title: widget.title, isOn: on) { workspace.toggleWidget(widget) }
            LineIcon(Self.glyph(widget), size: 14, color: AS.icon)
            Text(widget.title).font(AS.body).foregroundStyle(AS.text).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AS.cardFill))
        .contentShape(Rectangle())
        .draggable(Self.dragPrefix + widget.rawValue) {
            Text(widget.title).font(AS.body).padding(.horizontal, 10).frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AS.panel))
        }
        .dropDestination(for: String.self) { items, _ in
            guard on, let dragged = items.first.flatMap(Self.widget(from:)), dragged != widget else { return false }
            var layout = workspace.layout
            guard let from = layout.firstIndex(of: dragged), let to = layout.firstIndex(of: widget) else { return false }
            layout.remove(at: from)
            layout.insert(dragged, at: to)
            workspace.layout = layout
            return true
        }
        .accessibilityAction(named: L10n.Island.moveLeft) { if on { workspace.move(widget, by: -1) } }
        .accessibilityAction(named: L10n.Island.moveRight) { if on { workspace.move(widget, by: 1) } }
    }

    private static let dragPrefix = "allset.island.widget:" // l10n-ignore

    private static func widget(from text: String) -> IslandWidget? {
        guard text.hasPrefix(dragPrefix) else { return nil }
        return IslandWidget(rawValue: String(text.dropFirst(dragPrefix.count)))
    }

    /// The design's line glyph for each widget.
    static func glyph(_ widget: IslandWidget) -> String {
        switch widget {
        case .timer: "M8 3a5 5 0 1 0 .01 0M8 5.5V8l1.8 1.2"
        case .todos: "M4 4.5h.01M4 8h.01M4 11.5h.01M6.5 4.5h6M6.5 8h6M6.5 11.5h6"
        case .notes: "M3 3.5h10v9H3zM5.5 6.5h5M5.5 9.5h3"
        case .quickActions: "M3 5.5h10M3 10.5h10M6 3.8v3.4M10 8.8v3.4"
        case .shortcuts: "M8 2.5l5.5 3L8 8.5l-5.5-3zM2.5 9l5.5 3 5.5-3"
        case .stats: "M4 12V9M8 12V5M12 12V7"
        }
    }
}

/// The design's 16 pt blue checkbox.
private struct WidgetCheckbox: View {
    let title: String
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(isOn ? AS.blue : Color.clear)
                RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(isOn ? AS.blue : Color.white.opacity(0.3), lineWidth: 1)
                if isOn { LineIcon("M3.5 8.5l3 3 6-7", size: 10, lineWidth: 2.4, color: .white) }
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(title, isOn: Binding(get: { isOn }, set: { _ in toggle() })) }
    }
}

/// "25 min" with small up/down arrows.
private struct MinuteStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let moreLabel: String
    let lessLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Text(L10n.Island.minutesValue(value)).font(AS.body).monospacedDigit().foregroundStyle(AS.icon)
            VStack(spacing: 0) {
                arrow("M2 6.5l3-3 3 3", label: moreLabel, enabled: value < range.upperBound) { value = min(value + 1, range.upperBound) }
                arrow("M2 3.5l3 3 3-3", label: lessLabel, enabled: value > range.lowerBound) { value = max(value - 1, range.lowerBound) }
            }
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(AS.controlFill))
        }
        .accessibilityElement(children: .contain)
    }

    private func arrow(_ data: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LineIcon(data, size: 9, lineWidth: 1.6, viewBox: 10, color: AS.icon)
                .frame(width: 20, height: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }
}

/// Turns off macOS's Spaces bar for drags to the top edge, which otherwise
/// covers the notch while you drag files to the Tray.
private struct SpacesToggle: View {
    @State private var showsSpaces = DockSpaces.dragToTopShowsSpaces

    var body: some View {
        ASToggleRow(L10n.Island.hideSpacesOnDrag, subtitle: L10n.Island.hideSpacesHelpShort, isOn: Binding(get: { !showsSpaces }, set: { off in
            DockSpaces.setDragToTopShowsSpaces(!off)
            showsSpaces = !off
        }))
        .onAppear { showsSpaces = DockSpaces.dragToTopShowsSpaces }
    }
}
