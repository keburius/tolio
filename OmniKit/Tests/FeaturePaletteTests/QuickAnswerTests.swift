import Foundation
@testable import FeaturePalette
import Testing

struct QuickAnswerTests {
    private let rates = try! ECBRateParser.parse(CurrencyTests.fixture, fetchedAt: Date())
    private let nbg = try! NBGRateParser.parse(CurrencyTests.nbgFixture, fetchedAt: Date())

    private func engine(rates: CurrencyRates?, nbg: CurrencyRates? = nil, fetch: Bool = true) -> QuickAnswerEngine {
        QuickAnswerEngine(rateTables: [rates, nbg].compactMap { $0 }, defaultCurrency: "EUR", currencyFetchEnabled: fetch)
    }

    @Test func calculation() {
        let answers = engine(rates: rates).answers(for: "2 + 2 * 3")
        #expect(answers == [QuickAnswer(kind: .calculation, title: "8", subtitle: "2 + 2 * 3 =", copyText: "8")])
    }

    @Test func plainTextAndBareNumbersGiveNothing() {
        #expect(engine(rates: rates).answers(for: "safari").isEmpty)
        #expect(engine(rates: rates).answers(for: "1password").isEmpty)
        #expect(engine(rates: rates).answers(for: "42").isEmpty)
    }

    @Test func unitConversionWithAndWithoutTarget() {
        #expect(engine(rates: rates).answers(for: "5 km in mi").first?.title == "3.10686 mi")
        #expect(engine(rates: rates).answers(for: "100 c").first?.title == "212 °F")
    }

    @Test func currencyConversion() throws {
        let answer = try #require(engine(rates: rates).answers(for: "110 usd in eur").first)
        #expect(answer.kind == .currency)
        #expect(answer.title == "100.00 EUR")
        #expect(answer.copyText == "100.00")
        #expect(answer.subtitle.contains("ECB rate of 2026-11-11"))
    }

    @Test func currencyDefaultsToConfiguredTarget() {
        #expect(engine(rates: rates).answers(for: "$11").first?.title == "10.00 EUR")
        #expect(engine(rates: rates).answers(for: "10 eur").first?.title == "11.00 USD")
    }

    @Test func offlineWithoutCacheExplainsInsteadOfFailing() throws {
        let answer = try #require(engine(rates: nil).answers(for: "10 usd in eur").first)
        #expect(answer.title == "No exchange rates")
        #expect(answer.copyText.isEmpty)
        let disabled = try #require(engine(rates: nil, fetch: false).answers(for: "10 usd in eur").first)
        #expect(disabled.subtitle.contains("Settings"))
    }

    @Test func gelWithoutNBGRatesIsNotAvailable() throws {
        let answer = try #require(engine(rates: rates).answers(for: "10 usd in gel").first)
        #expect(answer.title == "GEL rate not available")
        #expect(answer.copyText.isEmpty)
        // Other currencies keep working.
        #expect(engine(rates: rates).answers(for: "110 usd in eur").first?.title == "100.00 EUR")
    }

    @Test func gelUsesNBGRatesDirectly() throws {
        let answer = try #require(engine(rates: rates, nbg: nbg).answers(for: "10 usd in gel").first)
        #expect(answer.title == "27.00 GEL") // NBG: 1 USD = 2.7 GEL
        #expect(answer.subtitle.contains("NBG rate of 2026-11-12"))
        #expect(engine(rates: rates, nbg: nbg).answers(for: "100 lari in eur").first?.title == "33.33 EUR")
        #expect(engine(rates: rates, nbg: nbg).answers(for: "₾30").first?.title == "10.00 EUR")
    }

    @Test func nonGELPairsPreferECB() throws {
        let answer = try #require(engine(rates: rates, nbg: nbg).answers(for: "110 usd in eur").first)
        #expect(answer.subtitle.contains("ECB"))
    }

    @Test func nbgOnlyWorksWhenECBMissing() throws {
        let answer = try #require(engine(rates: nil, nbg: nbg).answers(for: "1000 amd in gel").first)
        #expect(answer.title == "7.19 GEL")
    }

    @Test func currencyNobodyPublishesIsExplained() throws {
        let answer = try #require(engine(rates: rates, nbg: nbg).answers(for: "10 usd in vnd").first)
        #expect(answer.title == "VND rate not available")
    }

    @Test func massPoundsStayUnits() {
        #expect(engine(rates: rates).answers(for: "10 pounds in kg").first?.kind == .unit)
    }

    @Test func roundingRemovesFloatNoise() {
        #expect(QuickAnswerEngine.round(3.1068559611866697) == 3.10686)
        #expect(QuickAnswerEngine.round(0.000123456789) == 0.000123457)
    }
}
