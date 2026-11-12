import Foundation

/// Evaluates arithmetic typed into the palette.
///
/// Grammar (lowest to highest precedence):
///   expr    = term (("+" | "-") term)*
///   term    = unary (("*" | "/" | "mod") unary)*
///   unary   = ("-" | "+") unary | power
///   power   = postfix ("^" unary)?            right-associative
///   postfix = primary "%"*                    50% = 0.5
///   primary = number | constant | function "(" expr ("," expr)* ")" | "(" expr ")"
public enum Calculator {
    public enum Failure: Error, Equatable {
        case syntax
        case unknownName(String)
        case notFinite
    }

    /// The value and whether the input contained any operation, so that a
    /// bare number isn't shown as a "result".
    public struct Evaluation: Equatable, Sendable {
        public let value: Double
        public let hasOperation: Bool
    }

    public static func evaluate(_ input: String) -> Result<Evaluation, Failure> {
        do {
            var parser = Parser(tokens: try tokenize(input))
            let value = try parser.parseExpression()
            guard parser.isAtEnd else { throw Failure.syntax }
            guard value.isFinite else { throw Failure.notFinite }
            return .success(Evaluation(value: value == 0 ? 0 : value, hasOperation: parser.sawOperation))
        } catch let failure as Failure {
            return .failure(failure)
        } catch {
            return .failure(.syntax)
        }
    }

    /// Plain, copyable text: integers without decimals, otherwise up to 12 significant digits.
    public static func format(_ value: Double) -> String {
        if value.rounded() == value, abs(value) < 1e15 {
            return String(Int64(value))
        }
        var text = String(format: "%.12g", value)
        if text.contains("."), !text.contains("e") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text
    }

    // MARK: - Tokens

    enum Token: Equatable {
        case number(Double)
        case op(Character)
        case open, close, comma
        case name(String)
    }

    static func tokenize(_ input: String) throws -> [Token] {
        var tokens: [Token] = []
        let chars = Array(input)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace { i += 1; continue }
            if c.isNumber || (c == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
                let start = i
                while i < chars.count, chars[i].isNumber || chars[i] == "." { i += 1 }
                // Exponent only when followed by digits: "2e3" yes, "2e" no.
                if i < chars.count, chars[i] == "e" || chars[i] == "E" {
                    var k = i + 1
                    if k < chars.count, chars[k] == "+" || chars[k] == "-" { k += 1 }
                    if k < chars.count, chars[k].isNumber {
                        i = k
                        while i < chars.count, chars[i].isNumber { i += 1 }
                    }
                }
                guard let value = Double(String(chars[start..<i])) else { throw Failure.syntax }
                tokens.append(.number(value))
                continue
            }
            if c.isLetter || c == "π" {
                let start = i
                while i < chars.count, chars[i].isLetter || chars[i].isNumber || chars[i] == "π" { i += 1 }
                tokens.append(.name(String(chars[start..<i]).lowercased()))
                continue
            }
            switch c {
            case "+": tokens.append(.op("+"))
            case "-", "−": tokens.append(.op("-"))
            case "*", "×", "·":
                if c == "*", i + 1 < chars.count, chars[i + 1] == "*" { tokens.append(.op("^")); i += 1 } else { tokens.append(.op("*")) }
            case "/", "÷": tokens.append(.op("/"))
            case "^": tokens.append(.op("^"))
            case "%": tokens.append(.op("%"))
            case "(": tokens.append(.open)
            case ")": tokens.append(.close)
            case ",": tokens.append(.comma)
            default: throw Failure.syntax
            }
            i += 1
        }
        return tokens
    }

    // MARK: - Parser

    struct Parser {
        let tokens: [Token]
        var position = 0
        var sawOperation = false

        var isAtEnd: Bool { position == tokens.count }
        private var current: Token? { position < tokens.count ? tokens[position] : nil }

        mutating func parseExpression() throws -> Double {
            var value = try parseTerm()
            while let token = current, token == .op("+") || token == .op("-") {
                position += 1
                sawOperation = true
                let rhs = try parseTerm()
                value = token == .op("+") ? value + rhs : value - rhs
            }
            return value
        }

        mutating func parseTerm() throws -> Double {
            var value = try parseUnary()
            while let token = current {
                switch token {
                case .op("*"):
                    position += 1; sawOperation = true
                    value *= try parseUnary()
                case .op("/"):
                    position += 1; sawOperation = true
                    value /= try parseUnary()
                case .name("mod"):
                    position += 1; sawOperation = true
                    value = fmod(value, try parseUnary())
                default:
                    return value
                }
            }
            return value
        }

        mutating func parseUnary() throws -> Double {
            if current == .op("-") { position += 1; sawOperation = true; return -(try parseUnary()) }
            if current == .op("+") { position += 1; return try parseUnary() }
            return try parsePower()
        }

        mutating func parsePower() throws -> Double {
            let base = try parsePostfix()
            if current == .op("^") {
                position += 1
                sawOperation = true
                return pow(base, try parseUnary())
            }
            return base
        }

        mutating func parsePostfix() throws -> Double {
            var value = try parsePrimary()
            while current == .op("%") {
                position += 1
                sawOperation = true
                value /= 100
            }
            return value
        }

        mutating func parsePrimary() throws -> Double {
            guard let token = current else { throw Failure.syntax }
            position += 1
            switch token {
            case let .number(value):
                return value
            case .open:
                let value = try parseExpression()
                guard current == .close else { throw Failure.syntax }
                position += 1
                return value
            case let .name(name):
                if current == .open { return try parseCall(name) }
                guard let constant = Calculator.constants[name] else { throw Failure.unknownName(name) }
                return constant
            default:
                throw Failure.syntax
            }
        }

        mutating func parseCall(_ name: String) throws -> Double {
            position += 1 // "("
            var args = [try parseExpression()]
            while current == .comma {
                position += 1
                args.append(try parseExpression())
            }
            guard current == .close else { throw Failure.syntax }
            position += 1
            sawOperation = true
            guard let function = Calculator.functions[name] else { throw Failure.unknownName(name) }
            guard let value = function(args) else { throw Failure.syntax }
            return value
        }
    }

    static let constants: [String: Double] = ["pi": .pi, "π": .pi, "tau": 2 * .pi, "e": M_E]

    /// Each returns `nil` on wrong argument count. Trigonometry uses radians.
    static let functions: [String: @Sendable ([Double]) -> Double?] = [
        "sqrt": unary(sqrt), "cbrt": unary(cbrt), "abs": unary(abs),
        "round": unary { $0.rounded() }, "floor": unary(floor), "ceil": unary(ceil),
        "ln": unary(log), "log": unary(log10), "log2": unary(log2), "exp": unary(exp),
        "sin": unary(sin), "cos": unary(cos), "tan": unary(tan),
        "asin": unary(asin), "acos": unary(acos), "atan": unary(atan),
        "min": { $0.min() }, "max": { $0.max() },
    ]

    private static func unary(_ f: @escaping @Sendable (Double) -> Double) -> @Sendable ([Double]) -> Double? {
        { $0.count == 1 ? f($0[0]) : nil }
    }
}
