import Foundation
import OmniCore

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
        case .indefinite: reasons.append(L10n.KeepAwake.reasonUntilOff)
        case let .until(end): reasons.append(L10n.KeepAwake.reasonUntil(end.formatted(timeStyle)))
        }
        if !activeRuleApps.isEmpty {
            let names = activeRuleApps.sorted().joined(separator: ", ")
            reasons.append(activeRuleApps.count == 1 ? L10n.KeepAwake.reasonAppRunning(names) : L10n.KeepAwake.reasonAppsRunning(names))
        }
        guard let first = reasons.first else { return nil }
        let joined = reasons.dropFirst().reduce(first) { L10n.KeepAwake.reasons($0, $1) }
        return L10n.KeepAwake.keepingAwake(joined)
    }

    /// Preset durations offered in Settings and the menu bar icon.
    public static let presetMinutes = [15, 30, 60, 120, 300]

    /// Preset durations with their titles ("15 Minutes", "1 Hour").
    public static var presets: [(title: String, minutes: Int)] {
        presetMinutes.map { (durationTitle(minutes: $0), $0) }
    }

    /// "15 Minutes", "2 Hours".
    public static func durationTitle(minutes: Int) -> String {
        minutes >= 60 && minutes % 60 == 0 ? L10n.KeepAwake.hours(minutes / 60) : L10n.KeepAwake.minutes(minutes)
    }
}
