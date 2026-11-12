import Foundation

/// Pure helpers behind the built-in actions.
public enum TextAnalysis {
    public struct Counts: Equatable, Sendable {
        public var words: Int
        public var characters: Int
        public var lines: Int
    }

    /// Words as macOS counts them (by word boundaries, any language),
    /// characters as user-perceived characters, and lines.
    public static func counts(_ text: String) -> Counts {
        var words = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            words += 1
        }
        let trimmed = text.trimmingCharacters(in: .newlines)
        let lines = trimmed.isEmpty ? 0 : trimmed.components(separatedBy: .newlines).count
        return Counts(words: words, characters: text.count, lines: lines)
    }

    /// A web URL if the whole selection is one: "https://…", "www.…", or a
    /// bare domain like "example.com/path". Other schemes (file:, javascript:,
    /// custom app schemes) are not opened.
    public static func webURL(in text: String) -> URL? {
        let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "<>\"'()[]")))
        guard !candidate.isEmpty, candidate.count <= 2048,
              candidate.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(candidate.startIndex..., in: candidate)
        guard let match = detector.firstMatch(in: candidate, options: [], range: range),
              match.range == range, var url = match.url else { return nil }
        // An email address is a link (mailto:) but not a web page.
        guard let scheme = url.scheme?.lowercased() else { return nil }
        if scheme == "http" && !candidate.lowercased().hasPrefix("http") {
            // Bare domain: the detector assumes http; prefer https.
            url = URL(string: "https://" + candidate) ?? url
        }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host?.contains(".") == true else { return nil }
        return url
    }

    public static func uppercased(_ text: String) -> String { text.uppercased(with: .current) }
    public static func lowercased(_ text: String) -> String { text.lowercased(with: .current) }
}

/// Where "Search the Web" goes. The browser does the request, after a click.
public enum SearchEngine: String, Codable, CaseIterable, Sendable {
    case google, duckDuckGo, bing, kagi

    public var label: String {
        switch self {
        case .google: "Google"
        case .duckDuckGo: "DuckDuckGo"
        case .bing: "Bing"
        case .kagi: "Kagi"
        }
    }

    private var base: String {
        switch self {
        case .google: "https://www.google.com/search"
        case .duckDuckGo: "https://duckduckgo.com/"
        case .bing: "https://www.bing.com/search"
        case .kagi: "https://kagi.com/search"
        }
    }

    /// Long selections are cut to keep the URL reasonable.
    public static let maxQueryLength = 500

    public func url(for query: String) -> URL? {
        let text = String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxQueryLength))
        guard !text.isEmpty, var components = URLComponents(string: base) else { return nil }
        components.queryItems = [URLQueryItem(name: "q", value: text)]
        return components.url
    }
}
