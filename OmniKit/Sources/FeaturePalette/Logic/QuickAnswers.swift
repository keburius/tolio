import Foundation
import OmniCore

/// An instant result computed from the query: arithmetic, units, or currency.
public struct QuickAnswer: Equatable, Sendable {
    public enum Kind: String, Sendable { case calculation, unit, currency }

    public let kind: Kind
    /// Shown large, e.g. "8.05 mi".
    public let title: String
    /// Context, e.g. "5 km =" or "ECB rate of 2026-11-11".
    public let subtitle: String
    /// What Return copies (number only, no unit).
    public let copyText: String
}

/// Turns a query into quick answers. Pure: rates and defaults are injected.
public struct QuickAnswerEngine: Sendable {
    /// Rate tables in order of preference (ECB first, then NBG). The first
    /// table that has both currencies is used, so GEL pairs use NBG's own rates.
    public var rateTables: [CurrencyRates]
    /// Target when the user types only "100 usd".
    public var defaultCurrency: String
    /// Whether rate fetching is on (changes the "no rates" message).
    public var currencyFetchEnabled: Bool

    public init(rateTables: [CurrencyRates], defaultCurrency: String, currencyFetchEnabled: Bool = true) {
        self.rateTables = rateTables
        self.defaultCurrency = defaultCurrency.uppercased()
        self.currencyFetchEnabled = currencyFetchEnabled
    }

    public func answers(for query: String) -> [QuickAnswer] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains(where: \.isNumber) else { return [] }
        if let quantity = QuantityQuery.parse(trimmed) {
            if let answer = currency(quantity) ?? unit(quantity) { return [answer] }
        }
        if case let .success(evaluation) = Calculator.evaluate(trimmed), evaluation.hasOperation {
            let text = Calculator.format(evaluation.value)
            return [QuickAnswer(kind: .calculation, title: text, subtitle: "\(trimmed) =", copyText: text)]
        }
        return []
    }

    private func unit(_ q: QuantityQuery) -> QuickAnswer? {
        guard let target = q.to ?? UnitConversion.defaultTarget(for: q.from),
              let result = UnitConversion.convert(q.amount, from: q.from, to: target) else { return nil }
        let value = Calculator.format(Self.round(result.value))
        return QuickAnswer(
            kind: .unit, title: "\(value) \(result.toSymbol)",
            subtitle: "\(Calculator.format(q.amount)) \(result.fromSymbol) =", copyText: value
        )
    }

    private func currency(_ q: QuantityQuery) -> QuickAnswer? {
        guard let from = CurrencyNames.code(for: q.from) else { return nil }
        let to: String
        if let target = q.to {
            guard let code = CurrencyNames.code(for: target) else { return nil }
            to = code
        } else {
            to = from == defaultCurrency ? (from == "USD" ? "EUR" : "USD") : defaultCurrency
        }
        guard !rateTables.isEmpty else {
            // Only claim it's a currency query if the source looks like a real code.
            guard Self.isKnown(from) else { return nil }
            let hint = currencyFetchEnabled ? L10n.Launcher.ratesNotDownloaded : L10n.Launcher.turnOnRates
            return QuickAnswer(kind: .currency, title: L10n.Launcher.noRates, subtitle: hint, copyText: "")
        }
        guard let table = rateTables.first(where: { $0.supports(from) && $0.supports(to) }),
              let value = table.convert(q.amount, from: from, to: to) else {
            let missing = rateTables.contains { $0.supports(from) } ? to : from
            guard Self.isKnown(missing) else { return nil }
            let reason = missing == "GEL" ? L10n.Launcher.gelRatesFailed : L10n.Launcher.noPublisher(missing)
            return QuickAnswer(kind: .currency, title: L10n.Launcher.rateMissing(missing), subtitle: reason, copyText: "")
        }
        let text = String(format: "%.2f", value)
        return QuickAnswer(
            kind: .currency, title: "\(text) \(to)",
            subtitle: L10n.Launcher.currencySubtitle(
                amount: Calculator.format(q.amount), from: from, source: table.source, date: table.date
            ),
            copyText: text
        )
    }

    private static func isKnown(_ code: String) -> Bool {
        knownCodes.contains(code) || CurrencyNames.symbols.values.contains(code)
    }

    /// 6 significant digits so conversions don't show float noise.
    static func round(_ value: Double) -> Double {
        guard value != 0 else { return 0 }
        let digits = max(0, 5 - Int(floor(log10(abs(value)))))
        let factor = pow(10, Double(min(digits, 12)))
        return (value * factor).rounded() / factor
    }

    /// ISO codes worth recognizing even when no rate exists (to explain why).
    static let knownCodes: Set<String> = Set(Locale.commonISOCurrencyCodes)
}
