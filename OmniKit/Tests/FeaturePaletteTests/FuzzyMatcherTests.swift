import Foundation
@testable import FeaturePalette
import Testing

struct FuzzyMatcherTests {
    private func score(_ query: String, _ target: String) -> Double? {
        FuzzyMatcher.match(query, in: target)?.score
    }

    @Test func requiresSubsequence() {
        #expect(score("sfr", "Safari") != nil)
        #expect(score("xyz", "Safari") == nil)
        #expect(score("safarix", "Safari") == nil)
    }

    @Test func caseAndDiacriticsInsensitive() {
        #expect(score("CAFE", "Café Menu") != nil)
        #expect(score("über", "Uber Driver") != nil)
    }

    @Test func spacesInQueryAreIgnored() {
        #expect(score("vs code", "Visual Studio Code") != nil)
    }

    @Test func prefixBeatsMiddle() throws {
        #expect(try #require(score("term", "Terminal")) > #require(score("term", "Determine")))
    }

    @Test func acronymBeatsScatteredMatch() throws {
        #expect(try #require(score("ss", "System Settings")) > #require(score("ss", "Messages")))
        #expect(try #require(score("vsc", "Visual Studio Code")) > #require(score("vsc", "Visual Basic Scripts")))
    }

    @Test func camelCaseCountsAsWordStart() throws {
        #expect(try #require(score("tp", "TablePlus")) > #require(score("tp", "Teleport")))
    }

    @Test func consecutiveBeatsGapped() throws {
        #expect(try #require(score("note", "Notes")) > #require(score("note", "Number Of Tiny Errors")))
    }

    @Test func exactMatchWins() throws {
        #expect(try #require(score("mail", "Mail")) > #require(score("mail", "Mailplane")))
    }

    @Test func reportsMatchedIndicesForHighlighting() throws {
        let match = try #require(FuzzyMatcher.match("ss", in: "System Settings"))
        #expect(match.matchedIndices == [0, 7])
    }
}
