import AppKit
import AVKit
import OmniCore
import OmniPlatform
import SwiftUI

/// The island that grows out of the notch: closed with wings, a notice or
/// the volume, or open on a page (Music, Calendar, Focus, Tray…) with
/// tabs floating under it.
struct IslandView: View {
    let model: IslandModel
    @Environment(\.islandActions) private var actions

    /// Opening and growing overshoot a little, like the iPhone's island.
    private var spring: Animation? { OmniStyle.motion(.spring(response: 0.46, dampingFraction: 0.7)) }

    private var open: Bool { model.mode == .open }
    private var topRadius: CGFloat { model.isHandle && model.mode == .closed && !model.hasWings ? 0 : (open ? 14 : 7) }
    private var bottomRadius: CGFloat {
        if model.isHandle && model.mode == .closed && !model.hasWings { return 3.5 }
        return open ? 30 : (model.mode == .closed ? 11 : 16)
    }

    /// Pointing at the closed island makes it swell with a little bounce.
    private var hoverSpring: Animation? { OmniStyle.motion(.spring(response: 0.34, dampingFraction: 0.5)) }

    @State private var overIsland = false
    @State private var overTabs = false

    var body: some View {
        VStack(spacing: IslandModel.tabBarGap) {
            island
            if open && model.pages.count > 1 {
                IslandTabBar(model: model)
                    .onHover { overTabs = $0; reportHover() }
                    .transition(AnyTransition.offset(y: -14).combined(with: .opacity).combined(with: .scale(scale: 0.86, anchor: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .animation(spring, value: model.mode)
        .animation(spring, value: model.hasWings)
        .animation(model.mode == .closed ? hoverSpring : spring, value: model.hovering)
        .animation(spring, value: model.page)
        .animation(spring, value: model.showsMusicWings)
        .animation(spring, value: model.activity?.id)
        .animation(OmniStyle.motion(.spring(response: 0.25, dampingFraction: 0.5)), value: model.skipNudge)
    }

    /// The island and the tab bar under it count as one place to point at.
    private func reportHover() { actions.hover(overIsland || overTabs) }

    private var island: some View {
        let size = model.size
        let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
        return ZStack(alignment: .top) {
            IslandBackground(shape: shape, glass: model.options.look == .glass && (open || !model.geometry.hasHardwareNotch), open: open)
                .frame(width: size.width, height: size.height)
                .shadow(color: .black.opacity(open ? 0.45 : 0), radius: 20, y: 10)
            content
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipShape(shape)
            if model.dropTargeted && model.page != .tray {
                shape.strokeBorderless(color: .white.opacity(0.5)).frame(width: size.width, height: size.height)
            }
        }
        .offset(x: CGFloat(model.skipNudge) * -6)
        // Only the island reacts; the rest of the window lets clicks through.
        .contentShape(NotchShape(topRadius: 0, bottomRadius: bottomRadius))
        .onHover { overIsland = $0; reportHover() }
        .onTapGesture { actions.click() }
        .contextMenu { IslandMenu(model: model) }
    }

    @ViewBuilder private var content: some View {
        let notch = model.notchSize
        VStack(spacing: 0) {
            // The band beside the notch: the wings (the open island has its own top band).
            if !open {
                HStack(spacing: 0) {
                    wing(leading: true).frame(maxWidth: .infinity)
                    Spacer(minLength: model.isHandle ? 110 : notch.width)
                    wing(leading: false).frame(maxWidth: .infinity)
                }
                .frame(height: model.isHandle ? model.bandHeight : notch.height)
                .opacity(model.hasWings ? 1 : 0)
            }

            switch model.mode {
            case .notice:
                if let activity = model.activity {
                    Text(activity.title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                        .padding(.horizontal, 16).frame(maxHeight: .infinity)
                        .transition(AnyTransition.opacity.combined(with: .offset(y: -6)).combined(with: .softBlur))
                }
            case .volume:
                VolumeBar(volume: model.services.volume, muted: model.services.muted).padding(.horizontal, 22).frame(maxHeight: .infinity)
                    .transition(.opacity)
            case .open:
                OpenIsland(model: model)
                    .transition(AnyTransition.opacity.combined(with: .scale(scale: 0.88, anchor: .top)).combined(with: .softBlur))
            case .closed:
                EmptyView()
            }
        }
    }

    // MARK: Wings

    @ViewBuilder private func wing(leading: Bool) -> some View {
        Group {
            if model.mode == .volume {
                if leading {
                    Image(systemName: Self.speakerSymbol(model.services.volume, muted: model.services.muted)).font(.system(size: 13, weight: .semibold))
                } else {
                    Text(model.services.muted ? L10n.Island.muted : "\(Int((model.services.volume * 100).rounded()))")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .contentTransition(.numericText())
                }
            } else if let activity = model.activity, !(model.showsMusicWings && activity.priority < .normal) {
                ActivityContent(content: leading ? activity.leading : activity.trailing, tint: Self.color(activity.tint))
            } else if model.showsMusicWings {
                if leading {
                    Artwork(image: model.nowPlaying.artwork, size: 18, radius: 5)
                        .overlay(alignment: .bottomTrailing) { PlayerBadge(player: model.nowPlaying.player, size: 9).offset(x: 3, y: 3) }
                        .scaleEffect(model.nowPlaying.isPlaying ? 1 : 0.86)
                        .id(model.nowPlaying.track?.title)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else if model.nowPlaying.isPlaying {
                    Equalizer(playing: true, tint: model.nowPlaying.accent, height: 14).transition(.scale.combined(with: .opacity))
                } else {
                    // Paused: a play button that resumes without opening the island.
                    Button(action: model.nowPlaying.playPause) {
                        Image(systemName: "play.fill").font(.system(size: 11, weight: .bold))
                            .frame(width: 22, height: 22).contentShape(Rectangle())
                    }
                    .buttonStyle(IslandPress())
                    .help(L10n.Island.playPause)
                    .accessibilityLabel(L10n.Island.playPause)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
        .padding(leading ? .leading : .trailing, 9)
        // Wings slide out from behind the notch.
        .transition(.offset(x: leading ? 26 : -26).combined(with: .opacity).combined(with: .scale(scale: 0.5)))
    }

    // MARK: Helpers

    static func color(_ name: String) -> Color {
        switch name {
        case "red": .red
        case "green": .green
        case "orange": .orange
        case "blue": Color(red: 0.35, green: 0.65, blue: 1)
        case "yellow": .yellow
        default: .white
        }
    }

    static func speakerSymbol(_ volume: Double, muted: Bool) -> String {
        if muted || volume < 0.01 { return "speaker.slash.fill" }
        return volume < 0.34 ? "speaker.wave.1.fill" : (volume < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill")
    }
}

/// Black like the camera housing, or glass that lets the wallpaper through.
private struct IslandBackground: View {
    let shape: NotchShape
    let glass: Bool
    let open: Bool

    var body: some View {
        if glass {
            ZStack {
                if #available(macOS 26.0, *) {
                    Color.clear.glassEffect(.regular.tint(.black.opacity(0.25)), in: shape)
                } else {
                    shape.fill(.ultraThinMaterial).overlay(shape.fill(.black.opacity(0.3)))
                }
                // Black at the top where it meets the notch, the wallpaper
                // showing through towards the bottom; a thin light rim.
                shape.fill(LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(open ? 0.8 : 0.45), location: open ? 0.18 : 0.5),
                    .init(color: .black.opacity(open ? 0.22 : 0.3), location: 1),
                ], startPoint: .top, endPoint: .bottom))
                shape.stroke(LinearGradient(colors: [.clear, .white.opacity(0.22)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
        } else {
            shape.fill(Color.black)
        }
    }
}

/// Right-click menu on the island.
private struct IslandMenu: View {
    let model: IslandModel
    @Environment(\.islandActions) private var actions

    var body: some View {
        ForEach(model.pages, id: \.self) { page in
            Button {
                if model.mode == .open { model.show(page) } else { model.page = page }
                if model.mode != .open { actions.click() }
                actions.pageChanged()
            } label: {
                Label(page.title, systemImage: page.symbol)
            }
        }
        Divider()
        if model.pages.contains(.widgets) {
            Menu(L10n.Island.editWidgets) { WidgetMenuItems(workspace: model.services.workspace) }
        }
        Button(L10n.Common.settingsEllipsis, action: model.services.openSettings)
    }
}

/// Add or remove each widget, plus a reset.
struct WidgetMenuItems: View {
    let workspace: IslandWorkspace

    var body: some View {
        ForEach(IslandWidget.allCases, id: \.self) { widget in
            Toggle(isOn: Binding(get: { workspace.layout.contains(widget) }, set: { _ in workspace.toggleWidget(widget) })) {
                Label(widget.title, systemImage: widget.symbol)
            }
        }
        Divider()
        Button(L10n.Island.resetWidgets) { workspace.resetLayout() }
    }
}

extension IslandModel.Page {
    var title: String {
        switch self {
        case .home: L10n.Island.homePage
        case .mirror: L10n.Island.mirror
        case .music: L10n.Island.musicPage
        case .calendar: L10n.Island.calendarPage
        case .focus: L10n.Island.focusPage
        case .tray: L10n.Island.trayPage
        case .widgets: L10n.Island.widgetsPage
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .mirror: "camera.fill"
        case .music: "play.fill"
        case .calendar: "calendar"
        case .focus: "timer"
        case .tray: "tray.fill"
        case .widgets: "square.grid.2x2.fill"
        }
    }
}

// MARK: - Open island

/// The open island: the band beside the notch, then the page.
private struct OpenIsland: View {
    let model: IslandModel

    var body: some View {
        let page = model.pages.contains(model.page) ? model.page : (model.pages.first ?? .music)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: model.notchSize.width + 16)
                if page == .widgets {
                    Menu {
                        WidgetMenuItems(workspace: model.services.workspace)
                    } label: {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold)).frame(width: 26, height: 22)
                    }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                    .opacity(0.6).help(L10n.Island.editWidgets).accessibilityLabel(L10n.Island.editWidgets)
                }
            }
            .padding(.horizontal, 22)
            .frame(height: model.bandHeight)

            Group {
                switch page {
                case .home: HomePage(model: model)
                case .mirror: MirrorPage(camera: model.services.camera)
                case .music: MusicPage(player: model.nowPlaying)
                case .calendar: CalendarPage(services: model.services)
                case .focus: FocusPage(workspace: model.services.workspace)
                case .tray: TrayPage(model: model)
                case .widgets: WidgetsPage(model: model)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 8)
            .padding(.bottom, 18)
            .frame(maxHeight: .infinity, alignment: .top)
            .id(page)
            .transition(.push(from: model.pageForward ? .trailing : .leading).combined(with: .opacity))
        }
    }
}

/// The pill of tabs floating under the open island: an icon per page, the
/// chosen one with its name, then Settings.
private struct IslandTabBar: View {
    let model: IslandModel
    @Environment(\.islandActions) private var actions
    @Namespace private var selection

    var body: some View {
        let page = model.pages.contains(model.page) ? model.page : (model.pages.first ?? .music)
        HStack(spacing: 2) {
            ForEach(model.pages, id: \.self) { tab in
                TabButton(page: tab, selected: tab == page, badge: tab == .tray ? model.services.tray.items.count : 0, namespace: selection) {
                    model.show(tab)
                    actions.pageChanged()
                }
            }
            Rectangle().fill(.white.opacity(0.14)).frame(width: 1, height: 18).padding(.horizontal, 4)
            BandButton(symbol: "gearshape.fill", label: L10n.Common.settingsEllipsis, action: model.services.openSettings)
        }
        .padding(5)
        .frame(height: IslandModel.tabBarHeight)
        .background { TabBarBackground(glass: model.options.look == .glass) }
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        .animation(OmniStyle.motion(.spring(response: 0.36, dampingFraction: 0.78)), value: page)
    }
}

private struct TabBarBackground: View {
    let glass: Bool

    var body: some View {
        if glass {
            ZStack {
                if #available(macOS 26.0, *) {
                    Color.clear.glassEffect(.regular.tint(.black.opacity(0.3)), in: Capsule())
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
                Capsule().fill(.black.opacity(0.45))
                Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
        } else {
            Capsule().fill(.black).overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
        }
    }
}

private struct TabButton: View {
    let page: IslandModel.Page
    let selected: Bool
    let badge: Int
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: page.symbol).font(.system(size: 13, weight: .semibold))
                if selected {
                    Text(page.title).font(.system(size: 13, weight: .semibold)).lineLimit(1).fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.7, anchor: .leading)))
                }
                if badge > 0, !selected {
                    Text(verbatim: String(badge)).font(.system(size: 9, weight: .bold).monospacedDigit())
                        .padding(.horizontal, 4).frame(minWidth: 14, minHeight: 14)
                        .background(Capsule().fill(.white.opacity(0.22)))
                }
            }
            .padding(.horizontal, selected ? 14 : 11)
            .frame(height: 30)
            .background {
                if selected {
                    Capsule().fill(.white.opacity(0.16)).matchedGeometryEffect(id: "tab", in: namespace)
                } else if hover {
                    Capsule().fill(.white.opacity(0.07))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(IslandPress())
        .opacity(selected ? 1 : (hover ? 0.85 : 0.6))
        .onHover { hover = $0 }
        .help(page.title)
        .accessibilityLabel(page.title)
    }
}

struct BandButton: View {
    let symbol: String
    let label: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).frame(width: 30, height: 30)
                .background(Capsule().fill(.white.opacity(active ? 0.18 : 0)))
                .contentShape(Rectangle())
        }
        .buttonStyle(IslandPress())
        .opacity(active ? 1 : 0.6)
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Shared pieces

/// The notch outline: flares out at the top corners into the menu bar, round
/// at the bottom.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let t = min(topRadius, rect.width / 4), b = min(bottomRadius, rect.height / 2, (rect.width - 2 * t) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t, y: rect.minY + t), control: CGPoint(x: rect.minX + t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY - b))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t + b, y: rect.maxY), control: CGPoint(x: rect.minX + t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t - b, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - t, y: rect.maxY - b), control: CGPoint(x: rect.maxX - t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY + t))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - t, y: rect.minY))
        p.closeSubpath()
        return p
    }

    func strokeBorderless(color: Color) -> some View {
        stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
    }
}

/// One side of a live activity.
private struct ActivityContent: View {
    let content: LiveActivity.Content
    let tint: Color

