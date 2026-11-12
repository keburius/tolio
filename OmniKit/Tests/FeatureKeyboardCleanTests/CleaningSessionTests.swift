import CoreGraphics
@testable import FeatureKeyboardClean
import Foundation
import Testing

struct CleaningSessionTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func remainingAndExpiry() {
        let session = CleaningSession(start: start, duration: 120)
        #expect(session.remaining(at: start.addingTimeInterval(15)) == 105)
        #expect(session.remainingText(at: start.addingTimeInterval(15)) == "1:45")
        #expect(!session.isExpired(at: start.addingTimeInterval(119)))
        #expect(session.isExpired(at: start.addingTimeInterval(120)))
        #expect(session.remaining(at: start.addingTimeInterval(500)) == 0)
    }

    @Test func durationIsCappedSoTheKeyboardAlwaysReturns() {
        #expect(CleaningSession(start: start, duration: 86_400).duration == CleaningSession.maximumDuration)
        #expect(CleaningSession(start: start, duration: 0).duration == 5)
        #expect(CleaningSession.durationChoices.allSatisfy { $0 <= CleaningSession.maximumDuration })
    }

    @Test func blocksEveryKeyboardEventType() {
        for raw: UInt32 in [10, 11, 12, 14] { // keyDown, keyUp, flagsChanged, NX_SYSDEFINED
            #expect(CleaningSession.blockedEvents & (1 << CGEventMask(raw)) != 0, "type \(raw)")
        }
        // Mouse events stay usable so the Unlock button can be clicked.
        for raw: UInt32 in [1, 2, 5, 22] {
            #expect(CleaningSession.blockedEvents & (1 << CGEventMask(raw)) == 0, "type \(raw)")
        }
    }
}
