import Testing
import CoreGraphics
@testable import FeatureShortcutOverlay

struct HoldGestureTests {
    /// Feeds inputs and returns all effects.
    private func run(_ inputs: [HoldGesture.Input], on gesture: inout HoldGesture) -> [HoldGesture.Effect] {
        inputs.flatMap { gesture.handle($0) }
    }

    @Test func tapThenHoldShows() {
        var g = HoldGesture()
        let effects = run([.down(0), .up(0.1), .down(0.25)], on: &g)
        #expect(effects == [.prepare, .checkAfter(0.25)])
        #expect(g.handle(.tick(0.5)) == [.show])
        #expect(g.isShowing)
        #expect(g.handle(.up(2)) == [.hide])
        #expect(g.state == .idle)
    }

    @Test func doubleTapWithoutHoldDoesNothing() {
        var g = HoldGesture()
        _ = run([.down(0), .up(0.1), .down(0.2), .up(0.3)], on: &g)
        #expect(g.handle(.tick(0.45)) == [])
        #expect(!g.isShowing)
    }

    @Test func earlyTickWaits() {
        var g = HoldGesture()
        _ = run([.down(0), .up(0.1), .down(0.2)], on: &g)
        #expect(g.handle(.tick(0.3)) == [])
        #expect(g.handle(.tick(0.45)) == [.show])
    }

    @Test func slowFirstPressIsNotATap() {
        var g = HoldGesture()
        _ = run([.down(0), .up(0.5)], on: &g)
        #expect(g.state == .idle)
        #expect(g.handle(.down(0.6)) == [])
    }

    @Test func longGapStartsOver() {
        var g = HoldGesture()
        _ = run([.down(0), .up(0.1)], on: &g)
        #expect(g.handle(.down(0.6)) == [])
        #expect(g.state == .firstDown(at: 0.6))
        // That press can be the first of a new gesture.
        _ = g.handle(.up(0.7))
        #expect(g.handle(.down(0.8)) == [.prepare, .checkAfter(0.25)])
    }

    @Test func otherInputCancelsAtEveryStage() {
        // ⌘C then ⌘V must never open the overlay.
        for cut in 1...3 {
            var g = HoldGesture()
            _ = run(Array([HoldGesture.Input.down(0), .up(0.1), .down(0.2)].prefix(cut)), on: &g)
            _ = g.handle(.other)
            #expect(g.state == .idle)
            #expect(g.handle(.tick(1)) == [])
        }
    }

    @Test func keyWhileShowingHides() {
        var g = HoldGesture()
        _ = run([.down(0), .up(0.1), .down(0.2), .tick(0.5)], on: &g)
        #expect(g.handle(.other) == [.hide])
    }

    @Test func staleTickAfterResetIgnored() {
        var g = HoldGesture()
        _ = run([.down(0), .up(0.1), .down(0.2), .up(0.3)], on: &g)
        _ = run([.down(1), .up(1.1), .down(1.2)], on: &g)
        // The tick scheduled by the first attempt arrives late but early for this one.
        #expect(g.handle(.tick(1.3)) == [])
        #expect(g.handle(.tick(1.46)) == [.show])
    }

    @Test func modifierTransitions() {
        var t = ModifierTransitions()
        let cmd = CGEventFlags.maskCommand
        #expect(t.input(for: [.maskCommand], trigger: cmd, at: 1) == .down(1))
        #expect(t.input(for: [], trigger: cmd, at: 2) == .up(2))
        // Caps Lock and non-modifier bits are ignored.
        #expect(t.input(for: [.maskCommand, .maskAlphaShift], trigger: cmd, at: 3) == .down(3))
        #expect(t.input(for: [.maskAlphaShift], trigger: cmd, at: 4) == .up(4))
        // ⇧ then ⌘ is a chord, not a trigger press.
        #expect(t.input(for: [.maskShift], trigger: cmd, at: 5) == .other)
        #expect(t.input(for: [.maskShift, .maskCommand], trigger: cmd, at: 6) == .other)
        #expect(t.input(for: [.maskCommand], trigger: cmd, at: 7) == .other)
        #expect(t.input(for: [], trigger: cmd, at: 8) == .up(8))
        // A different trigger.
        #expect(t.input(for: [.maskAlternate], trigger: .maskAlternate, at: 9) == .down(9))
    }
}
