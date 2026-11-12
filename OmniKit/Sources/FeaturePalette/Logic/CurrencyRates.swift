import Foundation

/// Exchange rates against the euro, as published by the European Central Bank.
public struct CurrencyRates: Codable, Equatable, Sendable {
    /// The ECB publication date, e.g. "2026-11-11".
    public let date: String
    public let fetchedAt: Date
    /// Units of each currency per 1 EUR. Always includes "EUR": 1.
    public let rates: [String: Double]

    public init(date: String, fetchedAt: Date, rates: [String: Double]) {
        self.date = date
        self.fetchedAt = fetchedAt
        var all = rates
        all["EUR"] = 1
        self.rates = all
    }

    public func convert(_ amount: Double, from: String, to: String) -> Double? {
        guard let source = rates[from.uppercased()], let target = rates[to.uppercased()], source > 0 else { return nil }
        return amount / source * target
    }

    public func supports(_ code: String) -> Bool { rates[code.uppercased()] != nil }
}

/// Parses the ECB daily reference rate XML (`eurofxref-daily.xml`).
public enum ECBRateParser {
    public enum Failure: Error { case malformed }

    public static func parse(_ data: Data, fetchedAt: Date) throws -> CurrencyRates {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), let date = delegate.date, !delegate.rates.isEmpty else { throw Failure.malformed }
        return CurrencyRates(date: date, fetchedAt: fetchedAt, rates: delegate.rates)
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var date: String?
        var rates: [String: Double] = [:]

        func parser(
            _ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String] = [:]
        ) {
            guard element == "Cube" else { return }
            if let time = attributes["time"] { date = time }
            if let code = attributes["currency"], let rate = attributes["rate"].flatMap(Double.init), rate > 0 {
                rates[code.uppercased()] = rate
            }
        }
    }
}

/// Maps what people type to ISO currency codes.
enum CurrencyNames {
    static let symbols: [String: String] = ["$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY", "₾": "GEL"]
    static let words: [String: String] = [
        "dollar": "USD", "dollars": "USD", "euro": "EUR", "euros": "EUR", "yen": "JPY",
        "lari": "GEL", "franc": "CHF", "francs": "CHF",
    ]

    /// An uppercase 3-letter code, or nil if `text` isn't a currency.
    static func code(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let code = symbols[trimmed] ?? words[trimmed.lowercased()] { return code }
        if trimmed.count == 3, trimmed.allSatisfy(\.isLetter) { return trimmed.uppercased() }
        return nil
    }
}
