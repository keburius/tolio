import Foundation
@testable import FeaturePalette
import Testing

struct QuantityQueryTests {
    @Test(arguments: [
        ("5 km in mi", QuantityQuery(amount: 5, from: "km", to: "mi")),
        ("5km to miles", QuantityQuery(amount: 5, from: "km", to: "miles")),
        ("72 F as C", QuantityQuery(amount: 72, from: "f", to: "c")),
        ("$20 to eur", QuantityQuery(amount: 20, from: "$", to: "eur")),
        ("100 usd", QuantityQuery(amount: 100, from: "usd", to: nil)),
        ("-40 c in f", QuantityQuery(amount: -40, from: "c", to: "f")),
        ("2.5 fl oz in ml", QuantityQuery(amount: 2.5, from: "fl oz", to: "ml")),
    ])
    func parses(text: String, expected: QuantityQuery) {
        #expect(QuantityQuery.parse(text) == expected)
    }

    @Test(arguments: ["km in mi", "5", "1 + 2", "$ 5 usd", ""])
    func rejects(text: String) {
        #expect(QuantityQuery.parse(text) == nil)
    }
}

struct UnitConversionTests {
    private func convert(_ amount: Double, _ from: String, _ to: String) -> Double? {
        UnitConversion.convert(amount, from: from, to: to)?.value
    }

    @Test func convertsAcrossCategories() throws {
        #expect(abs(try #require(convert(5, "km", "mi")) - 3.10686) < 0.0001)
        #expect(abs(try #require(convert(1, "lb", "kg")) - 0.453592) < 0.0001)
        #expect(abs(try #require(convert(100, "c", "f")) - 212) < 0.0001)
        #expect(abs(try #require(convert(-40, "f", "c")) + 40) < 0.0001)
        #expect(abs(try #require(convert(1, "gb", "mb")) - 1000) < 0.0001)
        #expect(abs(try #require(convert(1, "gib", "mib")) - 1024) < 0.0001)
        #expect(abs(try #require(convert(2, "days", "hours")) - 48) < 0.0001)
        #expect(abs(try #require(convert(1, "mph", "km/h")) - 1.609344) < 0.0001)
    }

    @Test func acceptsPluralsAndLongNames() {
        #expect(convert(3, "meters", "feet") != nil)
        #expect(convert(3, "kilograms", "pounds") != nil)
    }

    @Test func rejectsMismatchedOrUnknownUnits() {
        #expect(convert(5, "km", "kg") == nil)
        #expect(convert(5, "km", "parsecs") == nil)
    }

    @Test func defaultCounterparts() {
        #expect(UnitConversion.defaultTarget(for: "km") == "mi")
        #expect(UnitConversion.defaultTarget(for: "celsius") == "°F")
        #expect(UnitConversion.defaultTarget(for: "parsec") == nil)
    }
}

struct CurrencyTests {
    static let fixture = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <gesmes:Envelope xmlns:gesmes="http://www.gesmes.org/xml/2002-08-01" xmlns="http://www.ecb.int/vocabulary/2002-08-01/eurofxref">
      <gesmes:subject>Reference rates</gesmes:subject>
      <Cube>
        <Cube time="2026-11-11">
          <Cube currency="USD" rate="1.1000"/>
          <Cube currency="JPY" rate="165.00"/>
          <Cube currency="GBP" rate="0.8500"/>
        </Cube>
      </Cube>
    </gesmes:Envelope>
    """.utf8)

    /// Trimmed copy of a real NBG response (2026-11-12): GEL per `quantity` units.
    static let nbgFixture = Data("""
    [{"date":"2026-11-12T00:00:00.000Z","currencies":[
      {"code":"AMD","quantity":1000,"rateFormated":"7.1944","diffFormated":"0.0005","rate":7.1944,"name":"Armenian Dram","diff":-0.0005,"date":"2026-11-11T17:01:12.692Z","validFromDate":"2026-11-12T00:00:00.000Z"},
      {"code":"EUR","quantity":1,"rateFormated":"3.0000","diffFormated":"0.0010","rate":3.0,"name":"Euro","diff":0.001,"date":"2026-11-11T17:01:12.692Z","validFromDate":"2026-11-12T00:00:00.000Z"},
      {"code":"USD","quantity":1,"rateFormated":"2.7000","diffFormated":"0.0010","rate":2.7,"name":"US Dollar","diff":0.001,"date":"2026-11-11T17:01:12.692Z","validFromDate":"2026-11-12T00:00:00.000Z"}
    ]}]
    """.utf8)

    @Test func parsesNBGDocumentIntoEuroBase() throws {
        let rates = try NBGRateParser.parse(Self.nbgFixture, fetchedAt: Date())
        #expect(rates.source == "NBG")
        #expect(rates.date == "2026-11-12")
        #expect(rates.rates["GEL"] == 3)
        #expect(abs(try #require(rates.convert(1, from: "USD", to: "GEL")) - 2.7) < 1e-9)
        #expect(abs(try #require(rates.convert(1000, from: "AMD", to: "GEL")) - 7.1944) < 1e-9)
    }

    @Test func nbgWithoutEuroIsRejected() {
        let data = Data(#"[{"date":"2026-11-12","currencies":[{"code":"USD","quantity":1,"rate":2.7}]}]"#.utf8)
        #expect(throws: NBGRateParser.Failure.missingEuro) { try NBGRateParser.parse(data, fetchedAt: Date()) }
        #expect(throws: (any Error).self) { try NBGRateParser.parse(Data("{}".utf8), fetchedAt: Date()) }
    }

    @Test func oldCacheWithoutSourceDecodesAsECB() throws {
        let json = Data(#"{"date":"2026-11-11","fetchedAt":0,"rates":{"USD":1.1,"EUR":1}}"#.utf8)
        #expect(try JSONDecoder().decode(CurrencyRates.self, from: json).source == "ECB")
    }

    @Test func parsesECBDocument() throws {
        let rates = try ECBRateParser.parse(Self.fixture, fetchedAt: Date(timeIntervalSince1970: 0))
        #expect(rates.date == "2026-11-11")
        #expect(rates.rates == ["USD": 1.1, "JPY": 165, "GBP": 0.85, "EUR": 1])
    }

    @Test func rejectsMalformedDocument() {
        #expect(throws: (any Error).self) { try ECBRateParser.parse(Data("<html/>".utf8), fetchedAt: Date()) }
    }

    @Test func crossRatesGoThroughEuro() throws {
        let rates = try ECBRateParser.parse(Self.fixture, fetchedAt: Date())
        #expect(abs(try #require(rates.convert(110, from: "usd", to: "EUR")) - 100) < 1e-9)
        #expect(abs(try #require(rates.convert(1.1, from: "USD", to: "GBP")) - 0.85) < 1e-9)
        #expect(rates.convert(1, from: "USD", to: "XYZ") == nil)
    }

    @Test func currencyNames() {
        #expect(CurrencyNames.code(for: "$") == "USD")
        #expect(CurrencyNames.code(for: "euros") == "EUR")
        #expect(CurrencyNames.code(for: "gbp") == "GBP")
        #expect(CurrencyNames.code(for: "km") == nil)
    }
}
