import Foundation
@testable import OmniCore
import Testing

struct L10nTests {
    @Test func catalogIsCompiledAndFound() {
        #expect(L10n.catalogLoaded)
    }

    @Test func pluralsPickTheRightForm() {
        #expect(L10n.plural("test.items", one: "%lld item", other: "%lld items", 1) == "1 item")
        #expect(L10n.plural("test.items", one: "%lld item", other: "%lld items", 3) == "3 items")
    }

    @Test func formatFillsPlaceholders() {
        #expect(L10n.format("test.format", "%@ has %lld", "Omni", 2) == "Omni has 2")
    }

    /// Every accessor key is in the catalog with the same English text, and
    /// the catalog has no keys the code doesn't use (besides the marker).
    @Test func catalogMatchesAccessors() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalogURL = root.appendingPathComponent("Sources/OmniCore/Resources/Localizable.xcstrings")
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])
        #expect(catalog["sourceLanguage"] as? String == "en")
        let stringsDir = root.appendingPathComponent("Sources/OmniCore/Strings")
        var keys = Set<String>()
        let pattern = try NSRegularExpression(pattern: #"\b(?:tr|format|plural)\(\s*"([^"]+)""#)
        for file in try FileManager.default.contentsOfDirectory(at: stringsDir, includingPropertiesForKeys: nil)
        where file.pathExtension == "swift" && file.lastPathComponent != "L10n.swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let key = String(text[Range(match.range(at: 1), in: text)!])
                #expect(!keys.contains(key), "duplicate key \(key)")
                keys.insert(key)
            }
        }
        #expect(Set(strings.keys) == keys.union(["meta.catalogLoaded"]))
    }
}
