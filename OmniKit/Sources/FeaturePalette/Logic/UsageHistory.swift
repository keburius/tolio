import Foundation

/// How often and how recently each palette item was chosen. Used to boost
/// ranking and to fill the empty-query list.
public struct UsageHistory: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var count: Int
        public var lastUsed: Date
    }

    static let maxEntries = 200
    static let halfLifeDays = 14.0

    public private(set) var entries: [String: Entry] = [:]

    public init() {}

    public mutating func record(_ id: String, at now: Date) {
        var entry = entries[id] ?? Entry(count: 0, lastUsed: now)
        entry.count += 1
        entry.lastUsed = now
        entries[id] = entry
        if entries.count > Self.maxEntries {
            let oldest = entries.sorted { $0.value.lastUsed < $1.value.lastUsed }.prefix(entries.count - Self.maxEntries)
            for (key, _) in oldest { entries[key] = nil }
        }
    }

    /// 0 for never used; grows with count and decays with age.
    public func boost(for id: String, at now: Date) -> Double {
        guard let entry = entries[id] else { return 0 }
        let days = max(0, now.timeIntervalSince(entry.lastUsed) / 86_400)
        let decay = pow(0.5, days / Self.halfLifeDays)
        return 3 * log2(1 + Double(entry.count)) * decay
    }
}
