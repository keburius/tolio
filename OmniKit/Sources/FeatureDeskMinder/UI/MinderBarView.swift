import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// The bar above the Dock, in three states:
/// - idle (after adding, when the bar stays): [+] [①]
/// - compact: [×] [◷ 15 min · 3:13 PM |||]. Pull it sideways for more time:
///   it grows from the middle and trails the pointer on a soft spring, with
///   a tick of sound and haptic per minute. Click it to open the editor.
/// - editor: [×] [◷ 18:30 | Reminder… ↑]
struct MinderBarView: View {
    let sounds: Bool
    let startIdle: Bool
    let pending: Int
    let onAdd: (_ title: String, _ due: Date) -> Void
    let onClose: () -> Void
    let onShowList: () -> Void

    static let compactWidth: CGFloat = 214
    static let editorWidth: CGFloat = 330
    static let maxStretch: CGFloat = 660
    static let height: CGFloat = 46

    private enum Mode { case idle, compact, editing }

    @State private var mode: Mode
    @State private var stretch: CGFloat = 0
    @State private var dragStart: CGFloat?
    @State private var dragSign: CGFloat = 1
    @State private var barMidX: CGFloat = 0
    @State private var pressed = false
    /// 0…1: how much the long edges bend in while you pull.
    @State private var pinch: CGFloat = 0
    @State private var timeText = ""
    @State private var title = ""
    @State private var invalid = false
    @State private var now = Date()
    @FocusState private var focus: Field?

    private enum Field { case time, title }

    init(
        sounds: Bool, startIdle: Bool, pending: Int,
        onAdd: @escaping (_ title: String, _ due: Date) -> Void,
        onClose: @escaping () -> Void, onShowList: @escaping () -> Void
    ) {
        self.sounds = sounds
        self.startIdle = startIdle
        self.pending = pending
        self.onAdd = onAdd
        self.onClose = onClose
        self.onShowList = onShowList
        _mode = State(initialValue: startIdle ? .idle : .compact)
    }

    private var minutes: Int { StretchScale.minutes(forStretch: stretch) }
    private var typedDue: Date? { timeText.isEmpty ? nil : MinderTimeParser.due(from: timeText, now: now) }
    private var due: Date { typedDue ?? now.addingTimeInterval(TimeInterval(minutes * 60)) }
    private var durationLabel: String {
        StretchScale.label(minutes: minutes, minuteFormat: L10n.DeskMinder.minutes, hourFormat: L10n.DeskMinder.hours)
    }
    private var width: CGFloat {
        mode == .editing ? max(Self.editorWidth, Self.compactWidth + stretch) : Self.compactWidth + max(stretch, -40)
    }

    var body: some View {
        ZStack {
            if mode == .idle {
                idle.transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                bar.transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .padding(.top, 40) // room for the time bubble
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { now = $0 }
        .onExitCommand {
            switch mode {
            case .editing: closeEditor()
            case .compact, .idle: onClose()
            }
        }
    }

    // MARK: Idle

    private var idle: some View {
        HStack(spacing: 8) {
            Button {
                Feel.click()
                withAnimation(OmniStyle.motion(.spring(response: 0.4, dampingFraction: 0.72))) { mode = .compact }
            } label: {
                Image(systemName: "plus").font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36).contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .glass(Circle(), interactive: true)
            .help(L10n.DeskMinder.hotkey)
            .accessibilityLabel(L10n.DeskMinder.hotkey)

            if pending > 0 {
                Button(action: onShowList) {
                    Text("\(pending)").font(.system(size: 13, weight: .bold).monospacedDigit())
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2).padding(5))
                        .contentShape(Circle())
                }
                .buttonStyle(PressStyle())
                .glass(Circle(), interactive: true)
                .help(L10n.DeskMinder.upcoming)
                .accessibilityLabel(L10n.DeskMinder.erase(pending))
            }
        }
    }

    // MARK: Bar

