import CoreGraphics

/// Where the island sits. On a Mac with a camera notch it's the notch itself
/// (the gap between the two menu bar areas beside it); elsewhere a small
/// "virtual notch" at the top middle.
public struct NotchGeometry: Equatable, Sendable {
    /// In screen coordinates (bottom-left origin, like AppKit).
    public var notch: CGRect
    public var hasHardwareNotch: Bool

    /// Size used when the screen has no notch.
    public static let virtualSize = CGSize(width: 190, height: 32)

    /// - Parameters:
    ///   - frame: the screen's frame.
    ///   - leftArea / rightArea: `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`,
    ///     nil without a notch.
    ///   - menuBarHeight: used for the virtual notch's height.
    public init(frame: CGRect, leftArea: CGRect?, rightArea: CGRect?, menuBarHeight: CGFloat) {
        if let leftArea, let rightArea, rightArea.minX > leftArea.maxX {
            let height = max(leftArea.height, rightArea.height)
            notch = CGRect(x: leftArea.maxX, y: frame.maxY - height, width: rightArea.minX - leftArea.maxX, height: height)
            hasHardwareNotch = true
        } else {
            let height = max(menuBarHeight, Self.virtualSize.height)
            notch = CGRect(x: frame.midX - Self.virtualSize.width / 2, y: frame.maxY - height, width: Self.virtualSize.width, height: height)
            hasHardwareNotch = false
        }
    }

    /// Window frame big enough for the opened island, centered on the notch
    /// and flush with the top of the screen.
    public func windowFrame(openSize: CGSize) -> CGRect {
        let width = max(openSize.width, notch.width) + 80
        let height = openSize.height + 40
        return CGRect(x: notch.midX - width / 2, y: notch.maxY - height, width: width, height: height)
    }
}
