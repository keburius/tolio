@testable import FeatureClipboard
import Foundation
import Testing

struct KeystrokeBufferTests {
    private let sig = Snippet(abbreviation: ";sig", title: "Signature", body: "Best,\nGeorge")
    private let btw = Snippet(abbreviation: "btw", title: "By the way", body: "by the way")
    private let btwx = Snippet(abbreviation: "btwx", title: "Longer", body: "longer")

    private func buffer(_ typed: String) -> KeystrokeBuffer {
        var buffer = KeystrokeBuffer()
        buffer.append(typed)
        return buffer
    }

    @Test func matchesAtEnd() {
        #expect(buffer("hello ;sig").match(in: [sig, btw])?.id == sig.id)
        #expect(buffer("hello ;si").match(in: [sig]) == nil)
    }

    @Test func wordAbbreviationsNeedABoundary() {
        #expect(buffer("so btw").match(in: [btw])?.id == btw.id)
        #expect(buffer("btw").match(in: [btw])?.id == btw.id)
        #expect(buffer("abtw").match(in: [btw]) == nil)
        #expect(buffer("x;sig").match(in: [sig])?.id == sig.id) // punctuation-led matches anywhere
    }

    @Test func longestAbbreviationWins() {
        #expect(buffer(" btwx").match(in: [btw, btwx])?.id == btwx.id)
    }

    @Test func disabledSnippetsDoNotMatch() {
        var off = sig
        off.isEnabled = false
        #expect(buffer(";sig").match(in: [off]) == nil)
    }

    @Test func backspaceAndResetEdit() {
        var buffer = buffer(";sigx")
        buffer.backspace()
        #expect(buffer.match(in: [sig])?.id == sig.id)
        buffer.reset()
        #expect(buffer.text.isEmpty)
        buffer.backspace() // no crash on empty
    }

    @Test func capacityIsBounded() {
        let long = buffer(String(repeating: "a", count: 500) + ";sig")
        #expect(long.text.count == KeystrokeBuffer.capacity)
        #expect(long.match(in: [sig])?.id == sig.id)
    }

    @Test func validation() {
        #expect(Snippet.problem(with: "a", among: [], editing: nil) != nil)
        #expect(Snippet.problem(with: "a b", among: [], editing: nil) != nil)
        #expect(Snippet.problem(with: ";sig", among: [sig], editing: nil) != nil)
        #expect(Snippet.problem(with: ";sig", among: [sig], editing: sig.id) == nil)
        #expect(Snippet.problem(with: ";new", among: [sig], editing: nil) == nil)
    }
}

struct PlaceholderExpanderTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15 08:00:00 UTC
    private let posix = Locale(identifier: "en_US_POSIX")
    private let utc = TimeZone(identifier: "UTC")!

    private func expand(_ body: String, clipboard: String? = "CLIP") -> PlaceholderExpander.Expansion {
        PlaceholderExpander.expand(body, now: now, clipboard: clipboard, locale: posix, timeZone: utc)
    }

    @Test func plainTextIsUnchanged() {
        #expect(expand("Hello there") == .init(text: "Hello there", cursorOffsetFromEnd: nil))
    }

    @Test func dateAndTimeWithFormats() {
        #expect(expand("{date:yyyy-MM-dd}").text == "2027-01-15")
        #expect(expand("{time:HH:mm}").text == "08:00")
        #expect(expand("{date}").text == "Jan 15, 2027")
        // macOS puts a narrow no-break space (U+202F) before AM/PM.
        #expect(expand("{time}").text.replacingOccurrences(of: "\u{202F}", with: " ") == "8:00 AM")
    }

    @Test func clipboardPlaceholder() {
        #expect(expand("[{clipboard}]").text == "[CLIP]")
        #expect(expand("[{clipboard}]", clipboard: nil).text == "[]")
    }

    @Test func cursorPositionIsReportedAndRemoved() {
        let result = expand("Dear {cursor},\nThanks")
        #expect(result.text == "Dear ,\nThanks")
        #expect(result.cursorOffsetFromEnd == 8)
        #expect(expand("{cursor}a{cursor}b") == .init(text: "ab", cursorOffsetFromEnd: 2))
    }

    @Test func bracesEscapeAndUnknownTokensStay() {
        #expect(expand("{{json}} {unknown} }").text == "{json} {unknown} }")
        #expect(expand("open { never closed").text == "open { never closed")
    }

    @Test func cursorCountsGraphemesNotBytes() {
        #expect(expand("{cursor}👋🏽é").cursorOffsetFromEnd == 2)
    }
}