    private var bar: some View {
        ZStack {
            if mode == .editing { editor.transition(.opacity) } else { compact.transition(.opacity) }
        }
        .frame(width: width, height: Self.height)
        .glass(StretchPill(pinch: pinch), interactive: false)
        .overlay {
            if invalid { StretchPill(pinch: pinch).stroke(Color.red.opacity(0.8), lineWidth: 1.5) }
        }
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { barMidX = geo.frame(in: .global).midX }
                .onChange(of: geo.frame(in: .global).midX) { _, mid in barMidX = mid }
        })
        .overlay(alignment: .top) { bubble }
        // The × sits just left of the bar, so the bar itself stays centered.
        .overlay(alignment: .leading) { closeButton.offset(x: -(Self.height + 8)) }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                .frame(width: Self.height, height: Self.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .glass(RoundedRectangle(cornerRadius: 15, style: .continuous), interactive: true)
        .help(L10n.DeskMinder.close)
        .accessibilityLabel(L10n.DeskMinder.close)
    }

    // MARK: Compact

    private var compact: some View {
        HStack(spacing: 8) {
            ClockIcon(minutes: minutes)
            Text(durationLabel)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .contentTransition(.numericText(value: Double(minutes)))
            if minutes >= 10 {
                Text("· \(Self.clock(due))")
                    .font(.system(size: 14, weight: .medium).monospacedDigit()).opacity(0.6)
                    .contentTransition(.numericText())
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in Capsule().frame(width: 2.2, height: 14) }
            }
            .opacity(dragStart == nil ? 0.7 : 1)
        }
        .lineLimit(1)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .scaleEffect(pressed && dragStart == nil && !OmniStyle.reduceMotion ? 0.96 : 1)
        .animation(OmniStyle.motion(.spring(response: 0.22, dampingFraction: 0.6)), value: pressed)
        .onHover { inside in if inside { NSCursor.openHand.push() } else { NSCursor.pop() } }
        // One gesture for the whole bar: a click opens the editor, a sideways
        // pull stretches it. Measured on screen (not in the bar, which moves
        // as it grows), so the bar can't fight the pointer.
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged(dragChanged)
                .onEnded(dragEnded)
        )
        .help(L10n.DeskMinder.stretchHelp)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { openEditor() }
        .accessibilityValue(durationLabel)
        .accessibilityAdjustableAction { direction in
            let next = stretch + (direction == .increment ? StretchScale.step : -StretchScale.step)
            setStretch(min(max(next, 0), Self.maxStretch))
        }
    }

    private func dragChanged(_ value: DragGesture.Value) {
        if !pressed { pressed = true }
        let moved = abs(value.translation.width) > 3 || abs(value.translation.height) > 3
        guard moved || dragStart != nil else { return }
        if dragStart == nil {
            dragStart = stretch
            // Grabbed on the left half: pulling left grows it.
            dragSign = value.startLocation.x < barMidX ? -1 : 1
            NSCursor.closedHand.push()
            timeText = ""
            now = Date()
        }
        // Both ends move, so the bar grows by twice the pull; past either
        // end it resists like rubber.
        let target = (dragStart ?? 0) + dragSign * value.translation.width * 2
        let resisted = target < 0 ? target / 5 : (target > Self.maxStretch ? Self.maxStretch + (target - Self.maxStretch) / 5 : target)
        let speed = min(abs(value.velocity.width), 4000)
        // A soft spring: the bar trails the pointer and settles, instead of
        // snapping to every pixel.
        withAnimation(OmniStyle.motion(.spring(response: 0.3, dampingFraction: 0.78))) {
            setStretch(resisted)
            pinch = min(1, 0.3 + speed / 3000)
        }
    }

    private func dragEnded(_ value: DragGesture.Value) {
        pressed = false
        guard dragStart != nil else {
            openEditor()
            return
        }
        NSCursor.pop()
        dragStart = nil
        withAnimation(OmniStyle.motion(.spring(response: 0.45, dampingFraction: 0.55))) {
            stretch = min(max(stretch, 0), Self.maxStretch)
            pinch = 0
        }
    }

    /// Changes the stretch; a tick of sound and haptic when the minutes change.
    private func setStretch(_ value: CGFloat) {
        let before = minutes
        stretch = value
        if minutes != before { Feel.tick(sound: sounds) }
    }

    // MARK: Editor

    private var editor: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                ClockIcon(minutes: minutes)
                TextField(durationLabel, text: $timeText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .frame(width: max(46, CGFloat(max(timeText.count, durationLabel.count)) * 9 + 6))
                    .focused($focus, equals: .time)
                    .onSubmit { focus = .title }
                    .onChange(of: timeText) { invalid = false }
                    .help(L10n.DeskMinder.timeHelp)
            }
            .padding(.horizontal, 10).frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(focus == .time ? 0.16 : 0.07)))
            // The whole box takes the click, not just the line of text.
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture { focus = .time }
            .padding(.leading, 5)

            Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 22).padding(.horizontal, 9)

            TextField(L10n.DeskMinder.titlePlaceholder, text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .focused($focus, equals: .title)
                .onSubmit(submit)
                // Everything from the divider to the ↑ button, full height,
                // puts the cursor in the name.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { focus = .title }
                .onHover { inside in if inside { NSCursor.iBeam.push() } else { NSCursor.pop() } }

            Button(action: submit) {
                Image(systemName: "arrow.up").font(.system(size: 12, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.white.opacity(title.isEmpty ? 0.14 : 0.92)))
                    .foregroundStyle(title.isEmpty ? Color.white.opacity(0.6) : Color.black)
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .help(L10n.DeskMinder.add)
            .accessibilityLabel(L10n.DeskMinder.add)
            .padding(.trailing, 10).padding(.leading, 6)
        }
    }

    private func openEditor() {
        Feel.click()
        now = Date()
        withAnimation(OmniStyle.motion(.spring(response: 0.38, dampingFraction: 0.74))) { mode = .editing }
        focus = .title
    }

    private func closeEditor() {
        withAnimation(OmniStyle.motion(.spring(response: 0.35, dampingFraction: 0.8))) { mode = .compact }
        focus = nil
        invalid = false
    }

    /// The due time floating above the bar while you set it.
    @ViewBuilder private var bubble: some View {
        if dragStart != nil || typedDue != nil {
            Text(Self.clock(due))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .contentTransition(.numericText())
                .padding(.horizontal, 9).padding(.vertical, 4)
                .glass(Capsule(), interactive: false)
                .offset(y: -34)
                .transition(.opacity.combined(with: .offset(y: 6)))
        }
    }

    private func submit() {
        if !timeText.isEmpty, typedDue == nil {
            invalid = true
            focus = .time
            Feel.error()
            HUD.show(L10n.DeskMinder.badTime, symbol: "exclamationmark.triangle")
            return
        }
        Feel.click()
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        onAdd(clean.isEmpty ? L10n.DeskMinder.defaultTitle : clean, due)
        title = ""
        timeText = ""
        focus = nil
        withAnimation(OmniStyle.motion(.spring(response: 0.4, dampingFraction: 0.75))) {
            stretch = 0
            mode = .idle
        }
    }

    static func clock(_ date: Date) -> String {
        date.formatted(date: Calendar.current.isDateInToday(date) ? .omitted : .abbreviated, time: .shortened)
    }
}

