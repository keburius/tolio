import CoreGraphics

/// One display in Accessibility coordinates: origin at the top-left of the
/// primary display, y growing downward (the space AX and CGEvent use).
public struct ScreenInfo: Equatable, Sendable {
    public let frame: CGRect
    /// Excludes the menu bar and Dock.
    public let visibleFrame: CGRect

    public init(frame: CGRect, visibleFrame: CGRect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

/// Conversions between AppKit (bottom-left origin, y up) and AX coordinates.
public enum ScreenGeometry {
    /// Converts a rect from AppKit coordinates to AX coordinates.
    /// `primaryHeight` is the height of the display with the menu bar (`NSScreen.screens[0]`).
    public static func toAX(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// The same flip is its own inverse.
    public static func toAppKit(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        toAX(rect, primaryHeight: primaryHeight)
    }

    /// Builds AX-space screen infos from AppKit frames (first = primary).
    public static func screens(appKitFrames: [(frame: CGRect, visible: CGRect)]) -> [ScreenInfo] {
        guard let primary = appKitFrames.first else { return [] }
        let height = primary.frame.height
        return appKitFrames.map {
            ScreenInfo(frame: toAX($0.frame, primaryHeight: height), visibleFrame: toAX($0.visible, primaryHeight: height))
        }
    }

    /// Index of the screen showing most of `window`; falls back to the
    /// screen containing its center, then the first screen.
    public static func screenIndex(for window: CGRect, in screens: [ScreenInfo]) -> Int? {
        guard !screens.isEmpty else { return nil }
        let areas = screens.map { screen -> CGFloat in
            let overlap = screen.frame.intersection(window)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        if let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 { return best }
        let center = CGPoint(x: window.midX, y: window.midY)
        return screens.firstIndex { $0.frame.contains(center) } ?? 0
    }

    /// Screens ordered left to right, then top to bottom: the order
    /// "next display" walks through.
    public static func displayOrder(_ screens: [ScreenInfo]) -> [Int] {
        screens.indices.sorted {
            let a = screens[$0].frame, b = screens[$1].frame
            return a.minX != b.minX ? a.minX < b.minX : a.minY < b.minY
        }
    }
}
