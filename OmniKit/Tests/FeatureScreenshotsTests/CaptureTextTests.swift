import Foundation
import Testing
@testable import FeatureScreenshots

struct CaptureTextTests {
    let lines = ["  Hello   world ", "", "second\tline", "   "]

    @Test func keepLineBreaks() {
        #expect(CaptureTextComposer.format(lines, mode: .keep) == "Hello world\nsecond line")
    }

    @Test func joinIntoParagraph() {
        #expect(CaptureTextComposer.format(lines, mode: .join) == "Hello world second line")
        #expect(CaptureTextComposer.format(["one"], mode: .join) == "one")
    }

    @Test func replaceByDefault() {
        var composer = CaptureTextComposer()
        _ = composer.compose(lines: ["first"], codes: [], mode: .keep, append: false)
        let outcome = composer.compose(lines: ["second"], codes: [], mode: .keep, append: false)
        #expect(outcome == .text("second", added: "second", appended: false))
        #expect(composer.lastCapture == "second")
    }

    @Test func appendAddsToPreviousCapture() {
        var composer = CaptureTextComposer()
        _ = composer.compose(lines: ["first", "part"], codes: [], mode: .keep, append: false)
        #expect(composer.compose(lines: ["more"], codes: [], mode: .keep, append: true)
            == .text("first\npart\nmore", added: "more", appended: true))
        // Paragraph mode joins with a space.
        #expect(composer.compose(lines: ["end"], codes: [], mode: .join, append: true)
            == .text("first\npart\nmore end", added: "end", appended: true))
    }

    @Test func appendWithoutPreviousCaptureJustCopies() {
        var composer = CaptureTextComposer()
        #expect(composer.compose(lines: ["solo"], codes: [], mode: .keep, append: true) == .text("solo", added: "solo", appended: false))
    }

    @Test func emptyResultChangesNothing() {
        var composer = CaptureTextComposer(lastCapture: "kept")
        #expect(composer.compose(lines: [], codes: [], mode: .keep, append: false) == .empty)
        #expect(composer.compose(lines: ["  ", ""], codes: ["  "], mode: .join, append: true) == .empty)
        #expect(composer.lastCapture == "kept") // an empty capture doesn't reset append
    }

    @Test func codesWinAndLinksAreDetected() {
        var composer = CaptureTextComposer()
        #expect(composer.compose(lines: ["Scan me"], codes: ["https://example.com/a"], mode: .keep, append: false)
            == .code("https://example.com/a", link: URL(string: "https://example.com/a")))
        #expect(composer.compose(lines: [], codes: ["4006381333931"], mode: .keep, append: false) == .code("4006381333931", link: nil))
        #expect(composer.compose(lines: [], codes: ["javascript:alert(1)"], mode: .keep, append: false) == .code("javascript:alert(1)", link: nil))
        #expect(composer.compose(lines: [], codes: ["https://a.com", "https://b.com"], mode: .keep, append: false)
            == .code("https://a.com\nhttps://b.com", link: nil))
    }

    @Test func supportedLanguagesAreReported() {
        let languages = TextRecognizer.supportedLanguages()
        #expect(languages.contains("en-US"))
    }
}
