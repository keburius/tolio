import Foundation

/// A manual keep-awake session. Not persisted: a restart starts with `.off`.
public enum KeepAwakeSession: Equatable, Sendable {
    case off
    case indefinite
    case until(Date)
}

/// Decides whether the Mac should be kept awake. Pure.
public enum KeepAwakePolicy {
    /// The session if it hasn't expired, else `.off`.
    public static func effective(_ session: KeepAwakeSession, now: Date) -> KeepAwakeSession {
        if case let .until(end) = session, end <= now { return .off }
        return session
    }

    /// Hold while a manual session runs or any rule app is running.
    public static func shouldHold(session: KeepAwakeSession, now: Date, ruleApps: Set<String>, running: Set<String>) -> Bool {
        effective(session, now: now) != .off || !ruleApps.isDisjoint(with: running)
    }

    /// Why the Mac is being kept awake, or nil if it isn't.
    public static func describe(
        session: KeepAwakeSession, now: Date, activeRuleApps: [String], timeStyle: Date.FormatStyle = .dateTime.hour().minute()
    ) -> String? {
        var reasons: [String] = []
        switch effective(session, now: now) {
        case .off: break
        case .indefinite: reasons.append("until you turn it off")
        case let .until(end): reasons.append("until \(end.formatted(timeStyle))")
        }
        if !activeRuleApps.isEmpty {
            reasons.append("while \(activeRuleApps.sorted().joined(separator: ", ")) \(activeRuleApps.count == 1 ? "is" : "are") running")
        }
        return reasons.isEmpty ? nil : "Keeping awake " + reasons.joined(separator: " and ")
    }

    /// Preset durations offered in the palette and Settings.
    public static let presets: [(title: String, minutes: Int)] = [
        ("15 Minutes", 15), ("30 Minutes", 30), ("1 Hour", 60), ("2 Hours", 120), ("5 Hours", 300),
    ]
}
