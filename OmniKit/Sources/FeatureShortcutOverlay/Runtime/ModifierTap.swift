import CoreGraphics
import Foundation
import OmniCore
import OmniPlatform

/// The modifier whose double-press-and-hold opens the overlay.
public enum OverlayTrigger: String, Codable, CaseIterable, Sendable {
    case command, option, control, off

    var flag: CGEventFlags? {
        switch self {
        case .command: .maskCommand
        case .option: .maskAlternate
        case .control: .maskControl
        case .off: nil
        }
    }

    var label: String {
        switch self {
        case .command: L10n.Cheatsheet.triggerCommand
        case .option: L10n.Cheatsheet.triggerOption
        case .control: L10n.Cheatsheet.triggerControl
        case .off: L10n.Cheatsheet.triggerOff
        }
    }

    var symbol: String {
        switch self {
        case .command: "⌘"
        case .option: "⌥"
        case .control: "⌃"
        case .off: ""
        }
    }
}

/// Converts raw modifier flags into `HoldGesture` inputs. Pure, for tests.
struct ModifierTransitions {
    static let relevant: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift, .maskSecondaryFn]
    private var previous: CGEventFlags = []

    mutating func input(for flags: CGEventFlags, trigger: CGEventFlags, at time: TimeInterval) -> HoldGesture.Input {
        let now = flags.intersection(Self.relevant)
        defer { previous = now }
        if now == trigger && !previous.contains(trigger) && previous.isEmpty { return .down(time) }
        if now.isEmpty && previous == trigger { return .up(time) }
        return .other
    }
}

/// Listen-only tap: it can't block or alter any input. It sees modifier
/// changes, key presses (only to cancel the gesture; never stored or logged),
/// and clicks. A listen-only tap that macOS disables re-enables itself.
@MainActor
final class ModifierTap {
    enum Event {
        case gesture(HoldGesture.Input)
        case mouseDown
    }

    private var tap: EventTap?
    private var transitions = ModifierTransitions()
    private let trigger: () -> OverlayTrigger
    private let onEvent: (Event) -> Void

    init(trigger: @escaping () -> OverlayTrigger, onEvent: @escaping (Event) -> Void) {
        self.trigger = trigger
        self.onEvent = onEvent
    }

    func start() throws {
        let mask = EventTap.mask(.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown)
        let tap = EventTap(mask: mask, mode: .listenOnly) { [weak self] type, event in
            self?.handle(type, event)
            return false
        }
        try tap.start()
        self.tap = tap
    }

    func stop() {
        tap?.stop()
        tap = nil
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        guard let flag = trigger().flag else { return }
        let now = ProcessInfo.processInfo.systemUptime
        switch type {
        case .flagsChanged:
            dispatch(.gesture(transitions.input(for: event.flags, trigger: flag, at: now)))
        case .keyDown:
            dispatch(.gesture(.other))
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            dispatch(.mouseDown)
        default:
            break
        }
    }

    /// The tap callback returns at once; the work runs right after.
    private func dispatch(_ event: Event) {
        Task { @MainActor [weak self] in self?.onEvent(event) }
    }
}