/// A small dial whose hand turns with the minutes (one turn per hour).
private struct ClockIcon: View {
    let minutes: Int

    var body: some View {
        ZStack {
            Circle().strokeBorder(lineWidth: 1.6)
            Capsule().frame(width: 1.8, height: 6)
                .offset(y: -2.6)
                .rotationEffect(.degrees(Double(minutes) * 6))
                .animation(OmniStyle.motion(.spring(response: 0.3, dampingFraction: 0.7)), value: minutes)
        }
        .frame(width: 17, height: 17)
        .opacity(0.85)
        .accessibilityHidden(true)
    }
}

/// A pill whose long edges bend gently in toward the middle by `pinch`, so a
/// pull reads as stretching.
struct StretchPill: Shape {
    var pinch: CGFloat

    var animatableData: CGFloat {
        get { pinch }
        set { pinch = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(rect.height / 2, 17)
        // Deeper when the bar is long, never more than a tenth of its height.
        let length = min(1, max(0, (rect.width - 220) / 600))
        let dip = rect.height * 0.1 * max(0, min(pinch, 1)) * (0.4 + 0.6 * length)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + dip * 2))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.midY), radius: r)
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY), radius: r)
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.maxY - dip * 2))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.midY), radius: r)
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + r, y: rect.minY), radius: r)
        p.closeSubpath()
        return p
    }
}

/// Shrinks a little while pressed.
private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !OmniStyle.reduceMotion ? 0.93 : 1)
            .animation(OmniStyle.motion(.spring(response: 0.2, dampingFraction: 0.6)), value: configuration.isPressed)
    }
}

private extension View {
    /// Liquid Glass on macOS 26 and later; frosted material with a light rim
    /// before. `interactive` glass reacts to clicks (buttons only: on the
    /// stretching bar it would wobble against the pull).
    @ViewBuilder func glass(_ shape: some Shape, interactive: Bool) -> some View {
        if #available(macOS 26.0, *) {
            // The system draws the glass outside the window's own pixels, so
            // without this barely-there fill clicks could pass through the
            // glass to the desktop.
            background(shape.fill(Color.black.opacity(0.004)))
                .glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            background(shape.fill(.ultraThinMaterial))
                .overlay(shape.stroke(Color.white.opacity(0.22), lineWidth: 1))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        }
    }
}

/// Sound and trackpad feedback for the bar.
@MainActor
enum Feel {
    private static var lastTick = Date.distantPast
    private static let tickSound: NSSound? = {
        let sound = NSSound(named: "Tink")?.copy() as? NSSound
        sound?.volume = 0.15
        return sound
    }()

    /// One minute step. Sounds are spaced at least 45 ms apart so a fast pull
    /// purrs instead of clattering.
    static func tick(sound: Bool) {
        AppFeel.tap(.alignment)
        guard sound, Date().timeIntervalSince(lastTick) > 0.045, let tickSound else { return }
        lastTick = Date()
        tickSound.stop()
        tickSound.play()
    }

    static func click() {
        AppFeel.tap(.levelChange)
    }

    static func error() {
        AppFeel.tap(.generic)
        NSSound.beep()
    }
}
