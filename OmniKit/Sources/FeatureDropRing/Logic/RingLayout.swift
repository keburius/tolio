import CoreGraphics
import Foundation

/// Where the orbs go: evenly on a circle, first one at the top, clockwise.
public struct RingLayout: Equatable, Sendable {
    public var center: CGPoint
    public var radius: CGFloat
    public var orbSize: CGFloat
    public var positions: [CGPoint]

    /// Space between neighbouring orbs along the circle.
    static let gap: CGFloat = 18
    static let minimumRadius: CGFloat = 110

    /// A ring of `count` orbs around `center`, moved inside `bounds` so no orb
    /// is cut off at a screen edge. Coordinates are top-left based (SwiftUI).
    public init(count: Int, orbSize: CGFloat, center: CGPoint, bounds: CGRect) {
        self.orbSize = orbSize
        let circumference = CGFloat(max(count, 1)) * (orbSize + Self.gap)
        radius = max(Self.minimumRadius, circumference / (2 * .pi))
        let reach = radius + orbSize / 2 + 8
        let x = min(max(center.x, bounds.minX + reach), bounds.maxX - reach)
        let y = min(max(center.y, bounds.minY + reach), bounds.maxY - reach)
        self.center = CGPoint(x: x.isFinite ? x : bounds.midX, y: y.isFinite ? y : bounds.midY)
        positions = (0..<count).map { [radius, c = self.center] index in
            let angle = -CGFloat.pi / 2 + 2 * .pi * CGFloat(index) / CGFloat(count)
            return CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
        }
    }

    /// Index of the orb under `point`, if any.
    public func hit(_ point: CGPoint) -> Int? {
        let reach = orbSize / 2
        return positions.indices.min { distance(positions[$0], point) < distance(positions[$1], point) }
            .flatMap { distance(positions[$0], point) <= reach ? $0 : nil }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}
