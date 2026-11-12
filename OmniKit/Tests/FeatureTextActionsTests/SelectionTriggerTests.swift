import CoreGraphics
import Testing
@testable import FeatureTextActions

struct SelectionTriggerTests {
    let a = CGPoint(x: 100, y: 100)

    @Test func dragTriggersMouseCheck() {
        var t = SelectionTrigger()
        #expect(t.handle(.mouseDown(a, clickCount: 1, shift: false)) == [])
        _ = t.handle(.mouseDragged(CGPoint(x: 103, y: 100)))
        _ = t.handle(.mouseDragged(CGPoint(x: 140, y: 102)))
        let up = CGPoint(x: 150, y: 102)
        #expect(t.handle(.mouseUp(up)) == [.check(.mouse(down: a, up: up), delay: SelectionTrigger.mouseDelay)])
    }

    @Test func plainClickAndTinyDragDoNothing() {
        var t = SelectionTrigger()
        _ = t.handle(.mouseDown(a, clickCount: 1, shift: false))
        #expect(t.handle(.mouseUp(a)) == [])
        _ = t.handle(.mouseDown(a, clickCount: 1, shift: false))
        _ = t.handle(.mouseDragged(CGPoint(x: 103, y: 102)))
        #expect(t.handle(.mouseUp(CGPoint(x: 103, y: 102))) == [])
    }

    @Test func doubleClickAndShiftClick() {
        var t = SelectionTrigger()
        _ = t.handle(.mouseDown(a, clickCount: 2, shift: false))
        #expect(t.handle(.mouseUp(a)).count == 1)
        _ = t.handle(.mouseDown(a, clickCount: 1, shift: true))
        #expect(t.handle(.mouseUp(a)).count == 1)
    }

    @Test func upWithoutDownIgnored() {
        var t = SelectionTrigger()
        #expect(t.handle(.mouseUp(a)) == [])
    }

    @Test func keyboardAndDismiss() {
        var t = SelectionTrigger()
        #expect(t.handle(.shiftNavigationKeyUp) == [.check(.keyboard, delay: SelectionTrigger.keyboardDelay)])
        #expect(t.handle(.keyDown) == [.dismiss])
        #expect(t.handle(.scroll) == [.dismiss])
    }

    @Test func contentGesture() {
        let window = CGRect(x: 0, y: 0, width: 800, height: 600) // AppKit: title bar at the top (y near 600)
        #expect(SelectionTrigger.isContentGesture(down: CGPoint(x: 100, y: 300), up: CGPoint(x: 300, y: 280), window: window))
        // Dragging the title bar (window move).
        #expect(!SelectionTrigger.isContentGesture(down: CGPoint(x: 100, y: 590), up: CGPoint(x: 300, y: 590), window: window))
        // Resizing from the right edge.
        #expect(!SelectionTrigger.isContentGesture(down: CGPoint(x: 798, y: 300), up: CGPoint(x: 900, y: 300), window: window))
        // Ending outside the window.
        #expect(!SelectionTrigger.isContentGesture(down: CGPoint(x: 100, y: 300), up: CGPoint(x: 900, y: 300), window: window))
    }
}
