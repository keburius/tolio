import SwiftUI

/// A shape made from SVG path data (`d`), drawn in a square `viewBox`
/// and scaled to whatever frame it gets. Lets the app use the design's
/// icons exactly as drawn.
///
/// Supports M L H V C S Q T A Z, absolute and relative.
public struct SVGPath: Shape {
    let path: Path
    let viewBox: CGSize

    public init(_ data: String, viewBox: CGFloat = 16) {
        self.init(data, viewBox: CGSize(width: viewBox, height: viewBox))
    }

    public init(_ data: String, viewBox: CGSize) {
        path = SVGPathParser.parse(data)
        self.viewBox = viewBox
    }

    public func path(in rect: CGRect) -> Path {
        let sx = rect.width / viewBox.width, sy = rect.height / viewBox.height
        return path.applying(CGAffineTransform(a: sx, b: 0, c: 0, d: sy, tx: rect.minX, ty: rect.minY))
    }
}

/// A stroked line icon from the design (16×16 grid, round caps and joins).
public struct LineIcon: View {
    let data: String
    let size: CGFloat
    let lineWidth: CGFloat
    let viewBox: CGFloat
    let color: Color?

    /// - Parameters:
    ///   - lineWidth: stroke width in viewBox units, as written in the design.
    ///   - color: nil uses the current foreground style.
    public init(_ data: String, size: CGFloat = 16, lineWidth: CGFloat = 1.7, viewBox: CGFloat = 16, color: Color? = nil) {
        self.data = data
        self.size = size
        self.lineWidth = lineWidth
        self.viewBox = viewBox
        self.color = color
    }

