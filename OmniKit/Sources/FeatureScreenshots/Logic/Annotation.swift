import CoreGraphics
import Foundation

public struct RGBAColor: Equatable, Hashable, Codable, Sendable {
    public var red, green, blue, alpha: CGFloat

    public init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

    public static let red = RGBAColor(0.95, 0.23, 0.19)
    public static let orange = RGBAColor(1, 0.58, 0)
    public static let yellow = RGBAColor(1, 0.86, 0.1)
    public static let green = RGBAColor(0.2, 0.78, 0.35)
    public static let blue = RGBAColor(0.04, 0.52, 1)
    public static let black = RGBAColor(0, 0, 0)
    public static let white = RGBAColor(1, 1, 1)
    public static let palette: [RGBAColor] = [.red, .orange, .yellow, .green, .blue, .black, .white]
}

/// One mark on a screenshot. Geometry is in image pixels, top-left origin.
public struct Annotation: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        case arrow(from: CGPoint, to: CGPoint)
        case box(CGRect)
        case text(origin: CGPoint, string: String, fontSize: CGFloat)
        case blur(CGRect)
        case highlight(CGRect)
        /// Numbered by order among steps (1, 2, 3 …), so deleting one renumbers the rest.
        case step(center: CGPoint, diameter: CGFloat)
    }

    public var id: UUID
    public var kind: Kind
    public var color: RGBAColor
    /// Pixels.
    public var lineWidth: CGFloat

    public init(id: UUID = UUID(), kind: Kind, color: RGBAColor = .red, lineWidth: CGFloat = 6) {
        self.id = id
        self.kind = kind
        self.color = color
        self.lineWidth = lineWidth
    }

    /// Rectangles are stored normalized (positive size).
    public static func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    public func moved(by delta: CGVector) -> Annotation {
        var copy = self
        func shift(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + delta.dx, y: p.y + delta.dy) }
        func shift(_ r: CGRect) -> CGRect { r.offsetBy(dx: delta.dx, dy: delta.dy) }
        switch kind {
        case let .arrow(from, to): copy.kind = .arrow(from: shift(from), to: shift(to))
        case let .box(r): copy.kind = .box(shift(r))
        case let .text(origin, string, size): copy.kind = .text(origin: shift(origin), string: string, fontSize: size)
        case let .blur(r): copy.kind = .blur(shift(r))
        case let .highlight(r): copy.kind = .highlight(shift(r))
        case let .step(center, diameter): copy.kind = .step(center: shift(center), diameter: diameter)
        }
        return copy
    }

    /// True for marks too small to keep (a click without a drag).
    public var isDegenerate: Bool {
        switch kind {
        case let .arrow(from, to): hypot(to.x - from.x, to.y - from.y) < 4
        case let .box(r), let .blur(r), let .highlight(r): r.width < 3 || r.height < 3
        case let .text(_, string, _): string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .step: false
        }
    }
}

/// Arrowhead points for an arrow drawn from `from` to `to`.
public enum ArrowGeometry {
    public static func headLength(lineWidth: CGFloat) -> CGFloat { max(lineWidth * 4, 12) }

    /// (left wing, tip, right wing).
    public static func head(from: CGPoint, to: CGPoint, lineWidth: CGFloat) -> (CGPoint, CGPoint, CGPoint) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let length = min(headLength(lineWidth: lineWidth), hypot(to.x - from.x, to.y - from.y))
        let spread = CGFloat.pi / 7
        let left = CGPoint(x: to.x - length * cos(angle - spread), y: to.y - length * sin(angle - spread))
        let right = CGPoint(x: to.x - length * cos(angle + spread), y: to.y - length * sin(angle + spread))
        return (left, to, right)
    }

    /// Where the shaft ends, so its square end doesn't poke out of the tip.
    public static func shaftEnd(from: CGPoint, to: CGPoint, lineWidth: CGFloat) -> CGPoint {
        let distance = hypot(to.x - from.x, to.y - from.y)
        guard distance > 0 else { return to }
        let back = min(headLength(lineWidth: lineWidth) * 0.8, distance)
        return CGPoint(x: to.x - (to.x - from.x) / distance * back, y: to.y - (to.y - from.y) / distance * back)
    }
}

