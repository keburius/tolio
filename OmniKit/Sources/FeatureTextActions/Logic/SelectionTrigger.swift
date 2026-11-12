import CoreGraphics
import Foundation

/// Heuristic "a selection was probably just made" detector. There's no
/// system-wide selection-changed event, so it watches the gestures that
/// usually select text: a mouse drag, a double/triple click, shift+click,
/// and shift+arrow keys. Pure; the caller feeds events and runs effects.
public struct SelectionTrigger: Sendable {
    public enum Kind: Equatable, Sendable {
        /// Down and up points (AppKit coordinates) of the gesture.
        case mouse(down: CGPoint, up: CGPoint)
        case keyboard
    }

    public enum Input: Equatable, Sendable {
        case mouseDown(CGPoint, clickCount: Int, shift: Bool)
        case mouseDragged(CGPoint)
        case mouseUp(CGPoint)
        /// keyUp of an arrow / Home / End key with ⇧ held.
        case shiftNavigationKeyUp
        /// Any other key press (typing): the popup must go.
        case keyDown
        case scroll
    }

    public enum Effect: Equatable, Sendable {
        /// Look for a selection after `delay` seconds (the app updates it first).
        case check(Kind, delay: TimeInterval)
        case dismiss
    }

    /// Minimum drag distance in points to count as a selection drag.
    public static let dragThreshold: CGFloat = 6
    public static let mouseDelay: TimeInterval = 0.12
    public static let keyboardDelay: TimeInterval = 0.35

    private var down: CGPoint?
    private var clickCount = 0
    private var shiftClick = false
    private var dragged = false

    public init() {}

    public mutating func handle(_ input: Input) -> [Effect] {
        switch input {
        case let .mouseDown(point, count, shift):
            down = point
            clickCount = count
            shiftClick = shift
            dragged = false
            return []
        case let .mouseDragged(point):
            if let down, !dragged, hypot(point.x - down.x, point.y - down.y) >= Self.dragThreshold { dragged = true }
            return []
        case let .mouseUp(point):
            defer { down = nil; dragged = false }
            guard let start = down else { return [] }
            if dragged || clickCount >= 2 || shiftClick {
                return [.check(.mouse(down: start, up: point), delay: Self.mouseDelay)]
            }
            return []
        case .shiftNavigationKeyUp:
            return [.check(.keyboard, delay: Self.keyboardDelay)]
        case .keyDown, .scroll:
            return [.dismiss]
        }
    }

    /// Whether a mouse gesture happened in a window's content area, not its
    /// title bar (window move) or edges (resize), where ⌘C would be a guess.
    /// `window` is in AppKit coordinates.
    public static func isContentGesture(down: CGPoint, up: CGPoint, window: CGRect, titleBand: CGFloat = 40, edge: CGFloat = 6) -> Bool {
        let content = CGRect(
            x: window.minX + edge, y: window.minY + edge,
            width: window.width - edge * 2, height: window.height - titleBand - edge
        )
        return content.width > 0 && content.height > 0 && content.contains(down) && content.contains(up)
    }
}
