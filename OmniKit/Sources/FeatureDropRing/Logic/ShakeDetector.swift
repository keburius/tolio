import Foundation

/// Spots a quick side-to-side shake of the pointer: several changes of
/// horizontal direction, each a real stroke, within a short time.
public struct ShakeDetector: Sendable {
    /// 0 (needs a big shake) … 1 (a small wiggle is enough).
    public var sensitivity: Double

    private var lastX: Double?
    private var direction = 0
    private var strokeStart: Double = 0
    private var reversals: [TimeInterval] = []
    private var cooldownUntil: TimeInterval = 0

    static let window: TimeInterval = 0.7
    static let cooldown: TimeInterval = 0.8

    public init(sensitivity: Double = 0.5) {
        self.sensitivity = sensitivity
    }

    /// Reversals needed: 5 at low sensitivity, 3 at high.
    var neededReversals: Int { sensitivity >= 0.67 ? 3 : (sensitivity >= 0.34 ? 4 : 5) }
    /// Shortest stroke that counts, in points: 70 at low sensitivity, 25 at high.
    var minimumStroke: Double { 70 - 45 * min(max(sensitivity, 0), 1) }

    /// Feeds one pointer position; true when this completes a shake.
    public mutating func add(x: Double, time: TimeInterval) -> Bool {
        defer { lastX = x }
        guard let lastX else {
            strokeStart = x
            return false
        }
        let delta = x - lastX
        guard abs(delta) > 0.5 else { return false }
        let newDirection = delta > 0 ? 1 : -1
        if newDirection != direction {
            if direction != 0, abs(lastX - strokeStart) >= minimumStroke {
                reversals.append(time)
            }
            direction = newDirection
            strokeStart = lastX
        }
        reversals.removeAll { time - $0 > Self.window }
        guard time >= cooldownUntil, reversals.count >= neededReversals else { return false }
        reversals.removeAll()
        cooldownUntil = time + Self.cooldown
        return true
    }

    public mutating func reset() {
        lastX = nil
        direction = 0
        reversals.removeAll()
    }
}