    var body: some View {
        switch content {
        case let .symbol(name):
            Image(systemName: name).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
                .symbolEffect(.pulse, options: .repeating, isActive: name.hasPrefix("record") || name.hasPrefix("arrow.down"))
                .symbolEffect(.bounce, options: .nonRepeating, value: name)
        case let .text(text):
            Text(text).font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(tint).lineLimit(1)
        case let .countdown(date):
            Text(timerInterval: Date()...max(date, Date()), countsDown: true)
                .font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        case let .elapsed(date):
            Text(date, style: .timer)
                .font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        case let .ring(value):
            Ring(value: value, tint: tint, width: 2.5).frame(width: 16, height: 16)
        }
    }
}

struct Ring: View {
    let value: Double
    let tint: Color
    var width: CGFloat = 3

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.22), lineWidth: width)
            Circle().trim(from: 0, to: max(0, min(value, 1))).stroke(tint, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Little bars that bounce while music plays.
struct Equalizer: View {
    let playing: Bool
    var tint: Color = Color(red: 0.98, green: 0.36, blue: 0.42)
    var bars = 4
    var height: CGFloat = 16

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: !playing || OmniStyle.reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<bars, id: \.self) { i in
                    let phase = sin(t * (5 + Double(i) * 1.7) + Double(i) * 1.3)
                    Capsule()
                        .fill(tint)
                        .frame(width: 2.6, height: playing ? height * 0.3 + height * 0.6 * abs(phase) : 4)
                }
            }
            .frame(height: height)
        }
        .accessibilityHidden(true)
    }
}

