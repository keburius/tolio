import Foundation

/// One reminder. Kept in settings so it survives a restart; `reminderID`
/// links it to its copy in Apple Reminders when syncing is on.
public struct Minder: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var due: Date
    /// `EKReminder.calendarItemIdentifier` of the synced copy.
    public var reminderID: String?

    public init(id: UUID = UUID(), title: String, due: Date, reminderID: String? = nil) {
        self.id = id
        self.title = title
        self.due = due
        self.reminderID = reminderID
    }
}

/// Turns the bar's stretch into minutes: fine steps first, coarser later,
/// so both "5 min" and "2 hours" are easy to hit.
public enum StretchScale {
    /// Points of stretch per step.
    public static let step: Double = 9

    /// Minutes for `extra` points of stretch beyond the bar's resting width.
    public static func minutes(forStretch extra: Double) -> Int {
        let steps = max(0, Int(extra / step))
        // 1…30 by 1, then by 5 up to 120, then by 15 up to 8 hours.
        if steps < 30 { return steps + 1 }
        let afterFine = steps - 29
        if afterFine <= 18 { return 30 + afterFine * 5 }
        return min(120 + (afterFine - 18) * 15, 480)
    }

    /// "1 min", "45 min", "2 h", "1 h 30 min".
    public static func label(minutes: Int, minuteFormat: (Int) -> String, hourFormat: (Int, Int) -> String) -> String {
        minutes < 60 ? minuteFormat(minutes) : hourFormat(minutes / 60, minutes % 60)
    }
}

/// Reads what you type in the time field.
public enum MinderTimeParser {
    /// "18:30", "18:", "18", "6pm", "6:30 pm" → the next time it's that
    /// o'clock; "20m", "20 min", "1h", "1h30", "90" (minutes when > 24) → from now.
    public static func due(from text: String, now: Date, calendar: Calendar = .current) -> Date? {
        let raw = text.lowercased().trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return nil }
        let compact = raw.replacingOccurrences(of: " ", with: "")

        // Durations.
        if let match = compact.wholeMatch(of: /(\d{1,3})(m|min|mins|minute|minutes)/) {
            return add(minutes: Int(match.1) ?? 0, to: now)
        }
        if let match = compact.wholeMatch(of: /(\d{1,2})(h|hr|hrs|hour|hours)(\d{1,2})?(m|min)?/) {
            return add(minutes: (Int(match.1) ?? 0) * 60 + (match.3.flatMap { Int($0) } ?? 0), to: now)
        }

        // Clock times.
        if let match = compact.wholeMatch(of: /(\d{1,2})(?::(\d{0,2}))?(am|pm|a|p)?/) {
            guard var hour = Int(match.1) else { return nil }
            let minute = match.2.flatMap { $0.isEmpty ? 0 : Int($0) } ?? 0
            if let suffix = match.3 {
                guard (1...12).contains(hour) else { return nil }
                let pm = suffix.hasPrefix("p")
                if hour == 12 { hour = pm ? 12 : 0 } else if pm { hour += 12 }
            } else if match.2 == nil, hour > 24 {
                // A bare number above 24 means minutes ("90").
                return add(minutes: hour, to: now)
            }
            guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            var parts = calendar.dateComponents([.year, .month, .day], from: now)
            parts.hour = hour
            parts.minute = minute
            guard let today = calendar.date(from: parts) else { return nil }
            return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
        }
        return nil
    }

    private static func add(minutes: Int, to now: Date) -> Date? {
        guard minutes > 0, minutes <= 60 * 24 * 7 else { return nil }
        return now.addingTimeInterval(TimeInterval(minutes * 60))
    }
}
