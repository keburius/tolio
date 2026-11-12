/// A string prepared once for repeated fuzzy matching (folded characters and
/// per-position bonuses are precomputed).
public struct FuzzyTarget: Sendable {
    public let text: String
    let folded: [Character]
    let bonus: [Double]

    public init(_ text: String) {
        self.text = text
        let chars = Array(text)
        folded = chars.map(FuzzyMatcher.fold)
        bonus = chars.indices.map { FuzzyMatcher.boundaryBonus(chars, $0) }
    }
}

/// Result of matching a query against a target.
public struct FuzzyMatch: Sendable, Equatable {
    public let score: Double
    /// Character offsets in the target that matched, for highlighting.
    public let matchedIndices: [Int]
    /// The query matched the whole target.
    public let isExact: Bool
}

/// Subsequence matcher that prefers prefixes, word starts (incl. camelCase
/// and acronyms), and consecutive runs, and penalizes gaps.
public enum FuzzyMatcher {
    static let prefixBonus = 8.0
    static let wordStartBonus = 6.0
    static let camelBonus = 5.0
    static let consecutiveBonus = 5.0
    static let gapPenalty = 0.3
    static let leadingPenalty = 0.15
    static let exactBonus = 20.0

    /// Lowercased, diacritics removed, whitespace dropped.
    public static func prepareQuery(_ query: String) -> [Character] {
        query.filter { !$0.isWhitespace }.map(fold)
    }

    public static func match(_ query: String, in target: String) -> FuzzyMatch? {
        match(prepareQuery(query), in: FuzzyTarget(target))
    }

    public static func match(_ query: [Character], in target: FuzzyTarget) -> FuzzyMatch? {
        let c = target.folded
        let n = c.count, m = query.count
        guard m > 0, m <= n else { return nil }
        let none = -Double.infinity

        // prev[j]: best score with query[i-1] matched at c[j].
        var prev = [Double](repeating: none, count: n)
        var back = [[Int]](repeating: [Int](repeating: -1, count: n), count: m)
        for j in 0..<n where c[j] == query[0] {
            prev[j] = 1 + target.bonus[j] - leadingPenalty * Double(min(j, 20))
        }
        for i in 1..<m {
            var cur = [Double](repeating: none, count: n)
            var gapBest = none, gapIndex = -1 // max over k <= j-2 of prev[k] - gap*(j-1-k)
            for j in i..<n {
                if j >= 2 {
                    gapBest -= gapPenalty
                    let candidate = prev[j - 2] - gapPenalty
                    if candidate > gapBest { gapBest = candidate; gapIndex = j - 2 }
                }
                guard c[j] == query[i] else { continue }
                let run = prev[j - 1] == none ? none : prev[j - 1] + consecutiveBonus
                let (best, from) = run >= gapBest ? (run, j - 1) : (gapBest, gapIndex)
                guard best > none else { continue }
                cur[j] = best + 1 + target.bonus[j]
                back[i][j] = from
            }
            prev = cur
        }
        guard let end = prev.indices.max(by: { prev[$0] < prev[$1] }), prev[end] > none else { return nil }

        var indices = [end]
        var j = end
        for i in stride(from: m - 1, to: 0, by: -1) {
            j = back[i][j]
            indices.append(j)
        }
        var score = prev[end] - 0.02 * Double(n - m)
        if m == n { score += exactBonus }
        return FuzzyMatch(score: score, matchedIndices: indices.reversed(), isExact: m == n)
    }

    static func fold(_ ch: Character) -> Character {
        String(ch).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).first ?? ch
    }

    static func boundaryBonus(_ chars: [Character], _ j: Int) -> Double {
        guard j > 0 else { return prefixBonus }
        let previous = chars[j - 1], current = chars[j]
        if previous.isWhitespace || "-_./()&+:".contains(previous) { return wordStartBonus }
        if previous.isLowercase && current.isUppercase { return camelBonus }
        if previous.isLetter != current.isLetter && (previous.isNumber || current.isNumber) { return 2 }
        return 0
    }
}
