import Foundation
import Testing
@testable import FeatureTextActions

struct TextAnalysisTests {
    @Test func webURLs() {
        #expect(TextAnalysis.webURL(in: "https://example.com/a?b=1")?.absoluteString == "https://example.com/a?b=1")
        #expect(TextAnalysis.webURL(in: "  http://example.com  ")?.absoluteString == "http://example.com")
        #expect(TextAnalysis.webURL(in: "example.com/path")?.absoluteString == "https://example.com/path")
        #expect(TextAnalysis.webURL(in: "www.apple.com")?.host == "www.apple.com")
        #expect(TextAnalysis.webURL(in: "<https://example.com>")?.host == "example.com")
    }

    @Test func notWebURLs() {
        for text in ["hello world", "see https://example.com here", "me@example.com", "file:///etc/passwd",
                     "javascript:alert(1)", "omni://palette", "localhost", "3.14", ""] {
            #expect(TextAnalysis.webURL(in: text) == nil, "\(text)")
        }
    }

    @Test func counts() {
        #expect(TextAnalysis.counts("Hello, world!") == .init(words: 2, characters: 13, lines: 1))
        #expect(TextAnalysis.counts("one\ntwo three\n") == .init(words: 3, characters: 14, lines: 2))
        #expect(TextAnalysis.counts("").words == 0)
        #expect(TextAnalysis.counts("").lines == 0)
        // Emoji and combined characters count as one character each.
        #expect(TextAnalysis.counts("👍🏽 café").characters == 6)
        // Languages without spaces still get words.
        #expect(TextAnalysis.counts("გამარჯობა მსოფლიო").words == 2)
    }

    @Test func caseTransforms() {
        #expect(TextAnalysis.uppercased("straße") == "STRASSE")
        #expect(TextAnalysis.lowercased("ÉCOLE") == "école")
    }

    @Test func searchURLs() {
        let url = SearchEngine.google.url(for: "  swift & rust? ")
        #expect(url?.absoluteString == "https://www.google.com/search?q=swift%20%26%20rust?")
        #expect(SearchEngine.duckDuckGo.url(for: "a")?.host == "duckduckgo.com")
        #expect(SearchEngine.kagi.url(for: "   ") == nil)
        let long = String(repeating: "a", count: 2000)
        let query = URLComponents(url: SearchEngine.bing.url(for: long)!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value
        #expect(query?.count == SearchEngine.maxQueryLength)
    }
}
