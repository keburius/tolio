import CoreGraphics
import Foundation

/// A note's tint over the glass.
public enum NoteTint: String, Codable, CaseIterable, Sendable {
    case yellow, orange, pink, purple, blue, green, gray
}

/// One sticky note. Frames are AppKit global points.
public struct StickyNote: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var frame: CGRect
    public var tint: NoteTint
    /// Floats above app windows instead of sitting on the desktop.
    public var keepOnTop: Bool
    public var created: Date
    public var modified: Date

    public static let defaultSize = CGSize(width: 260, height: 220)
    public static let minimumSize = CGSize(width: 160, height: 120)

    public init(id: UUID = UUID(), text: String = "", frame: CGRect, tint: NoteTint = .yellow, keepOnTop: Bool = false, now: Date = Date()) {
        self.id = id
        self.text = text
        self.frame = frame
        self.tint = tint
        self.keepOnTop = keepOnTop
        created = now
        modified = now
    }

    /// The first line, for menus ("Untitled note" when empty is decided by the UI).
    public var title: String {
        text.split(whereSeparator: \.isNewline).first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
    }
}

/// Where new notes go and how saved frames are brought back on screen.
public enum NotePlacement {
    /// A note whose top-left corner is at `point` (where you clicked), kept inside `visible`.
    public static func frame(at point: CGPoint, size: CGSize = StickyNote.defaultSize, in visible: CGRect) -> CGRect {
        clamp(CGRect(x: point.x, y: point.y - size.height, width: size.width, height: size.height), to: visible)
    }

    /// Moves (and if needed shrinks) a frame so it's fully inside `visible`.
    public static func clamp(_ frame: CGRect, to visible: CGRect) -> CGRect {
        var result = frame
        result.size.width = min(max(result.width, StickyNote.minimumSize.width), visible.width)
        result.size.height = min(max(result.height, StickyNote.minimumSize.height), visible.height)
        result.origin.x = min(max(result.minX, visible.minX), visible.maxX - result.width)
        result.origin.y = min(max(result.minY, visible.minY), visible.maxY - result.height)
        return result
    }

    /// A saved frame on the screen it overlaps most; if it's off every
    /// screen (display unplugged), on `fallback`.
    public static func restore(_ frame: CGRect, screens: [CGRect], fallback: CGRect) -> CGRect {
        let best = screens.max { overlap($0, frame) < overlap($1, frame) }
        guard let best, overlap(best, frame) > 0 else { return clamp(frame, to: fallback) }
        return clamp(frame, to: best)
    }

    /// Cascades a new note so it doesn't land exactly on another one.
    public static func cascade(_ frame: CGRect, avoiding others: [CGRect], in visible: CGRect, step: CGFloat = 24) -> CGRect {
        var candidate = frame
        var tries = 0
        while others.contains(where: { abs($0.minX - candidate.minX) < 4 && abs($0.maxY - candidate.maxY) < 4 }) && tries < 20 {
            candidate = clamp(candidate.offsetBy(dx: step, dy: -step), to: visible)
            tries += 1
        }
        return candidate
    }

    private static func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let i = a.intersection(b)
        return i.isNull ? 0 : i.width * i.height
    }
}
