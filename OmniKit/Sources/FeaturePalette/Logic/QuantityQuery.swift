import Foundation

/// "5 km in mi", "$20 to eur", "72°F": an amount, a source unit, and an optional target.
struct QuantityQuery: Equatable {
    let amount: Double
    let from: String
    let to: String?

    private static let separators = [" in ", " to ", " as ", " = ", " -> ", " → "]
    private static let prefixSymbols: Set<Character> = ["$", "€", "£", "¥", "₾"]
    /// Non-letter characters a unit may start with (°F, 5", 6', $).
    private static let unitLeadCharacters: Set<Character> = ["°", "\"", "'", "$", "€", "£", "¥", "₾"]

    /// Units are lowercased and trimmed. Returns nil if the text doesn't start
    /// with a number (optionally after a currency symbol) followed by a unit.
    static func parse(_ text: String) -> QuantityQuery? {
        let lower = " " + text.lowercased().trimmingCharacters(in: .whitespaces) + " "
        var left = lower, right: String?
        for separator in separators {
            if let range = lower.range(of: separator, options: .backwards), range.lowerBound > lower.startIndex {
                left = String(lower[..<range.lowerBound])
                right = String(lower[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        left = left.trimmingCharacters(in: .whitespaces)
        if let target = right, target.isEmpty { right = nil }

        var symbol: Character?
        if let first = left.first, prefixSymbols.contains(first) {
            symbol = first
            left.removeFirst()
            left = left.trimmingCharacters(in: .whitespaces)
        }
        let numberEnd = left.firstIndex { !($0.isNumber || $0 == "." || $0 == "-") } ?? left.endIndex
        guard numberEnd > left.startIndex, let amount = Double(left[..<numberEnd]) else { return nil }
        var unit = String(left[numberEnd...]).trimmingCharacters(in: .whitespaces)
        if let symbol {
            guard unit.isEmpty else { return nil }
            unit = String(symbol)
        }
        guard let first = unit.first, first.isLetter || unitLeadCharacters.contains(first) else { return nil }
        return QuantityQuery(amount: amount, from: unit, to: right)
    }
}