    public var body: some View {
        let shape = SVGPath(data, viewBox: viewBox)
        let style = StrokeStyle(lineWidth: lineWidth * size / viewBox, lineCap: .round, lineJoin: .round)
        Group {
            if let color { shape.stroke(color, style: style) } else { shape.stroke(style: style) }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

enum SVGPathParser {
    static func parse(_ data: String) -> Path {
        var scanner = Tokens(Array(data.utf8))
        var path = Path()
        var current = CGPoint.zero, start = CGPoint.zero
        var lastControl: CGPoint?
        var lastCommand: UInt8 = 0
        var command: UInt8 = 0

        while let next = scanner.nextCommandOrNumber() {
            if case let .command(c) = next { command = c } else if command == 0 { break } else { scanner.pushBack() }
            let relative = command >= 97 // lowercase
            let base = relative ? current : .zero
            switch command | 0x20 {
            case UInt8(ascii: "m"):
                guard let p = scanner.point() else { return path }
                current = CGPoint(x: base.x + p.x, y: base.y + p.y)
                start = current
                path.move(to: current)
                // Following pairs are implicit line-tos.
                command = relative ? UInt8(ascii: "l") : UInt8(ascii: "L")
                lastControl = nil
            case UInt8(ascii: "l"):
                guard let p = scanner.point() else { return path }
                current = CGPoint(x: base.x + p.x, y: base.y + p.y)
                path.addLine(to: current)
                lastControl = nil
            case UInt8(ascii: "h"):
                guard let x = scanner.number() else { return path }
                current.x = relative ? current.x + x : x
                path.addLine(to: current)
                lastControl = nil
            case UInt8(ascii: "v"):
                guard let y = scanner.number() else { return path }
                current.y = relative ? current.y + y : y
                path.addLine(to: current)
                lastControl = nil
            case UInt8(ascii: "c"):
                guard let c1 = scanner.point(), let c2 = scanner.point(), let p = scanner.point() else { return path }
                let a = c1.offset(base), b = c2.offset(base)
                current = p.offset(base)
                path.addCurve(to: current, control1: a, control2: b)
                lastControl = b
            case UInt8(ascii: "s"):
                guard let c2 = scanner.point(), let p = scanner.point() else { return path }
                let wasCubic = [UInt8(ascii: "c"), UInt8(ascii: "s")].contains(lastCommand | 0x20)
                let a = wasCubic ? current.reflect(lastControl ?? current) : current
                let b = c2.offset(base)
                current = p.offset(base)
                path.addCurve(to: current, control1: a, control2: b)
                lastControl = b
            case UInt8(ascii: "q"):
                guard let c = scanner.point(), let p = scanner.point() else { return path }
                let control = c.offset(base)
                current = p.offset(base)
                path.addQuadCurve(to: current, control: control)
                lastControl = control
            case UInt8(ascii: "t"):
                guard let p = scanner.point() else { return path }
                let wasQuad = [UInt8(ascii: "q"), UInt8(ascii: "t")].contains(lastCommand | 0x20)
                let control = wasQuad ? current.reflect(lastControl ?? current) : current
                current = p.offset(base)
                path.addQuadCurve(to: current, control: control)
                lastControl = control
            case UInt8(ascii: "a"):
                guard let rx = scanner.number(), let ry = scanner.number(), let rotation = scanner.number(),
                      let large = scanner.flag(), let sweep = scanner.flag(), let p = scanner.point() else { return path }
                let end = p.offset(base)
                addArc(to: &path, from: current, to: end, rx: rx, ry: ry, rotation: rotation, large: large, sweep: sweep)
                current = end
                lastControl = nil
            case UInt8(ascii: "z"):
                path.closeSubpath()
                current = start
                lastControl = nil
            default:
                return path
            }
            lastCommand = command
        }
        return path
    }

    /// SVG elliptical arc, converted to center form and drawn as cubic curves.
    private static func addArc(to path: inout Path, from p0: CGPoint, to p1: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat, rotation: CGFloat, large: Bool, sweep: Bool) {
        var rx = abs(rxIn), ry = abs(ryIn)
        guard rx > 0, ry > 0, p0 != p1 else { path.addLine(to: p1); return }
        let phi = rotation * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var coef = sqrt(max(0, num / den))
        if large == sweep { coef = -coef }
        let cx1 = coef * rx * y1 / ry
        let cy1 = -coef * ry * x1 / rx
        let cx = cosPhi * cx1 - sinPhi * cy1 + (p0.x + p1.x) / 2
        let cy = sinPhi * cx1 + cosPhi * cy1 + (p0.y + p1.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
            return a
        }
        let theta1 = angle(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var delta = angle((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !sweep, delta > 0 { delta -= 2 * .pi } else if sweep, delta < 0 { delta += 2 * .pi }

        // Split into ≤90° segments.
        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / CGFloat(segments)
        let t = 4 / 3 * tan(step / 4)
        var theta = theta1
        func point(_ a: CGFloat) -> CGPoint {
            let x = rx * cos(a), y = ry * sin(a)
            return CGPoint(x: cx + cosPhi * x - sinPhi * y, y: cy + sinPhi * x + cosPhi * y)
        }
        func derivative(_ a: CGFloat) -> CGPoint {
            let x = -rx * sin(a), y = ry * cos(a)
            return CGPoint(x: cosPhi * x - sinPhi * y, y: sinPhi * x + cosPhi * y)
        }
        for _ in 0 ..< segments {
            let next = theta + step
            let a = point(theta), b = point(next)
            let da = derivative(theta), db = derivative(next)
            path.addCurve(to: b,
                          control1: CGPoint(x: a.x + t * da.x, y: a.y + t * da.y),
                          control2: CGPoint(x: b.x - t * db.x, y: b.y - t * db.y))
            theta = next
        }
    }

    private struct Tokens {
        enum Token { case command(UInt8), number(CGFloat) }
        let bytes: [UInt8]
        var index = 0
        var previous = 0

        init(_ bytes: [UInt8]) { self.bytes = bytes }

        mutating func skipSeparators() {
            while index < bytes.count, [UInt8(ascii: " "), UInt8(ascii: ","), 9, 10, 13].contains(bytes[index]) { index += 1 }
        }

        mutating func pushBack() { index = previous }

        mutating func nextCommandOrNumber() -> Token? {
            skipSeparators()
            previous = index
            guard index < bytes.count else { return nil }
            let b = bytes[index]
            if (b >= 65 && b <= 90 || b >= 97 && b <= 122) && b != UInt8(ascii: "e") && b != UInt8(ascii: "E") {
                index += 1
                return .command(b)
            }
            guard let n = number() else { return nil }
            return .number(n)
        }

        mutating func number() -> CGFloat? {
            skipSeparators()
            let begin = index
            var seenDot = false, seenExp = false
            if index < bytes.count, bytes[index] == UInt8(ascii: "-") || bytes[index] == UInt8(ascii: "+") { index += 1 }
            while index < bytes.count {
                let b = bytes[index]
                if b >= 48 && b <= 57 { index += 1 }
                else if b == UInt8(ascii: "."), !seenDot, !seenExp { seenDot = true; index += 1 }
                else if b == UInt8(ascii: "e") || b == UInt8(ascii: "E"), !seenExp {
                    seenExp = true; index += 1
                    if index < bytes.count, bytes[index] == UInt8(ascii: "-") || bytes[index] == UInt8(ascii: "+") { index += 1 }
                } else { break }
            }
            guard index > begin, let text = String(bytes: bytes[begin ..< index], encoding: .ascii), let value = Double(text) else {
                index = begin
                return nil
            }
            return CGFloat(value)
        }

        /// Arc flags may be written without separators ("a1 1 0 01…").
        mutating func flag() -> Bool? {
            skipSeparators()
            guard index < bytes.count else { return nil }
            let b = bytes[index]
            guard b == UInt8(ascii: "0") || b == UInt8(ascii: "1") else { return nil }
            index += 1
            return b == UInt8(ascii: "1")
        }

        mutating func point() -> CGPoint? {
            guard let x = number(), let y = number() else { return nil }
            return CGPoint(x: x, y: y)
        }
    }
}

private extension CGPoint {
    func offset(_ base: CGPoint) -> CGPoint { CGPoint(x: x + base.x, y: y + base.y) }
    /// The reflection of `control` about self.
    func reflect(_ control: CGPoint) -> CGPoint { CGPoint(x: 2 * x - control.x, y: 2 * y - control.y) }
}
