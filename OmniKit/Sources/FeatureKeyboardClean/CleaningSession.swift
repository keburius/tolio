import CoreGraphics
import Foundation
import OmniPlatform

/// One keyboard-cleaning session with a hard end time (the watchdog).
public struct CleaningSession: Equatable, Sendable {
    public let start: Date
    public let duration: TimeInterval

    /// Longest allowed session: the keyboard always comes back on its own.
    public static let maximumDuration: TimeInterval = 10 * 60
    public static let durationChoices: [TimeInterval] = [30, 60, 120, 300, 600]

    public init(start: Date, duration: TimeInterval) {
        self.start = start
        self.duration = min(max(duration, 5), Self.maximumDuration)
    }

    public var end: Date { start.addingTimeInterval(duration) }

    public func remaining(at now: Date) -> TimeInterval { max(0, end.timeIntervalSince(now)) }

    public func isExpired(at now: Date) -> Bool { remaining(at: now) == 0 }

    /// "1:05"
    public func remainingText(at now: Date) -> String {
        let seconds = Int(remaining(at: now).rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// Every keyboard event type: keys, modifiers, and media/brightness keys.
    public static let blockedEvents: CGEventMask =
        EventTap.mask(.keyDown, .keyUp, .flagsChanged) | EventTap.systemDefinedMask
}

/// Why a session ended.
public enum CleaningEndReason: Equatable, Sendable {
    case unlockedByUser
    case timeLimit
    /// macOS disabled the event tap; the keyboard is already working again.
    case tapDisabled
    case featureDisabled
}
