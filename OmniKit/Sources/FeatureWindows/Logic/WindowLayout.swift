import CoreGraphics

/// Computes target frames. All rects are in AX coordinates.
public enum WindowLayout {
    /// Target frame for `action` on a screen with `visible` frame, or nil
    /// for actions that aren't plain layouts (display moves, restore).
    /// `gap` puts space between windows and screen edges.
    public static func frame(for action: WindowAction, window: CGRect, visible: CGRect, gap: CGFloat = 0) -> CGRect? {
        let area = visible.insetBy(dx: gap / 2, dy: gap / 2)
        let w = area.width, h = area.height, x = area.minX, y = area.minY
        let cell: CGRect
        switch action {
        case .leftHalf: cell = CGRect(x: x, y: y, width: w / 2, height: h)
        case .rightHalf: cell = CGRect(x: x + w / 2, y: y, width: w / 2, height: h)
        case .topHalf: cell = CGRect(x: x, y: y, width: w, height: h / 2)
        case .bottomHalf: cell = CGRect(x: x, y: y + h / 2, width: w, height: h / 2)
        case .firstThird: cell = CGRect(x: x, y: y, width: w / 3, height: h)
        case .centerThird: cell = CGRect(x: x + w / 3, y: y, width: w / 3, height: h)
        case .lastThird: cell = CGRect(x: x + 2 * w / 3, y: y, width: w / 3, height: h)
        case .firstTwoThirds: cell = CGRect(x: x, y: y, width: 2 * w / 3, height: h)
        case .lastTwoThirds: cell = CGRect(x: x + w / 3, y: y, width: 2 * w / 3, height: h)
        case .topLeft: cell = CGRect(x: x, y: y, width: w / 2, height: h / 2)
        case .topRight: cell = CGRect(x: x + w / 2, y: y, width: w / 2, height: h / 2)
        case .bottomLeft: cell = CGRect(x: x, y: y + h / 2, width: w / 2, height: h / 2)
        case .bottomRight: cell = CGRect(x: x + w / 2, y: y + h / 2, width: w / 2, height: h / 2)
        case .maximize: cell = area
        case .center:
            let size = CGSize(width: min(window.width, visible.width), height: min(window.height, visible.height))
            return CGRect(
                x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                width: size.width, height: size.height
            ).integral
        case .nextDisplay, .previousDisplay, .restore:
            return nil
        }
        return cell.insetBy(dx: gap / 2, dy: gap / 2).integral
    }

    /// Moves `window` from one screen to another, keeping its position and
    /// size relative to the visible area, then fitting it inside.
    public static func move(_ window: CGRect, from source: CGRect, to target: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return window }
        let rx = (window.minX - source.minX) / source.width
        let ry = (window.minY - source.minY) / source.height
        let rw = window.width / source.width
        let rh = window.height / source.height
        let mapped = CGRect(
            x: target.minX + rx * target.width, y: target.minY + ry * target.height,
            width: rw * target.width, height: rh * target.height
        )
        return clamp(mapped, into: target).integral
    }

    /// Where to put a window whose actual size (after the app applied its
    /// minimum or step size) differs from the target. Keeps the edge the
    /// action is anchored to, then keeps the window inside `bounds`.
    public static func fit(actualSize: CGSize, target: CGRect, action: WindowAction, bounds: CGRect) -> CGRect {
        var origin = target.origin
        if actualSize.width != target.width {
            if action.anchorsRight {
                origin.x = target.maxX - actualSize.width
            } else if action.centersHorizontally {
                origin.x = target.midX - actualSize.width / 2
            }
        }
        if actualSize.height != target.height {
            if action.anchorsBottom {
                origin.y = target.maxY - actualSize.height
            } else if action.centersVertically {
                origin.y = target.midY - actualSize.height / 2
            }
        }
        return clamp(CGRect(origin: origin, size: actualSize), into: bounds).integral
    }

    /// Shifts (and if needed shrinks) `rect` so it lies inside `bounds`,
    /// preferring to keep the top-left visible.
    public static func clamp(_ rect: CGRect, into bounds: CGRect) -> CGRect {
        var result = rect
        result.size.width = min(result.width, bounds.width)
        result.size.height = min(result.height, bounds.height)
        result.origin.x = min(max(result.minX, bounds.minX), bounds.maxX - result.width)
        result.origin.y = min(max(result.minY, bounds.minY), bounds.maxY - result.height)
        return result
    }
}
