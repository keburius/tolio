import Foundation
@testable import FeaturePalette
import Testing

struct CalculatorTests {
    private func value(_ input: String) -> Double? {
        if case let .success(evaluation) = Calculator.evaluate(input) { return evaluation.value }
        return nil
    }

    @Test(arguments: [
        ("1 + 2 * 3", 7.0), ("(1 + 2) * 3", 9), ("10 / 4", 2.5), ("2 ^ 10", 1024),
        ("2 ^ 3 ^ 2", 512), ("-2 ^ 2", -4), ("2 ^ -1", 0.5), ("--3", 3), ("-(2 + 3)", -5),
        ("50%", 0.5), ("200 * 15%", 30), ("10 mod 3", 1), ("2 ** 3", 8), ("6 × 7", 42), ("9 ÷ 3", 3),
        ("3 − 1", 2), ("sqrt(16)", 4), ("abs(-3)", 3), ("max(1, 5, 3)", 5), ("min(4, 2)", 2),
        ("round(2.5)", 3), ("floor(2.7)", 2), ("log(1000)", 3), ("ln(e)", 1), ("2pi", .nan),
        ("1.5e3", 1500), (".5 + .5", 1), ("pi", .pi),
    ])
    func evaluates(input: String, expected: Double) {
        let result = value(input)
        if expected.isNaN {
            #expect(result == nil, "\(input) should fail")
        } else {
            #expect(result.map { abs($0 - expected) < 1e-9 } == true, "\(input) = \(String(describing: result))")
        }
    }

    @Test(arguments: ["", "1 +", "(1 + 2", "1 + 2)", "1,000", "foo(2)", "sqrt(1, 2)", "2 $ 3", "hello"])
    func rejectsInvalid(input: String) {
        #expect(value(input) == nil, "\(input)")
    }

    @Test func divisionByZeroIsAnError() {
        #expect(Calculator.evaluate("1 / 0") == .failure(.notFinite))
    }

    @Test func bareNumberHasNoOperation() throws {
        let evaluation = try Calculator.evaluate("42").get()
        #expect(!evaluation.hasOperation)
        #expect(try Calculator.evaluate("sqrt(4)").get().hasOperation)
    }

    @Test func unknownNamesAreReported() {
        #expect(Calculator.evaluate("2 * zeta") == .failure(.unknownName("zeta")))
    }

    @Test(arguments: [
        (4.0, "4"), (-0.0, "0"), (2.5, "2.5"), (1.0 / 3.0, "0.333333333333"), (1e20, "1e+20"), (-12.75, "-12.75"),
    ])
    func formats(value: Double, expected: String) {
        #expect(Calculator.format(value) == expected)
    }
}
