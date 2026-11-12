import CoreGraphics

/// Which layout a window dragged to a screen edge should snap to.
public enum SnapZones {
    /// Distance from an edge (points) that counts as "at the edge".
    static let edgeMargin: CGFloat = 4
    /// Size of the corner areas along each edge.
    static let cornerSize: CGFloat = 60

    /// The snap action for the mouse at `point` (AX coordinates), or nil.
    /// Edges shared with another display don't snap, since the pointer
    /// passes through them.
    public static func action(at point: CGPoint, screens: [ScreenInfo]) -> WindowAction? {
        guard let screen = screens.first(where: { $0.frame.contains(point) || onBoundary(point, $0.frame) }) else {
            return nil
        }
        let f = screen.frame
        func open(_ probe: CGPoint) -> Bool { !screens.contains { $0 != screen && $0.frame.contains(probe) } }

        let atLeft = point.x <= f.minX + edgeMargin && open(CGPoint(x: f.minX - 1, y: point.y))
        let atRight = point.x >= f.maxX - 1 - edgeMargin && open(CGPoint(x: f.maxX + 1, y: point.y))
        let atTop = point.y <= f.minY + edgeMargin && open(CGPoint(x: point.x, y: f.minY - 1))
        let atBottom = point.y >= f.maxY - 1 - edgeMargin && open(CGPoint(x: point.x, y: f.maxY + 1))
        let nearTop = point.y <= f.minY + cornerSize
        let nearBottom = point.y >= f.maxY - cornerSize
        let nearLeft = point.x <= f.minX + cornerSize
        let nearRight = point.x >= f.maxX - cornerSize

        if atLeft { return nearTop ? .topLeft : nearBottom ? .bottomLeft : .leftHalf }
        if atRight { return nearTop ? .topRight : nearBottom ? .bottomRight : .rightHalf }
        if atTop { return nearLeft ? .topLeft : nearRight ? .topRight : .maximize }
        if atBottom { return nearLeft ? .bottomLeft : nearRight ? .bottomRight : nil }
        return nil
    }

    private static func onBoundary(_ point: CGPoint, _ frame: CGRect) -> Bool {
        point.x >= frame.minX && point.x <= frame.maxX && point.y >= frame.minY && point.y <= frame.maxY
    }
}
