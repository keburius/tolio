import SwiftUI

/// Each feature's own mark, drawn on a 24×24 grid as in the design:
/// full-strength parts, dimmed parts, and parts cut out of what is below.
public struct FeatureGlyph: View {
    let glyph: Glyph
    let color: Color

    public init(_ glyph: Glyph, color: Color) {
        self.glyph = glyph
        self.color = color
    }

    public var body: some View {
        Rectangle()
            .fill(color)
            .mask {
                Canvas { context, size in
                    let scale = size.width / 24
                    context.scaleBy(x: scale, y: scale)
                    for element in glyph.elements { element.draw(in: &context) }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }

    // MARK: - Glyphs

    public enum Glyph: String, CaseIterable, Sendable {
        case clipboardHistory, notchIsland, dropRing, deskMinder, energyMode, windowLayouts, screenshots
        case lockKeyboard, windowSwitcher, captureText, desktopNotes, shortcutCheatSheet, textActions, systemStats

        var elements: [Element] {
            switch self {
            case .clipboardHistory:
                [.rect(5, 4.5, 14, 17, 3.2, .full), .rect(7.9, 2.4, 8.2, 5.4, 2.1, .cut), .rect(8.9, 3.2, 6.2, 3.6, 1.3, .full),
                 .rect(8, 11.2, 8, 1.8, 0.9, .cut), .rect(8, 14.8, 5.4, 1.8, 0.9, .cut)]
            case .notchIsland:
                [.rect(2, 4.5, 20, 15, 3.4, .full), .fill("M7.5 4.5h9v2.6a2 2 0 0 1-2 2h-5a2 2 0 0 1-2-2z", .cut)]
            case .dropRing:
                [.circle(12, 4, 2.3, .full), .circle(18.93, 8, 2.3, .dim), .circle(18.93, 16, 2.3, .dim), .circle(12, 20, 2.3, .dim),
                 .circle(5.07, 16, 2.3, .dim), .circle(5.07, 8, 2.3, .dim),
                 .stroke("M12 8.6v6M9.3 12.1l2.7 2.7 2.7-2.7", 2.2, .full)]
            case .deskMinder:
                [.stroke("M4.3 6.7L7.1 4.3M19.7 6.7L16.9 4.3", 2.4, .full), .circle(12, 13, 7.7, .full),
                 .stroke("M12 9v4.2l2.8 1.9", 1.9, .cut)]
            case .energyMode:
                [.stroke("M8.2 2.8c-1 1.3 1 2.2 0 3.7M12.4 2.8c-1 1.3 1 2.2 0 3.7", 1.7, .dim),
                 .fill("M4.6 8.8h11.6v5.4a5.8 5.8 0 0 1-11.6 0z", .full),
                 .stroke("M16.4 10.6h1.3a2.5 2.5 0 0 1 0 5h-1.9", 1.9, .full), .rect(4.2, 21, 12.4, 1.7, 0.85, .full)]
            case .windowLayouts:
                [.rect(2.5, 5, 19, 14, 3.2, .dim), .fill("M5.7 5H11.2V19H5.7a3.2 3.2 0 0 1-3.2-3.2V8.2A3.2 3.2 0 0 1 5.7 5z", .full),
                 .rect(11.2, 5, 1.6, 14, 0, .cut)]
            case .screenshots:
                [.stroke(Self.corners, 2.2, .full), .rect(9.7, 7.7, 4.6, 2.6, 1, .full), .rect(6.9, 9.1, 10.2, 7.5, 2, .full),
                 .circle(12, 12.9, 2.15, .cut)]
            case .lockKeyboard:
                [.rect(2, 5.5, 20, 12.5, 3.2, .full)]
                    + [4.4, 7.5, 10.6, 13.7, 16.8].flatMap { x in [Element.rect(x, 8.6, 2.2, 2.2, 0.7, .cut), .rect(x, 11.8, 2.2, 2.2, 0.7, .cut)] }
                    + [.rect(7.5, 14.9, 7, 1.8, 0.9, .cut), .circle(18.3, 17.3, 5.3, .cut), .rect(15.3, 16.4, 6, 4.7, 1.3, .full),
                       .stroke("M16.7 16.4v-1.2a1.6 1.6 0 0 1 3.2 0v1.2", 1.4, .full)]
            case .windowSwitcher:
                [.rect(8, 2.2, 8, 1.9, 0.95, .dim), .rect(5.5, 5.3, 13, 2.1, 1.05, .dim), .rect(3, 8.6, 18, 12, 3.2, .full)]
            case .captureText:
                [.stroke(Self.corners, 2.2, .full), .rect(7.2, 8.3, 9.6, 2, 1, .full), .rect(7.2, 11.6, 6.2, 2, 1, .full),
                 .rect(7.2, 14.9, 8.2, 2, 1, .full)]
            case .desktopNotes:
                [.fill("M6.5 3.5h11a3 3 0 0 1 3 3v7.2L13.7 20.5H6.5a3 3 0 0 1-3-3v-11a3 3 0 0 1 3-3z", .full),
                 .fill("M20.5 13.7h-4.3a2.5 2.5 0 0 0-2.5 2.5v4.3z", .dim),
                 .rect(7, 7.8, 10, 1.8, 0.9, .cut), .rect(7, 11.4, 6, 1.8, 0.9, .cut)]
            case .shortcutCheatSheet:
                [.rect(3, 3, 18, 18, 4.6, .full),
                 .scaledStroke("M9 9h6v6H9zM9 9V6.75A2.25 2.25 0 1 0 6.75 9H9M15 9V6.75A2.25 2.25 0 1 1 17.25 9H15M9 15v2.25A2.25 2.25 0 1 1 6.75 15H9M15 15v2.25a2.25 2.25 0 1 0 2.25-2.25H15", 2.5, 0.72, .cut)]
            case .textActions:
                [.letter("A", x: 2.6, baseline: 18.4, size: 18),
                 .stroke("M19.4 5.6v12.8M17.3 4.2h1.2a.9.9 0 0 1 .9.9M21.5 4.2h-1.2a.9.9 0 0 0-.9.9M17.3 19.8h1.2a.9.9 0 0 0 .9-.9M21.5 19.8h-1.2a.9.9 0 0 1-.9-.9", 1.8, .full)]
            case .systemStats:
                [.rect(3.5, 12, 4.4, 8.5, 1.5, .dim), .rect(9.8, 4, 4.4, 16.5, 1.5, .full), .rect(16.1, 8.5, 4.4, 12, 1.5, .full)]
            }
        }

        private static let corners = "M3.5 8.5V6.5a3 3 0 0 1 3-3h2M15.5 3.5h2a3 3 0 0 1 3 3v2M20.5 15.5v2a3 3 0 0 1-3 3h-2M8.5 20.5h-2a3 3 0 0 1-3-3v-2"
    }

    /// How a part is painted into the mask: white, #909090, or black in the design.
    enum Ink { case full, dim, cut }

    enum Element {
        case rect(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, Ink)
        case circle(CGFloat, CGFloat, CGFloat, Ink)
        case fill(String, Ink)
        case stroke(String, CGFloat, Ink)
        /// A stroke scaled about the center (the cheat sheet's ⌘).
        case scaledStroke(String, CGFloat, CGFloat, Ink)
        case letter(String, x: CGFloat, baseline: CGFloat, size: CGFloat)

        func draw(in context: inout GraphicsContext) {
            switch self {
            case let .rect(x, y, w, h, r, ink):
                paint(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r, style: .circular), ink, &context)
            case let .circle(cx, cy, r, ink):
                paint(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)), ink, &context)
            case let .fill(data, ink):
                paint(SVGPathParser.parse(data), ink, &context)
            case let .stroke(data, width, ink):
                paint(outline(SVGPathParser.parse(data), width), ink, &context)
            case let .scaledStroke(data, width, scale, ink):
                let transform = CGAffineTransform(translationX: 12, y: 12).scaledBy(x: scale, y: scale).translatedBy(x: -12, y: -12)
                paint(outline(SVGPathParser.parse(data), width).applying(transform), ink, &context)
            case let .letter(text, x, baseline, size):
                let resolved = context.resolve(Text(verbatim: text).font(.system(size: size, weight: .bold, design: .rounded)).foregroundColor(.white))
                let measured = resolved.measure(in: CGSize(width: 100, height: 100))
                let top = baseline - resolved.firstBaseline(in: measured)
                context.draw(resolved, in: CGRect(x: x, y: top, width: measured.width, height: measured.height))
            }
        }

        private func outline(_ path: Path, _ width: CGFloat) -> Path {
            path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }

        private func paint(_ path: Path, _ ink: Ink, _ context: inout GraphicsContext) {
            switch ink {
            case .full:
                context.fill(path, with: .color(.white))
            case .dim:
                // Replace whatever is below (mask luminance #909090 ≈ 56 %).
                var cut = context
                cut.blendMode = .destinationOut
                cut.fill(path, with: .color(.white))
                context.fill(path, with: .color(.white.opacity(0.565)))
            case .cut:
                var cut = context
                cut.blendMode = .destinationOut
                cut.fill(path, with: .color(.white))
            }
        }
    }
}
