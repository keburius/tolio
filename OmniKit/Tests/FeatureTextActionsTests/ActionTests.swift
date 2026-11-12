import Foundation
import OmniPlatform
import Testing
@testable import FeatureTextActions

@MainActor
final class FakeContext: TextActionContext {
    var log: [String] = []
    func replaceSelection(with text: String) { log.append("replace:\(text)") }
    func copyToClipboard(_ text: String) { log.append("copy:\(text)") }
    func pasteClipboard() { log.append("paste") }
    func open(_ url: URL) { log.append("open:\(url.absoluteString)") }
    func openPalette(query: String) { log.append("palette:\(query)") }
    func showMessage(_ text: String, symbol: String) { log.append("message:\(text)") }
    func translate(_ text: String, replaceable: Bool) { log.append("translate:\(replaceable)") }
    var searchEngine: SearchEngine { .duckDuckGo }
}

@MainActor
struct ActionTests {
    private func ids(_ selection: TextSelection) -> [String] {
        TextActionCatalog.available(for: selection).map(\.id)
    }

    @Test func availabilityInEditableField() {
        let s = TextSelection(text: "Hello world", source: .accessibility, isEditable: true)
        #expect(ids(s) == ["copy", "paste", "search", "translate", "uppercase", "lowercase", "count", "palette"])
    }

    @Test func readOnlyTextHasNoReplacingActions() {
        let s = TextSelection(text: "Hello world", source: .accessibility, isEditable: false)
        #expect(!ids(s).contains("paste"))
        #expect(!ids(s).contains("uppercase"))
        #expect(!ids(s).contains("lowercase"))
    }

    @Test func linksAndAlreadyCased() {
        let url = TextSelection(text: "https://swift.org", source: .copyFallback)
        #expect(ids(url).contains("openURL"))
        let upper = TextSelection(text: "ABC", source: .accessibility, isEditable: true)
        #expect(!ids(upper).contains("uppercase"))
        #expect(ids(upper).contains("lowercase"))
        let digits = TextSelection(text: "12345", source: .accessibility, isEditable: true)
        #expect(!ids(digits).contains("translate"))
    }

    @Test func enabledFilter() {
        let s = TextSelection(text: "x", source: .accessibility, isEditable: true)
        #expect(TextActionCatalog.available(for: s, enabled: ["count", "copy"]).map(\.id) == ["copy", "count"])
    }

    @Test func performs() {
        let context = FakeContext()
        let s = TextSelection(text: " two words\nline ", source: .accessibility, isEditable: true)
        for id in ["copy", "search", "uppercase", "count", "palette", "translate"] {
            TextActionCatalog.builtIn.first { $0.id == id }!.perform(s, context: context)
        }
        #expect(context.log == [
            "copy: two words\nline ", "message:Copied",
            "open:https://duckduckgo.com/?q=two%20words%0Aline",
            "replace: TWO WORDS\nLINE ",
            "message:3 words, 16 characters, 2 lines",
            "palette:two words line",
            "translate:true",
        ])
    }

    @Test func leaseExpires() {
        #expect(!PasteboardLease.isActive)
        PasteboardLease.begin()
        #expect(PasteboardLease.isActive)
        PasteboardLease.end()
        #expect(!PasteboardLease.isActive)
    }
}
