import Foundation

/// Removes paused stretches from a recording's timeline. Pure (seconds in,
/// seconds out), so pause/resume timing is tested.
///
/// While paused, samples are dropped. The first sample after resuming adds
/// the length of the pause to `offset`, and every later sample is moved
/// earlier by `offset`, so the video continues without a frozen gap.
public struct PauseClock: Equatable, Sendable {
    public private(set) var isPaused = false
    /// Total paused time removed so far, in seconds.
    public private(set) var offset: Double = 0
    private var lastTime: Double?
    private var pausedAt: Double?

    public init() {}

    public mutating func pause() {
        guard !isPaused else { return }
        isPaused = true
        pausedAt = lastTime
    }

    public mutating func resume() {
        isPaused = false
    }

    /// The sample's time on the output timeline, or nil to drop it.
    public mutating func adjust(_ time: Double) -> Double? {
        if isPaused { return nil }
        if let start = pausedAt {
            offset += max(0, time - start)
            pausedAt = nil
        }
        // Never go backwards (audio and video arrive interleaved).
        lastTime = max(lastTime ?? time, time)
        return time - offset
    }
}

/// Wall-clock recording time that stops while paused (for the timer).
public struct RecordingTimer: Equatable, Sendable {
    public private(set) var start: Date
    public private(set) var pausedTotal: TimeInterval = 0
    public private(set) var pausedSince: Date?

    public init(start: Date) { self.start = start }

    public var isPaused: Bool { pausedSince != nil }

    public mutating func pause(at now: Date) {
        if pausedSince == nil { pausedSince = now }
    }

    public mutating func resume(at now: Date) {
        guard let since = pausedSince else { return }
        pausedTotal += now.timeIntervalSince(since)
        pausedSince = nil
    }

    public func elapsed(at now: Date) -> TimeInterval {
        let end = pausedSince ?? now
        return max(0, end.timeIntervalSince(start) - pausedTotal)
    }
}
