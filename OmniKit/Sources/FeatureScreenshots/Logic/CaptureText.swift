import Foundation

/// How recognized lines become clipboard text.
public enum LineBreakMode: String, Codable, CaseIterable, Sendable {
    /// One line per recognized line.
    case keep
    /// Everything joined into one paragraph.
    case join
}

/// Turns recognition results into what Capture Text copies, including
/// append mode. Pure, so the rules are tested.
public struct CaptureTextComposer: Sendable {
    /// What a capture should do.
    public enum Outcome: Equatable, Sendable {
        /// Nothing recognized: show "No text found", leave the clipboard alone.
        case empty
        /// Copy `text`. `added` is the new part (its length goes in the notice).
        case text(String, added: String, appended: Bool)
        /// QR code or barcode contents; `link` if it's a web address.
        case code(String, link: URL?)
    }

    /// The last captured text (kept in memory for append mode).
    public private(set) var lastCapture: String?

    public init(lastCapture: String? = nil) {
        self.lastCapture = lastCapture
    }

    /// Lines → text. Keep: one per line. Join: one paragraph. Both trim
    /// lines, drop blank ones and collapse runs of spaces.
    public static func format(_ lines: [String], mode: LineBreakMode) -> String {
        let cleaned = lines
            .map { $0.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.joined(separator: mode == .keep ? "\n" : " ")
    }

    /// Decides the outcome and remembers the capture. Codes win over text:
    /// a selection with a QR code is almost always about the code.
    public mutating func compose(lines: [String], codes: [String], mode: LineBreakMode, append: Bool) -> Outcome {
        let payloads = codes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !payloads.isEmpty {
            let text = payloads.joined(separator: "\n")
            lastCapture = text
            return .code(text, link: payloads.count == 1 ? Self.webLink(payloads[0]) : nil)
        }
        let new = Self.format(lines, mode: mode)
        guard !new.isEmpty else { return .empty }
        if append, let previous = lastCapture, !previous.isEmpty {
            let combined = previous + (mode == .keep ? "\n" : " ") + new
            lastCapture = combined
            return .text(combined, added: new, appended: true)
        }
        lastCapture = new
        return .text(new, added: new, appended: false)
    }

    /// An http(s) URL with a host, nothing else.
    static func webLink(_ text: String) -> URL? {
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https", url.host?.isEmpty == false else { return nil }
        return url
    }
}
