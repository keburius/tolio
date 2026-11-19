import CoreGraphics
import Foundation

// Plain, testable pieces of the island: widget layout, timers, gestures,
// downloads and the meeting countdown.

/// A widget on the island's Widgets page.
public enum IslandWidget: String, CaseIterable, Codable, Sendable {
    case timer, todos, notes, quickActions, shortcuts, stats

    /// The layout a fresh install starts with.
    public static let defaultLayout: [IslandWidget] = [.timer, .todos, .notes, .quickActions]

    /// How wide the widget is, in columns of the page (4 per row).
    public var columns: Int {
        switch self {
        case .todos, .notes, .shortcuts: 2
        default: 1
        }
    }

    /// Cleans a stored layout: drops unknown names and duplicates.
    public static func layout(from names: [String]) -> [IslandWidget] {
        var seen = Set<IslandWidget>()
        return names.compactMap(IslandWidget.init(rawValue:)).filter { seen.insert($0).inserted }
    }

    /// Splits a layout into pages that fit `columns` columns each.
    public static func pages(_ layout: [IslandWidget], columns: Int = 4) -> [[IslandWidget]] {
        var pages: [[IslandWidget]] = []
        var current: [IslandWidget] = []
        var used = 0
        for widget in layout {
            let width = min(widget.columns, columns)
            if used + width > columns, !current.isEmpty {
                pages.append(current)
                current = []
                used = 0
            }
            current.append(widget)
            used += width
        }
        if !current.isEmpty { pages.append(current) }
        return pages
    }

    /// Moves `widget` one place left (`-1`) or right (`+1`).
    public static func move(_ widget: IslandWidget, by step: Int, in layout: [IslandWidget]) -> [IslandWidget] {
        guard let index = layout.firstIndex(of: widget) else { return layout }
        let target = min(max(index + step, 0), layout.count - 1)
        var list = layout
        list.remove(at: index)
        list.insert(widget, at: target)
        return list
    }
}

/// One countdown on the Timer widget. Several can run at once.
public struct IslandTimer: Identifiable, Equatable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable { case plain, focus, rest }

    public var id: UUID
    public var kind: Kind
    public var duration: TimeInterval
    /// Set while running.
    public var endsAt: Date?
    /// Time left while paused.
    public var remaining: TimeInterval
    /// Focus rounds finished in this Pomodoro run.
    public var round: Int

    public init(id: UUID = UUID(), kind: Kind = .plain, duration: TimeInterval, round: Int = 0) {
        self.id = id
        self.kind = kind
        self.duration = duration
        remaining = duration
        self.round = round
    }

    public var isRunning: Bool { endsAt != nil }

    public func timeLeft(at now: Date) -> TimeInterval {
        endsAt.map { max($0.timeIntervalSince(now), 0) } ?? remaining
    }

    public func progress(at now: Date) -> Double {
        duration > 0 ? 1 - timeLeft(at: now) / duration : 1
    }

    public mutating func start(at now: Date) {
        guard endsAt == nil, remaining > 0 else { return }
        endsAt = now.addingTimeInterval(remaining)
    }

    public mutating func pause(at now: Date) {
        guard let endsAt else { return }
        remaining = max(endsAt.timeIntervalSince(now), 0)
        self.endsAt = nil
    }

    public func isFinished(at now: Date) -> Bool { endsAt.map { $0 <= now } ?? false }

    /// After a Pomodoro phase ends: focus → rest (long rest every 4th) → focus.
    public func nextPomodoro(focus: TimeInterval = 25 * 60, rest: TimeInterval = 5 * 60, longRest: TimeInterval = 15 * 60) -> IslandTimer? {
        switch kind {
        case .plain: return nil
        case .focus:
            let done = round + 1
            return IslandTimer(id: id, kind: .rest, duration: done % 4 == 0 ? longRest : rest, round: done)
        case .rest: return IslandTimer(id: id, kind: .focus, duration: focus, round: round)
        }
    }

    /// "4:59" or "1:04:59".
    public static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// A quick to-do on the To-dos widget.
public struct IslandTodo: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var title: String
    public var done: Bool

    public init(id: UUID = UUID(), title: String, done: Bool = false) {
        self.id = id
        self.title = title
        self.done = done
    }

    /// Open ones first (newest first), then done ones.
    public static func sorted(_ list: [IslandTodo]) -> [IslandTodo] {
        list.filter { !$0.done } + list.filter(\.done)
    }
}

/// Turns trackpad scrolls on the island into gestures.
public struct SwipeReader: Sendable {
    public enum Gesture: Equatable, Sendable { case left, right, down, up }

    /// How far (in points of scrolling) a swipe must travel.
    public var threshold: CGFloat = 36
    private var x: CGFloat = 0
    private var y: CGFloat = 0
    private var fired = false

    public init(threshold: CGFloat = 36) { self.threshold = threshold }

    public mutating func begin() { x = 0; y = 0; fired = false }

    /// Adds one scroll event's deltas (natural scrolling: content follows the
    /// fingers, so fingers moving down give a positive `dy`). Returns a gesture
    /// once per swipe.
    public mutating func add(dx: CGFloat, dy: CGFloat) -> Gesture? {
        guard !fired else { return nil }
        x += dx
        y += dy
        if abs(x) > threshold, abs(x) > abs(y) * 1.4 {
            fired = true
            // Fingers moving left show what's to the right.
            return x < 0 ? .left : .right
        }
        if abs(y) > threshold, abs(y) > abs(x) * 1.4 {
            fired = true
            return y > 0 ? .down : .up
        }
        return nil
    }
}

/// Files a browser is still writing to Downloads.
public enum DownloadFiles {
    static let partialExtensions: Set<String> = ["crdownload", "download", "part", "partial", "opdownload", "tmp"]

    public static func isPartial(_ name: String) -> Bool {
        guard !name.hasPrefix(".") else { return false }
        return partialExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    /// "Report.pdf.crdownload" → "Report.pdf"; Safari's "Report.pdf.download" (a folder) → "Report.pdf".
    public static func finalName(_ name: String) -> String {
        isPartial(name) ? (name as NSString).deletingPathExtension : name
    }
}

/// What the island shows about the next meeting.
public enum MeetingCountdown {
    /// The next timed (not all-day) event starting within `window`, or one
    /// that started less than 5 minutes ago.
    public static func next<E>(_ events: [E], now: Date, window: TimeInterval = 10 * 60,
                               start: (E) -> Date, allDay: (E) -> Bool) -> E? {
        events.filter { !allDay($0) }
            .filter { start($0).timeIntervalSince(now) <= window && now.timeIntervalSince(start($0)) < 5 * 60 }
            .min { start($0) < start($1) }
    }
}
