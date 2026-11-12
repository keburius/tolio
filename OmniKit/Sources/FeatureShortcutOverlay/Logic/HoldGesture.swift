import Foundation

/// Recognizes "tap the modifier, then press and hold it" (default ⌘ ⌘-hold).
///
/// Pure: the caller feeds modifier transitions with timestamps (seconds) and
/// executes the returned effects. Any other key, modifier, or click resets
/// the gesture, so typing ⌘C ⌘V never triggers it.
public struct HoldGesture: Equatable, Sendable {
    public struct Timing: Equatable, Sendable {
        /// Longest first press that still counts as a tap.
        public var tapMax: TimeInterval = 0.30
        /// Longest gap between the tap and the second press.
        public var gapMax: TimeInterval = 0.30
        /// How long the second press must be held before the overlay shows.
        public var hold: TimeInterval = 0.25
        public init() {}
    }

    public enum Input: Equatable, Sendable {
        /// The trigger modifier went down with no other modifier held.
        case down(TimeInterval)
        /// The trigger modifier was released (no modifier left held).
        case up(TimeInterval)
        /// Any key, click, or other modifier.
        case other
        /// A check scheduled through `.checkAfter`.
        case tick(TimeInterval)
    }

    public enum Effect: Equatable, Sendable {
        /// Call back with `.tick` after this many seconds.
        case checkAfter(TimeInterval)
        /// The gesture is likely; start reading menus now.
        case prepare
        case show
        case hide
    }

    public enum State: Equatable, Sendable {
        case idle
        case firstDown(at: TimeInterval)
        case firstUp(at: TimeInterval)
        case secondDown(at: TimeInterval)
        case showing
    }

    public private(set) var state: State = .idle
    public var timing: Timing

    public init(timing: Timing = Timing()) {
        self.timing = timing
    }

    public var isShowing: Bool { state == .showing }

    public mutating func handle(_ input: Input) -> [Effect] {
        switch (state, input) {
        case (.showing, .up), (.showing, .other):
            state = .idle
            return [.hide]
        case (.showing, _):
            return []

        case let (.idle, .down(t)), let (.firstDown, .down(t)), let (.secondDown, .down(t)):
            state = .firstDown(at: t)
            return []
        case let (.firstDown(start), .up(t)):
            state = t - start <= timing.tapMax ? .firstUp(at: t) : .idle
            return []
        case let (.firstUp(released), .down(t)):
            if t - released <= timing.gapMax {
                state = .secondDown(at: t)
                return [.prepare, .checkAfter(timing.hold)]
            }
            state = .firstDown(at: t)
            return []
        case let (.secondDown(start), .tick(t)):
            // A small tolerance: timers may fire a hair early.
            guard t - start >= timing.hold - 0.01 else { return [] }
            state = .showing
            return [.show]

        case (_, .other), (.secondDown, .up), (.idle, .up), (.firstUp, .up):
            state = .idle
            return []
        case (_, .tick):
            return []
        }
    }

    /// Hides from outside (e.g. after a menu item was chosen).
    public mutating func reset() {
        state = .idle
    }
}
