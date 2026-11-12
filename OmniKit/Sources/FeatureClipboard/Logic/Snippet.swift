import Foundation
import OmniCore

/// A text snippet expanded when its abbreviation is typed.
public struct Snippet: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// Typed to trigger expansion, e.g. ";sig".
    public var abbreviation: String
    public var title: String
    /// Text with optional placeholders (see `PlaceholderExpander`).
    public var body: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), abbreviation: String, title: String, body: String, isEnabled: Bool = true) {
        self.id = id
        self.abbreviation = abbreviation
        self.title = title
        self.body = body
        self.isEnabled = isEnabled
    }

    /// Why `abbreviation` can't be used, or nil if it can.
    public static func problem(with abbreviation: String, among others: [Snippet], editing id: UUID?) -> String? {
        if abbreviation.count < 2 { return L10n.Snippets.tooShort }
        if abbreviation.contains(where: \.isWhitespace) { return L10n.Snippets.noSpaces }
        if others.contains(where: { $0.id != id && $0.abbreviation == abbreviation }) {
            return L10n.Snippets.alreadyUsed(abbreviation)
        }
        return nil
    }
}

/// The last few typed characters, matched against snippet abbreviations.
/// Contents are kept in memory only and never logged.
public struct KeystrokeBuffer: Sendable {
    public static let capacity = 64
    public private(set) var text = ""

    public init() {}

    public mutating func append(_ typed: String) {
        text += typed
        if text.count > Self.capacity { text = String(text.suffix(Self.capacity)) }
    }

    public mutating func backspace() {
        if !text.isEmpty { text.removeLast() }
    }

    public mutating func reset() {
        text = ""
    }

    /// The enabled snippet whose abbreviation the buffer ends with. The
    /// abbreviation must start at a word boundary (start of buffer or after
    /// a non-alphanumeric character), so "btw" doesn't fire inside "abtw".
    /// The longest matching abbreviation wins.
    public func match(in snippets: [Snippet]) -> Snippet? {
        snippets
            .filter { $0.isEnabled && !$0.abbreviation.isEmpty && text.hasSuffix($0.abbreviation) }
            .filter { snippet in
                let before = text.dropLast(snippet.abbreviation.count).last
                guard let before, let first = snippet.abbreviation.first else { return true }
                // Abbreviations that start with punctuation (";sig") match anywhere.
                return !(first.isLetter || first.isNumber) || !(before.isLetter || before.isNumber)
            }
            .max { $0.abbreviation.count < $1.abbreviation.count }
    }
}

/// Fills placeholders in a snippet body:
///
/// - `{date}` / `{date:yyyy-MM-dd}`: current date (medium style, or the given format)
/// - `{time}` / `{time:HH:mm}`: current time (short style, or the given format)
/// - `{clipboard}`: current clipboard text
/// - `{cursor}`: where the caret ends up (first occurrence; the rest are removed)
/// - `{{` and `}}`: literal braces
///
/// Unknown placeholders are left as typed.
public enum PlaceholderExpander {
    public struct Expansion: Equatable, Sendable {
        public let text: String
        /// Characters between the caret and the end, or nil to leave it at the end.
        public let cursorOffsetFromEnd: Int?
    }

    public static func expand(
        _ body: String, now: Date, clipboard: String?, locale: Locale = .current, timeZone: TimeZone = .current
    ) -> Expansion {
        var output = ""
        var cursorIndex: Int?
        var outputCount = 0
        var rest = Substring(body)

        func emit(_ string: String) {
            output += string
            outputCount += string.count
        }

        while let open = rest.firstIndex(where: { $0 == "{" || $0 == "}" }) {
            emit(String(rest[..<open]))
            let after = rest.index(after: open)
            if rest[open] == "}" {
                // "}}" → "}"; a lone "}" stays.
                emit("}")
                rest = (after < rest.endIndex && rest[after] == "}") ? rest[rest.index(after: after)...] : rest[after...]
                continue
            }
            if after < rest.endIndex, rest[after] == "{" {
                emit("{")
                rest = rest[rest.index(after: after)...]
                continue
            }
            guard let close = rest[after...].firstIndex(of: "}") else {
                emit(String(rest[open...]))
                rest = rest[rest.endIndex...]
                break
            }
            let token = String(rest[after..<close])
            if token == "cursor" {
                if cursorIndex == nil { cursorIndex = outputCount }
            } else if let value = value(for: token, now: now, clipboard: clipboard, locale: locale, timeZone: timeZone) {
                emit(value)
            } else {
                emit("{\(token)}")
            }
            rest = rest[rest.index(after: close)...]
        }
        emit(String(rest))
        return Expansion(text: output, cursorOffsetFromEnd: cursorIndex.map { outputCount - $0 })
    }

    private static func value(for token: String, now: Date, clipboard: String?, locale: Locale, timeZone: TimeZone) -> String? {
        let parts = token.split(separator: ":", maxSplits: 1).map(String.init)
        guard let name = parts.first else { return nil }
        let format = parts.count > 1 ? parts[1] : nil
        switch name {
        case "clipboard":
            return clipboard ?? ""
        case "date", "time":
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            if let format {
                formatter.dateFormat = format
            } else if name == "date" {
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
            } else {
                formatter.dateStyle = .none
                formatter.timeStyle = .short
            }
            return formatter.string(from: now)
        default:
            return nil
        }
    }
}
