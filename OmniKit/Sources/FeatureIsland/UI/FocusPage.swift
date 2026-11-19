import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Focus or a break: pick minutes on a ruler (drag or scroll it), start,
/// and the time counts down here and in the wings. When one ends the other
/// follows. Also a sound switch and a stopwatch.
struct FocusPage: View {
    let workspace: IslandWorkspace
    @State private var kind: IslandTimer.Kind = .focus

    static let focusTint = Color(red: 1, green: 0.72, blue: 0.32)
    static let restTint = Color(red: 0.4, green: 0.85, blue: 0.55)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let session = workspace.session
            let shownKind = session.map { $0.kind == .rest ? IslandTimer.Kind.rest : .focus } ?? kind
            let tint = shownKind == .rest ? Self.restTint : Self.focusTint
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    modePill(.focus, L10n.Island.focus, selected: shownKind == .focus, locked: session != nil)
                    modePill(.rest, L10n.Island.rest, selected: shownKind == .rest, locked: session != nil)
                }

                MinuteRuler(
                    value: session.map { $0.timeLeft(at: now) / 60 } ?? Double(workspace.minutes(for: kind)),
                    range: 0...(shownKind == .rest ? 30 : 90),
                    tint: tint,
                    interactive: session == nil,
                    onChange: { workspace.setMinutes($0, for: kind) }
                )
                .frame(height: 62)

                HStack(spacing: 12) {
                    primaryButton(session: session, tint: tint)
                    circleButton(workspace.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                 label: L10n.Island.timerSound, tint: workspace.soundOn ? tint : .white.opacity(0.6)) {
                        workspace.soundOn.toggle()
                    }
                    if let session {
                        circleButton("xmark", label: L10n.Island.stopTimer, tint: .white) { workspace.removeTimer(session.id) }
                    } else {
                        circleButton("stopwatch.fill", label: L10n.Island.stopwatch,
                                     tint: workspace.stopwatchStart != nil ? tint : .white, active: workspace.stopwatchStart != nil) {
                            workspace.toggleStopwatch()
                        }
                    }
                    Spacer(minLength: 0)
                    clock(session: session, now: now, tint: tint)
                }
            }
        }
        .onAppear { if let session = workspace.session { kind = session.kind == .rest ? .rest : .focus } }
        .animation(OmniStyle.motion(.spring(response: 0.3, dampingFraction: 0.8)), value: kind)
    }

    private func modePill(_ value: IslandTimer.Kind, _ title: String, selected: Bool, locked: Bool) -> some View {
        let tint = value == .rest ? Self.restTint : Self.focusTint
        return Button { kind = value } label: {
            Text(title).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? tint : .white.opacity(0.6))
                .padding(.horizontal, 20).frame(height: 30)
                .background(Capsule().fill(selected ? tint.opacity(0.24) : .white.opacity(0.09)))
                .contentShape(Capsule())
        }
        .buttonStyle(IslandPress())
        .disabled(locked)
    }

    @ViewBuilder private func primaryButton(session: IslandTimer?, tint: Color) -> some View {
        let title = session == nil ? L10n.Island.startTimer : (session!.isRunning ? L10n.Island.pause : L10n.Island.resume)
        Button {
            if let session { workspace.toggle(session.id) } else { workspace.startSession(kind) }
        } label: {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                .padding(.horizontal, 22).frame(minWidth: 132).frame(height: 40)
                .background(Capsule().fill(tint.opacity(0.22)))
                .contentShape(Capsule())
                .contentTransition(.opacity)
        }
        .buttonStyle(IslandPress())
    }

    private func circleButton(_ symbol: String, label: String, tint: Color, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 40, height: 40)
                .background(Circle().fill(active ? tint.opacity(0.22) : .white.opacity(0.1)))
                .contentShape(Circle())
        }
        .buttonStyle(IslandPress())
        .help(label)
        .accessibilityLabel(label)
    }

    /// The time left, the stopwatch, or the minutes you've set.
    @ViewBuilder private func clock(session: IslandTimer?, now: Date, tint: Color) -> some View {
        let font = Font.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit()
        if let session, let end = session.endsAt {
            Text(timerInterval: now...max(end, now), countsDown: true).font(font).foregroundStyle(tint)
                .multilineTextAlignment(.trailing).frame(minWidth: 110, alignment: .trailing)
        } else if let session {
            Text(IslandTimer.clock(session.remaining)).font(font).foregroundStyle(tint.opacity(0.6))
        } else if let start = workspace.stopwatchStart {
            Text(start, style: .timer).font(font).foregroundStyle(.white)
                .multilineTextAlignment(.trailing).frame(minWidth: 110, alignment: .trailing)
        } else {
            Text(IslandTimer.clock(TimeInterval(workspace.minutes(for: kind) * 60))).font(font).foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(OmniStyle.motion(.spring(response: 0.25, dampingFraction: 0.85)), value: workspace.minutes(for: kind))
        }
    }
}

