import CoreGraphics
import Foundation

/// A display as the capture math sees it.
public struct DisplayInfo: Equatable, Sendable {
    public var id: CGDirectDisplayID
    /// AppKit global coordinates (points, bottom-left origin of the primary display).
    public var frame: CGRect
    /// Pixels per point (2 on Retina).
    public var scale: CGFloat

    public init(id: CGDirectDisplayID, frame: CGRect, scale: CGFloat) {
        self.id = id
        self.frame = frame
        self.scale = scale
    }
}

/// How an area is captured: one piece per display it touches, composited
/// into one image. Pure, so the pixel math is unit-tested.
public struct CapturePlan: Equatable, Sendable {
    public struct Piece: Equatable, Sendable {
        public var displayID: CGDirectDisplayID
        /// Display-local points, top-left origin (what ScreenCaptureKit's `sourceRect` wants).
        public var sourceRect: CGRect
        /// Pixel size to request: the source at the display's own scale.
        public var pixelWidth: Int
        public var pixelHeight: Int
        public var scale: CGFloat
        /// Where the piece goes in the output image, in pixels, top-left origin.
        public var destination: CGRect
    }

    /// The area actually captured (snapped to the output pixel grid), AppKit global points.
    public var area: CGRect
    /// Output pixels per point: the highest scale among the displays touched.
    public var scale: CGFloat
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var pieces: [Piece]
}

public enum CaptureGeometry {
    /// Expands `rect` outward to whole pixels at `scale`.
    public static func snap(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let s = max(scale, 1)
        let minX = (rect.minX * s).rounded(.down) / s
        let minY = (rect.minY * s).rounded(.down) / s
        let maxX = (rect.maxX * s).rounded(.up) / s
        let maxY = (rect.maxY * s).rounded(.up) / s
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Plans the capture of `area` (AppKit global points). Returns nil if it
    /// doesn't touch any display.
    ///
    /// Each display is captured at its own native scale, so on a single
    /// display the output is pixel-for-pixel what's on screen. An area across
    /// displays with different scales is composited at the highest scale;
    /// the lower-scale part is enlarged (nearest neighbour), since there is
    /// no single native pixel grid for it.
    public static func plan(area: CGRect, displays: [DisplayInfo]) -> CapturePlan? {
        let touched = displays.filter { $0.frame.intersects(area) && !$0.frame.intersection(area).isEmpty }
        guard let scale = touched.map(\.scale).max() else { return nil }
        let union = touched.reduce(CGRect.null) { $0.union($1.frame) }
        let snapped = snap(area.intersection(union), scale: scale)
        let pixelWidth = Int((snapped.width * scale).rounded())
        let pixelHeight = Int((snapped.height * scale).rounded())
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
        let pieces = touched.compactMap { display -> CapturePlan.Piece? in
            let part = snap(snapped.intersection(display.frame), scale: display.scale).intersection(display.frame)
            guard part.width > 0, part.height > 0 else { return nil }
            let source = CGRect(
                x: part.minX - display.frame.minX,
                y: display.frame.maxY - part.maxY,
                width: part.width, height: part.height
            )
            let destination = CGRect(
                x: ((part.minX - snapped.minX) * scale).rounded(),
                y: ((snapped.maxY - part.maxY) * scale).rounded(),
                width: (part.width * scale).rounded(),
                height: (part.height * scale).rounded()
            )
            return CapturePlan.Piece(
                displayID: display.id, sourceRect: source,
                pixelWidth: Int((part.width * display.scale).rounded()),
                pixelHeight: Int((part.height * display.scale).rounded()),
                scale: display.scale, destination: destination
            )
        }
        return CapturePlan(area: snapped, scale: scale, pixelWidth: pixelWidth, pixelHeight: pixelHeight, pieces: pieces)
    }

    /// The display that should own a single-display operation (recording):
    /// the one containing the area's center, else the one with the largest overlap.
    public static func primaryDisplay(for area: CGRect, displays: [DisplayInfo]) -> DisplayInfo? {
        let center = CGPoint(x: area.midX, y: area.midY)
        if let display = displays.first(where: { $0.frame.contains(center) }) { return display }
        return displays.max { overlap($0.frame, area) < overlap($1.frame, area) }
            .flatMap { overlap($0.frame, area) > 0 ? $0 : nil }
    }

    private static func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let i = a.intersection(b)
        return i.isNull ? 0 : i.width * i.height
    }

    /// Video encoders need even dimensions. Shrinks the area by at most one
    /// pixel per axis (never grows past the display) and returns the result
    /// in display-local top-left points plus the pixel size.
    public static func recordingRect(area: CGRect, display: DisplayInfo) -> (source: CGRect, pixelWidth: Int, pixelHeight: Int)? {
        let part = snap(area.intersection(display.frame), scale: display.scale).intersection(display.frame)
        guard part.width > 0, part.height > 0 else { return nil }
        var width = Int((part.width * display.scale).rounded())
        var height = Int((part.height * display.scale).rounded())
        width -= width % 2
        height -= height % 2
        guard width >= 2, height >= 2 else { return nil }
        let source = CGRect(
            x: part.minX - display.frame.minX,
            y: display.frame.maxY - part.maxY,
            width: CGFloat(width) / display.scale,
            height: CGFloat(height) / display.scale
        )
        return (source, width, height)
    }
}
