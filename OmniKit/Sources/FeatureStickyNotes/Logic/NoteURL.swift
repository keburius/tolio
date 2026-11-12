import CoreGraphics
import Foundation

/// `omni://note/new?x=…&y=…`, sent by Omni's Finder extension from the
/// desktop's right-click menu. Only this fixed action exists; a link can't
/// write text into a note.
public enum NoteURL {
    public static let host = "note"

    /// The requested top-left point (AppKit global coordinates), or nil for "near the pointer".
    public static func newNotePoint(_ url: URL) -> CGPoint?? {
        guard url.scheme == "omni", url.host == host, url.path == "/new" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func number(_ name: String) -> CGFloat? {
            guard let raw = items.first(where: { $0.name == name })?.value, let value = Double(raw), value.isFinite,
                  abs(value) < 100_000 else { return nil }
            return CGFloat(value)
        }
        if let x = number("x"), let y = number("y") { return .some(CGPoint(x: x, y: y)) }
        return .some(nil)
    }

    public static func make(at point: CGPoint) -> URL {
        URL(string: "omni://note/new?x=\(Int(point.x))&y=\(Int(point.y))")!
    }
}
