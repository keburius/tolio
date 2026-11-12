import Foundation

/// A place in Settings a search result opens.
public enum SettingsPage: Hashable, Sendable {
    case overview, menuBar, shortcuts, permissions, general
    case feature(FeatureID)
}

/// Searches every setting label, its synonyms, feature names, and page names.
public struct SettingsIndex: Sendable {
    public struct Item: Hashable, Sendable, Identifiable {
        public let page: SettingsPage
        /// "Page › Setting" shown in results.
        public let pageTitle: String
        public let label: String
        public let keywords: [String]
        public let anchor: String?

        public var id: String { "\(page)|\(anchor ?? "")|\(label)" }

        public init(page: SettingsPage, pageTitle: String, label: String, keywords: [String] = [], anchor: String? = nil) {
            self.page = page
            self.pageTitle = pageTitle
            self.label = label
            self.keywords = keywords
            self.anchor = anchor
        }
    }

    public let items: [Item]

    public init(items: [Item]) {
        var seen = Set<String>()
        self.items = items.filter { seen.insert($0.id).inserted }
    }

    /// Best matches first: label starts with the query, a word in the label
    /// starts with it, the label contains it, a keyword matches, the page matches.
    public func search(_ query: String, limit: Int = 30) -> [Item] {
        let needle = Self.fold(query)
        guard !needle.isEmpty else { return [] }
        let scored: [(Item, Int, Int)] = items.enumerated().compactMap { offset, item in
            let label = Self.fold(item.label)
            let score: Int
            if label.hasPrefix(needle) { score = 0 }
            else if label.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(where: { $0.hasPrefix(needle) }) { score = 1 }
            else if label.contains(needle) { score = 2 }
            else if item.keywords.contains(where: { Self.fold($0).hasPrefix(needle) || Self.fold($0).contains(needle) }) { score = 3 }
            else if Self.fold(item.pageTitle).contains(needle) { score = 4 }
            else { return nil }
            return (item, score, offset)
        }
        return scored.sorted { ($0.1, $0.2) < ($1.1, $1.2) }.prefix(limit).map(\.0)
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
