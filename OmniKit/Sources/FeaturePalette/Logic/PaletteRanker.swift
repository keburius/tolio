import Foundation

/// Orders palette items for a query.
public enum PaletteRanker {
    /// Keyword matches count a bit less than title matches.
    static let keywordWeight = 0.8

    public static func rank(
        _ items: [PaletteItem], query: String, usage: UsageHistory, now: Date, limit: Int = 50
    ) -> [PaletteItem] {
        let prepared = FuzzyMatcher.prepareQuery(query)
        guard !prepared.isEmpty else { return recent(items, usage: usage, now: now) }

        var scored: [(item: PaletteItem, score: Double)] = []
        for var item in items {
            guard let (score, highlight) = bestMatch(prepared, item) else { continue }
            item.highlighted = highlight
            scored.append((item, score + usage.boost(for: item.id, at: now)))
        }
        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.item.title.count != rhs.item.title.count { return lhs.item.title.count < rhs.item.title.count }
                return lhs.item.title < rhs.item.title
            }
            .prefix(limit)
            .map(\.item)
    }

    /// Recently used items, most relevant first.
    static func recent(_ items: [PaletteItem], usage: UsageHistory, now: Date, limit: Int = 8) -> [PaletteItem] {
        items.map { ($0, usage.boost(for: $0.id, at: now)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    private static func bestMatch(_ query: [Character], _ item: PaletteItem) -> (Double, [Int])? {
        var best: (Double, [Int])?
        for (offset, target) in item.targets.enumerated() {
            guard let match = FuzzyMatcher.match(query, in: target) else { continue }
            // A keyword never gets the exact-match bonus, so titles win ties.
            let keywordScore = (match.score - (match.isExact ? FuzzyMatcher.exactBonus : 0)) * keywordWeight
            let score = offset == 0 ? match.score : keywordScore
            if score > (best?.0 ?? -.infinity) {
                best = (score, offset == 0 ? match.matchedIndices : [])
            }
        }
        return best
    }
}
