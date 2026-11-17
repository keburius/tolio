import Foundation

/// Every user-facing string in Tolio.
///
/// Values live in one String Catalog, `OmniCore/Resources/Localizable.xcstrings`,
/// so a translator edits a single file. Accessors are grouped by area in
/// `L10n+<Area>.swift` files next to this one and are the only place string
/// literals for the UI may appear (`Scripts/check-strings.sh` enforces this).
///
/// Accessor forms, which `Scripts/gen-strings.py` reads to build the catalog:
/// - `tr("area.key", "English text")`
/// - `format("area.key", "English with %@ and %lld", args…)`
/// - `plural("area.key", one: "%lld item", other: "%lld items", count)`
public enum L10n {
    static let bundle = Bundle.module
    static let table = "Localizable"

    /// A fixed string.
    public static func tr(_ key: StaticString, _ english: String) -> String {
        bundle.localizedString(forKey: "\(key)", value: english, table: table)
    }

    /// A string with `String(format:)` placeholders.
    public static func format(_ key: StaticString, _ english: String, _ arguments: any CVarArg...) -> String {
        String(format: tr(key, english), locale: Locale.current, arguments: arguments)
    }

    /// A count-dependent string (catalog plural variants).
    public static func plural(_ key: StaticString, one: String, other: String, _ count: Int) -> String {
        let missing = "\u{1}"
        let format = bundle.localizedString(forKey: "\(key)", value: missing, table: table)
        let chosen = format == missing ? (count == 1 ? one : other) : format
        return String.localizedStringWithFormat(chosen, count)
    }

    /// True if the compiled catalog was found (the generator always adds this key).
    static var catalogLoaded: Bool { tr("meta.catalogLoaded", "no") == "yes" }
}
