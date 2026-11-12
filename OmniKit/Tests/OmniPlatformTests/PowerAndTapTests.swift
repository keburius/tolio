import CoreGraphics
import Foundation
import IOKit.pwr_mgt
@testable import OmniPlatform
import Testing

@MainActor
struct PowerAssertionTests {
    /// Names of assertions this process holds, from IOKit itself.
    private func heldNames() -> [String] {
        var raw: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&raw) == kIOReturnSuccess,
              let byProcess = raw?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return [] }
        let mine = byProcess[NSNumber(value: ProcessInfo.processInfo.processIdentifier)] ?? []
        return mine.compactMap { $0["AssertName"] as? String }
    }

    @Test func holdAndReleaseAreVisibleToIOKit() {
        let reason = "Omni test \(UUID().uuidString)"
        let assertion = PowerAssertion()
        #expect(assertion.hold(.system, reason: reason))
        #expect(assertion.isHeld)
        #expect(heldNames().contains(reason))
        assertion.release()
        #expect(!assertion.isHeld)
        #expect(!heldNames().contains(reason))
    }

    @Test func switchingKindReplacesTheAssertion() {
        let assertion = PowerAssertion()
        assertion.hold(.system, reason: "Omni test A")
        assertion.hold(.display, reason: "Omni test B")
        #expect(assertion.heldKind == .display)
        #expect(!heldNames().contains("Omni test A"))
        assertion.release()
    }
}

@MainActor
struct FailOpenTests {
    @Test func filteringTapStopsAndReportsWhenSystemDisablesIt() throws {
        var disabled = 0
        var swallowed = 0
        let tap = EventTap(mask: EventTap.mask(.keyDown), mode: .filtering, handler: { _, _ in
            swallowed += 1
            return true
        }, onDisabled: { disabled += 1 })
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))

        #expect(tap.shouldDeliver(type: .keyDown, event: event) == false) // swallowing while healthy
        #expect(tap.shouldDeliver(type: .tapDisabledByTimeout, event: event) == true)
        #expect(disabled == 1)
        #expect(!tap.isRunning)
        _ = tap.shouldDeliver(type: .tapDisabledByUserInput, event: event)
        #expect(disabled == 2)
        #expect(swallowed == 1)
    }

    @Test func listenOnlyTapNeverSwallows() throws {
        let tap = EventTap(mask: EventTap.mask(.keyDown), mode: .listenOnly, handler: { _, _ in true })
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
        #expect(tap.shouldDeliver(type: .keyDown, event: event))
    }
}
