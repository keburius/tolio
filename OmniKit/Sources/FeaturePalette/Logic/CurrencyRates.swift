import Foundation

/// Exchange rates from one publisher, normalized to units per 1 EUR.
public struct CurrencyRates: Codable, Equatable, Sendable {
    /// Short publisher name shown to the user, e.g. "ECB" or "NBG".
    public let source: String
    /// The publication date, e.g. "2026-11-11".
    public let date: String
    public let fetchedAt: Date
    /// Units of each currency per 1 EUR. Always includes "EUR": 1.
    public let rates: [String: Double]

    public init(source: String = "ECB", date: String, fetchedAt: Date, rates: [String: Double]) {
        self.source = source
        self.date = date
        self.fetchedAt = fetchedAt
        var all = rates
        all["EUR"] = 1
        self.rates = all
    }

    private enum CodingKeys: String, CodingKey { case source, date, fetchedAt, rates }

    /// Caches written before `source` existed were ECB caches.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "ECB"
        date = try container.decode(String.self, forKey: .date)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        rates = try container.decode([String: Double].self, forKey: .rates)
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
        return CurrencyRates(source: "ECB", date: date, fetchedAt: fetchedAt, rates: delegate.rates)
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

/// Parses the National Bank of Georgia official rates JSON
/// (`nbg.gov.ge/gw/api/ct/monetarypolicy/currencies/en/json`).
///
/// NBG publishes GEL per `quantity` units of each currency. Rates are
/// re-expressed per 1 EUR so they combine like ECB rates; GEL itself is added.
public enum NBGRateParser {
    public enum Failure: Error { case malformed, missingEuro }

    private struct Day: Decodable {
        let date: String
        let currencies: [Entry]
    }

    private struct Entry: Decodable {
        let code: String
        let quantity: Double
        let rate: Double
        let validFromDate: String?
    }

    public static func parse(_ data: Data, fetchedAt: Date) throws -> CurrencyRates {
        guard let day = try JSONDecoder().decode([Day].self, from: data).first else { throw Failure.malformed }
        var gelPer: [String: Double] = [:]
        for entry in day.currencies where entry.quantity > 0 && entry.rate > 0 {
            gelPer[entry.code.uppercased()] = entry.rate / entry.quantity
        }
        guard let gelPerEuro = gelPer["EUR"] else { throw Failure.missingEuro }
        var rates = gelPer.mapValues { gelPerEuro / $0 }
        rates["GEL"] = gelPerEuro
        let published = day.currencies.first?.validFromDate ?? day.date
        return CurrencyRates(source: "NBG", date: String(published.prefix(10)), fetchedAt: fetchedAt, rates: rates)
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
