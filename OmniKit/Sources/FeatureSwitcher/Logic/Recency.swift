import CoreGraphics

/// Most-recently-focused windows, newest first.
public struct RecencyTracker: Sendable {
    static let capacity = 500
    public private(set) var order: [CGWindowID] = []

    public init() {}

    /// Marks `id` as just focused.
    public mutating func touch(_ id: CGWindowID) {
        if order.first == id { return }
        order.removeAll { $0 == id }
        order.insert(id, at: 0)
        if order.count > Self.capacity { order.removeLast(order.count - Self.capacity) }
    }

    /// Drops windows that no longer exist.
    public mutating func retain(only existing: Set<CGWindowID>) {
        order.removeAll { !existing.contains($0) }
    }
}

/// Orders switcher rows.
public enum SwitcherOrdering {
    /// Recently focused first; windows never seen focused follow in
    /// front-to-back stacking order. Minimized windows come after all
    /// others, then windows of hidden apps.
    public static func sort(_ records: [WindowRecord], recency: [CGWindowID], zOrder: [CGWindowID]) -> [WindowRecord] {
        let recencyRank = Dictionary(recency.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let zRank = Dictionary(zOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        func group(_ state: WindowState) -> Int {
            switch state {
            case .normal, .otherSpace: 0
            case .minimized: 1
            case .hidden: 2
            }
        }
        return records.enumerated().sorted { lhs, rhs in
            let a = lhs.element, b = rhs.element
            let keyA = (group(a.state), recencyRank[a.id] ?? Int.max, zRank[a.id] ?? Int.max, lhs.offset)
            let keyB = (group(b.state), recencyRank[b.id] ?? Int.max, zRank[b.id] ?? Int.max, rhs.offset)
            return keyA < keyB
        }.map(\.element)
    }
}
