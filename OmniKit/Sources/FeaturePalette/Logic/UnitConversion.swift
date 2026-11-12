import Foundation

/// Converts physical quantities with Foundation `Dimension` units.
public enum UnitConversion {
    public struct Result: Equatable, Sendable {
        public let value: Double
        public let fromSymbol: String
        public let toSymbol: String
    }

    /// Converts `amount` between two unit names. Nil if either is unknown or
    /// they measure different things.
    public static func convert(_ amount: Double, from: String, to: String) -> Result? {
        // Compare base units, not classes: Foundation's static units are private subclasses.
        guard let source = unit(named: from), let target = unit(named: to),
              type(of: source.unit).baseUnit() == type(of: target.unit).baseUnit() else { return nil }
        let base = source.unit.converter.baseUnitValue(fromValue: amount)
        return Result(
            value: target.unit.converter.value(fromBaseUnitValue: base),
            fromSymbol: source.symbol, toSymbol: target.symbol
        )
    }

    /// The usual counterpart when no target is typed ("5 km" → mi).
    static func defaultTarget(for name: String) -> String? {
        guard let symbol = unit(named: name)?.symbol else { return nil }
        return counterparts[symbol]
    }

    private static let counterparts: [String: String] = [
        "km": "mi", "mi": "km", "m": "ft", "ft": "m", "cm": "in", "in": "cm",
        "kg": "lb", "lb": "kg", "g": "oz", "oz": "g",
        "°C": "°F", "°F": "°C", "L": "gal", "gal": "L", "km/h": "mph", "mph": "km/h",
    ]

    struct NamedUnit {
        let unit: Dimension
        let symbol: String
    }

    static func unit(named raw: String) -> NamedUnit? {
        let name = raw.lowercased().replacingOccurrences(of: " ", with: "")
        guard let entry = table[name] ?? (name.hasSuffix("s") ? table[String(name.dropLast())] : nil) else { return nil }
        return NamedUnit(unit: entry.0, symbol: entry.1)
    }

    private static let day = UnitDuration(symbol: "d", converter: UnitConverterLinear(coefficient: 86_400))
    private static let week = UnitDuration(symbol: "wk", converter: UnitConverterLinear(coefficient: 604_800))

    /// Alias → (unit, display symbol). Plural "s" is stripped before lookup.
    private static let table: [String: (Dimension, String)] = {
        var t: [String: (Dimension, String)] = [:]
        func add(_ unit: Dimension, _ symbol: String, _ aliases: String...) {
            for alias in aliases + [symbol.lowercased()] { t[alias] = (unit, symbol) }
        }
        // Length
        add(UnitLength.millimeters, "mm", "millimeter", "millimetre")
        add(UnitLength.centimeters, "cm", "centimeter", "centimetre")
        add(UnitLength.meters, "m", "meter", "metre")
        add(UnitLength.kilometers, "km", "kilometer", "kilometre")
        add(UnitLength.inches, "in", "inch", "inche", "\"")
        add(UnitLength.feet, "ft", "foot", "feet", "'")
        add(UnitLength.yards, "yd", "yard")
        add(UnitLength.miles, "mi", "mile")
        add(UnitLength.nauticalMiles, "nmi", "nauticalmile")
        // Mass
        add(UnitMass.milligrams, "mg", "milligram")
        add(UnitMass.grams, "g", "gram")
        add(UnitMass.kilograms, "kg", "kilogram", "kilo")
        add(UnitMass.metricTons, "t", "tonne", "ton")
        add(UnitMass.pounds, "lb", "lbs", "pound")
        add(UnitMass.ounces, "oz", "ounce")
        add(UnitMass.stones, "st", "stone")
        // Temperature
        add(UnitTemperature.celsius, "°C", "c", "celsius", "degc")
        add(UnitTemperature.fahrenheit, "°F", "f", "fahrenheit", "degf")
        add(UnitTemperature.kelvin, "K", "k", "kelvin")
        // Volume
        add(UnitVolume.milliliters, "mL", "ml", "milliliter", "millilitre")
        add(UnitVolume.liters, "L", "l", "liter", "litre")
        add(UnitVolume.gallons, "gal", "gallon")
        add(UnitVolume.quarts, "qt", "quart")
        add(UnitVolume.pints, "pt", "pint")
        add(UnitVolume.cups, "cup")
        add(UnitVolume.fluidOunces, "fl oz", "floz", "fluidounce")
        add(UnitVolume.tablespoons, "tbsp", "tablespoon")
        add(UnitVolume.teaspoons, "tsp", "teaspoon")
        // Area
        add(UnitArea.squareMeters, "m²", "m2", "sqm", "squaremeter")
        add(UnitArea.squareKilometers, "km²", "km2", "sqkm", "squarekilometer")
        add(UnitArea.squareFeet, "ft²", "ft2", "sqft", "squarefoot", "squarefeet")
        add(UnitArea.acres, "ac", "acre")
        add(UnitArea.hectares, "ha", "hectare")
        // Speed
        add(UnitSpeed.kilometersPerHour, "km/h", "kph", "kmh")
        add(UnitSpeed.milesPerHour, "mph")
        add(UnitSpeed.metersPerSecond, "m/s", "mps")
        add(UnitSpeed.knots, "kn", "knot", "kt")
        // Duration
        add(UnitDuration.milliseconds, "ms", "millisecond")
        add(UnitDuration.seconds, "s", "sec", "second")
        add(UnitDuration.minutes, "min", "minute")
        add(UnitDuration.hours, "h", "hr", "hour")
        add(day, "d", "day")
        add(week, "wk", "week")
        // Data
        add(UnitInformationStorage.bits, "bit")
        add(UnitInformationStorage.bytes, "B", "b", "byte")
        add(UnitInformationStorage.kilobytes, "KB", "kb", "kilobyte")
        add(UnitInformationStorage.megabytes, "MB", "mb", "megabyte")
        add(UnitInformationStorage.gigabytes, "GB", "gb", "gigabyte")
        add(UnitInformationStorage.terabytes, "TB", "tb", "terabyte")
        add(UnitInformationStorage.kibibytes, "KiB", "kib")
        add(UnitInformationStorage.mebibytes, "MiB", "mib")
        add(UnitInformationStorage.gibibytes, "GiB", "gib")
        add(UnitInformationStorage.tebibytes, "TiB", "tib")
        return t
    }()
}