struct Artwork: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note").font(.system(size: size * 0.45)).foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.white.opacity(0.12))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// The volume level under the wings.
private struct VolumeBar: View {
    let volume: Double
    let muted: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(.white).frame(width: geo.size.width * (muted ? 0 : max(0, min(volume, 1))))
            }
        }
        .frame(height: 5)
        .animation(OmniStyle.motion(.spring(response: 0.25, dampingFraction: 0.8)), value: volume)
    }
}

/// The playing app's icon (Spotify or Music) as a small round badge.
struct PlayerBadge: View {
    let player: NowPlaying.Player?
    let size: CGFloat

    var body: some View {
        if let player, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.rawValue) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable().frame(width: size, height: size)
                .shadow(color: .black.opacity(0.6), radius: 2)
                .accessibilityHidden(true)
        }
    }
}

/// macOS's own audio output picker (AirPlay, headphones, speakers).
struct RoutePicker: NSViewRepresentable {
    /// Clear hides macOS's own icon so a custom one can show beneath.
    var color: NSColor = .white

    func makeNSView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.isRoutePickerButtonBordered = false
        view.setRoutePickerButtonColor(color, for: .normal)
        for state: AVRoutePickerView.ButtonState in [.normalHighlighted, .active, .activeHighlighted] {
            view.setRoutePickerButtonColor(color, for: state)
        }
        return view
    }

    func updateNSView(_ view: AVRoutePickerView, context: Context) {}
}

struct IslandPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !OmniStyle.reduceMotion ? 0.85 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(OmniStyle.motion(.spring(response: 0.22, dampingFraction: 0.45)), value: configuration.isPressed)
    }
}

/// A rounded card on an open page.
struct IslandCard<Content: View>: View {
    var padding: CGFloat = 10
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.06)))
    }
}

/// Small caps title on a card.
struct CardTitle: View {
    let text: String
    var symbol: String?
    var trailing: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 9, weight: .bold)) }
            Text(text.uppercased(with: .current)).font(.system(size: 9.5, weight: .bold)).tracking(0.6)
            Spacer(minLength: 0)
            if let trailing { Text(trailing).font(.system(size: 9.5, weight: .semibold).monospacedDigit()) }
        }
        .foregroundStyle(.white.opacity(0.45))
        .lineLimit(1)
    }
}

private struct BlurAmount: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View { content.blur(radius: radius) }
}

extension AnyTransition {
    /// Comes into focus as it appears.
    static var softBlur: AnyTransition { .modifier(active: BlurAmount(radius: 8), identity: BlurAmount(radius: 0)) }
}
