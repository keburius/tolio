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

struct PauseClockTests {
    @Test func pausedStretchIsCutOut() {
        var clock = PauseClock()
        #expect(clock.adjust(10) == 10)
        #expect(clock.adjust(11) == 11)
        clock.pause()
        #expect(clock.adjust(12) == nil) // dropped while paused
        #expect(clock.adjust(15) == nil)
        clock.resume()
        // 11 → 20 was paused: the next sample continues right after 11.
        #expect(clock.adjust(20) == 11)
        #expect(clock.adjust(21) == 12)
        #expect(clock.offset == 9)
    }

    @Test func twoPausesAddUp() {
        var clock = PauseClock()
        _ = clock.adjust(0)
        clock.pause(); clock.resume()
        #expect(clock.adjust(5) == 0)
        clock.pause(); clock.resume()
        #expect(clock.adjust(8) == 0)
        #expect(clock.offset == 8)
    }

    @Test func pauseBeforeAnySampleIsHarmless() {
        var clock = PauseClock()
        clock.pause()
        clock.resume()
        #expect(clock.adjust(3) == 3)
    }

    @Test func timerStopsWhilePaused() {
        let start = Date(timeIntervalSince1970: 0)
        var timer = RecordingTimer(start: start)
        #expect(timer.elapsed(at: start.addingTimeInterval(10)) == 10)
        timer.pause(at: start.addingTimeInterval(10))
        #expect(timer.elapsed(at: start.addingTimeInterval(25)) == 10)
        timer.resume(at: start.addingTimeInterval(25))
        #expect(timer.elapsed(at: start.addingTimeInterval(30)) == 15)
        #expect(!timer.isPaused)
    }
}
