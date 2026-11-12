import CoreGraphics

/// Remembers each window's frame from before Omni first moved it, so
/// "Restore" can put it back. If the user moves the window themselves
/// afterwards, the next Omni action records that new frame instead.
public struct RestoreHistory: Sendable {
    struct Entry: Sendable {
        var original: CGRect
        var lastApplied: CGRect
        var stamp: UInt64
    }

    static let capacity = 200
    /// Apps round sizes (e.g. to character cells); treat close frames as equal.
    static let tolerance: CGFloat = 3

    private var entries: [UInt32: Entry] = [:]
    private var clock: UInt64 = 0

    public init() {}

    /// Call before applying a layout. `current` is the window's frame now.
    public mutating func willApply(to windowID: UInt32, current: CGRect) {
        clock += 1
        if let entry = entries[windowID], Self.approximatelyEqual(entry.lastApplied, current) {
            entries[windowID]?.stamp = clock
            return
        }
        entries[windowID] = Entry(original: current, lastApplied: current, stamp: clock)
        evictIfNeeded()
    }

    /// Call after applying, with the frame the window actually ended up at.
    public mutating func didApply(to windowID: UInt32, actual: CGRect) {
        entries[windowID]?.lastApplied = actual
    }

    /// The frame to restore, if the window was moved by Omni and not since by the user.
    public func restoreFrame(for windowID: UInt32, current: CGRect) -> CGRect? {
        guard let entry = entries[windowID], Self.approximatelyEqual(entry.lastApplied, current) else { return nil }
        return entry.original
    }

    public mutating func forget(_ windowID: UInt32) {
        entries[windowID] = nil
    }

    public var count: Int { entries.count }

    static func approximatelyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }

    private mutating func evictIfNeeded() {
        guard entries.count > Self.capacity else { return }
        let oldest = entries.min { $0.value.stamp < $1.value.stamp }?.key
        if let oldest { entries[oldest] = nil }
    }
}