/// A ruler of minutes centred on the value: ticks before it in the tint,
/// a white marker with a little arrow at it, numbers every five. Drag it
/// sideways or scroll over it; each minute ticks the trackpad.
private struct MinuteRuler: View {
    let value: Double
    let range: ClosedRange<Int>
    let tint: Color
    let interactive: Bool
    let onChange: (Int) -> Void

    @State private var dragStart: Double?
    @State private var accumulated: CGFloat = 0

    static let spacing: CGFloat = 18

    var body: some View {
        RulerDrawing(value: value, range: range, tint: tint)
            .animation(OmniStyle.motion(.spring(response: 0.28, dampingFraction: 0.85)), value: interactive ? value : 0)
            .contentShape(Rectangle())
            .background(ScrollCatcher { dx, dy in scroll(abs(dx) > abs(dy) ? dx : -dy) })
            .gesture(DragGesture(minimumDistance: 1).onChanged { drag in
                guard interactive else { return }
                let start = dragStart ?? value
                dragStart = start
                set(Int((start - Double(drag.translation.width / Self.spacing)).rounded()))
            }.onEnded { _ in dragStart = nil })
            .help(interactive ? L10n.Island.scrollToSet : "")
            .accessibilityElement()
            .accessibilityLabel(L10n.Island.minutes(Int(value.rounded())))
            .accessibilityAdjustableAction { direction in
                guard interactive else { return }
                set(Int(value.rounded()) + (direction == .increment ? 1 : -1))
            }
    }

    private func scroll(_ delta: CGFloat) {
        guard interactive else { return }
        accumulated += delta
        guard abs(accumulated) >= 10 else { return }
        let step = accumulated > 0 ? -1 : 1
        accumulated = 0
        set(Int(value.rounded()) + step)
    }

    private func set(_ minutes: Int) {
        let clamped = min(max(minutes, max(range.lowerBound, 1)), range.upperBound)
        guard clamped != Int(value.rounded()) else { return }
        onChange(clamped)
        AppFeel.tick()
    }
}

/// The ruler itself; animates smoothly between values.
private struct RulerDrawing: View, Animatable {
    var value: Double
    let range: ClosedRange<Int>
    let tint: Color

    nonisolated var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let mid = size.width / 2
            let spacing = MinuteRuler.spacing
            let selected = Int(value.rounded())
            let tickTop: CGFloat = 26
            for minute in range {
                let x = mid + CGFloat(Double(minute) - value) * spacing
                guard x > -4, x < size.width + 4 else { continue }
                // Fade out towards both ends.
                let fade = min(max(min(x, size.width - x) / 70, 0), 1)
                let major = minute % 5 == 0
                if minute != selected {
                    let height: CGFloat = major ? 26 : 20
                    let rect = CGRect(x: x - 1, y: tickTop + (major ? 0 : 3), width: 2, height: height)
                    let color = Double(minute) < value ? tint : Color.white.opacity(0.28)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color.opacity(fade)))
                }
                if major {
                    let label = Text(verbatim: String(minute))
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundColor(minute == selected ? .white : .white.opacity(0.4 * fade))
                    context.draw(label, at: CGPoint(x: x, y: 9), anchor: .center)
                }
            }
            // The marker and its arrow.
            context.fill(Path(roundedRect: CGRect(x: mid - 1.5, y: tickTop - 3, width: 3, height: 32), cornerRadius: 1.5), with: .color(.white))
            var arrow = Path()
            arrow.move(to: CGPoint(x: mid - 6, y: tickTop + 37))
            arrow.addLine(to: CGPoint(x: mid + 6, y: tickTop + 37))
            arrow.addLine(to: CGPoint(x: mid, y: tickTop + 30))
            arrow.closeSubpath()
            context.fill(arrow, with: .color(tint))
        }
    }
}
