import Foundation
import Observation

/// Something worth a glance in the notch while it lasts: a timer, the
/// next meeting, a download, a recording, a reminder coming up. Any feature can
/// post one; Notch Island (if on) shows the most important in its wings.
public struct LiveActivity: Identifiable, Equatable, Sendable {
    public enum Priority: Int, Comparable, Sendable {
        case low, normal, high
        public static func < (a: Priority, b: Priority) -> Bool { a.rawValue < b.rawValue }
    }

    /// What one wing shows.
    public enum Content: Equatable, Sendable {
        case symbol(String)
        case text(String)
        /// Counts down to the date ("4:59").
        case countdown(Date)
        /// Counts up from the date ("0:42").
        case elapsed(Date)
        /// 0…1 as a small ring.
        case ring(Double)
    }

    public var id: String
    public var leading: Content
    public var trailing: Content
    /// Shown when the island opens or while the activity is new.
    public var title: String
    /// A color name the island understands: "red", "green", "orange", "blue", "yellow", "white".
    public var tint: String
    public var priority: Priority
    /// Gone after this, if set (a short notice rather than a lasting state).
    public var expires: Date?

    public init(
        id: String, leading: Content, trailing: Content, title: String,
        tint: String = "white", priority: Priority = .normal, expires: Date? = nil
    ) {
        self.id = id
        self.leading = leading
        self.trailing = trailing
        self.title = title
        self.tint = tint
        self.priority = priority
        self.expires = expires
    }
}

/// The current live activities. Posting is cheap and safe whether or not
/// Notch Island is on.
@MainActor
@Observable
public final class LiveActivityCenter {
    public static let shared = LiveActivityCenter()

    public private(set) var activities: [LiveActivity] = []

    public init() {}

    /// Adds or replaces (by id) an activity.
    public func post(_ activity: LiveActivity) {
        activities.removeAll { $0.id == activity.id }
        activities.append(activity)
    }

    public func remove(_ id: String) {
        activities.removeAll { $0.id == id }
    }

    /// The one to show: highest priority, then newest; expired ones dropped.
    public func current(now: Date = Date()) -> LiveActivity? {
        Self.pick(activities, now: now)
    }

    public nonisolated static func pick(_ list: [LiveActivity], now: Date) -> LiveActivity? {
        let live = list.enumerated().filter { $0.element.expires.map { $0 > now } ?? true }
        return live.max { a, b in
            a.element.priority != b.element.priority ? a.element.priority < b.element.priority : a.offset < b.offset
        }?.element
    }

    /// Drops expired activities.
    public func prune(now: Date = Date()) {
        activities.removeAll { $0.expires.map { $0 <= now } ?? false }
    }
}
