import CoreGraphics
@testable import OmniPlatform
import Testing

@MainActor
struct EventTapTests {
    @Test func maskCombinesEventTypes() {
        let mask = EventTap.mask(.keyDown, .keyUp)
        #expect(mask == (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue))
    }

    @Test func ownEventsAreRecognized() throws {
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
        #expect(!KeySender.isOwnEvent(event))
        event.setIntegerValueField(.eventSourceUserData, value: KeySender.eventMarker)
        #expect(KeySender.isOwnEvent(event))
    }
}