/// A screenshot being edited: size, marks, and crop. Value type for undo.
public struct AnnotationDocument: Equatable, Sendable {
    public var pixelWidth: Int
    public var pixelHeight: Int
    /// Pixels per point of the capture (2 on Retina).
    public var scale: CGFloat
    public private(set) var annotations: [Annotation] = []
    /// Pixels, top-left origin, integral. nil = whole image.
    public private(set) var crop: CGRect?

    public init(pixelWidth: Int, pixelHeight: Int, scale: CGFloat) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.scale = scale
    }

    public var bounds: CGRect { CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight) }
    /// The area that will be exported.
    public var outputRect: CGRect { crop ?? bounds }

    public mutating func add(_ annotation: Annotation) {
        guard !annotation.isDegenerate else { return }
        annotations.append(annotation)
    }

    public mutating func replace(_ annotation: Annotation) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        if annotation.isDegenerate { annotations.remove(at: index) } else { annotations[index] = annotation }
    }

    public mutating func remove(_ id: UUID) {
        annotations.removeAll { $0.id == id }
    }

    public mutating func move(_ id: UUID, by delta: CGVector) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations[index] = annotations[index].moved(by: delta)
    }

    /// Sets the crop, snapped outward to whole pixels and clamped to the image.
    /// A crop smaller than 2×2 px or covering everything clears it.
    public mutating func setCrop(_ rect: CGRect?) {
        guard let rect else { crop = nil; return }
        let snapped = CGRect(
            x: rect.minX.rounded(.down), y: rect.minY.rounded(.down),
            width: 0, height: 0
        ).union(CGRect(x: rect.maxX.rounded(.up), y: rect.maxY.rounded(.up), width: 0, height: 0))
            .intersection(bounds)
        if snapped.isNull || snapped.width < 2 || snapped.height < 2 || snapped == bounds {
            crop = nil
        } else {
            crop = snapped
        }
    }

    /// The step number (1-based) of a step annotation.
    public func stepNumber(of id: UUID) -> Int? {
        var number = 0
        for annotation in annotations {
            if case .step = annotation.kind { number += 1 }
            if annotation.id == id { return number > 0 ? number : nil }
        }
        return nil
    }

    /// Default sizes in pixels for new marks, scaled with the capture.
    public var defaultLineWidth: CGFloat { 3 * scale }
    public var defaultFontSize: CGFloat { 18 * scale }
    public var defaultStepDiameter: CGFloat { 26 * scale }

    /// The topmost annotation at `point` (pixels), within `tolerance` pixels.
    public func hitTest(_ point: CGPoint, tolerance: CGFloat, textSize: (String, CGFloat) -> CGSize) -> UUID? {
        for annotation in annotations.reversed() {
            let pad = tolerance + annotation.lineWidth / 2
            switch annotation.kind {
            case let .arrow(from, to):
                if Self.distance(point, toSegment: from, to) <= pad { return annotation.id }
            case let .box(r):
                // Boxes are hollow: hit on the outline.
                let outer = r.insetBy(dx: -pad, dy: -pad), inner = r.insetBy(dx: pad, dy: pad)
                if outer.contains(point) && (inner.isNull || !inner.contains(point)) { return annotation.id }
            case let .blur(r), let .highlight(r):
                if r.insetBy(dx: -tolerance, dy: -tolerance).contains(point) { return annotation.id }
            case let .text(origin, string, size):
                let s = textSize(string, size)
                if CGRect(origin: origin, size: s).insetBy(dx: -tolerance, dy: -tolerance).contains(point) { return annotation.id }
            case let .step(center, diameter):
                if hypot(point.x - center.x, point.y - center.y) <= diameter / 2 + tolerance { return annotation.id }
            }
        }
        return nil
    }

    static func distance(_ p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}
