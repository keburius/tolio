import AppKit
import SwiftUI

/// A borderless window over the notch, above the menu bar. Its clear parts
/// let clicks through; only the black island catches them.
final class IslandPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { true }

    /// Two-finger swipes anywhere on the island (sideways: pages or tracks;
    /// down: open; up: close).
    var onGesture: ((SwipeReader.Gesture) -> Void)?
    private var reader = SwipeReader()
    /// Directions a list under the fingers scrolls itself, so its own
    /// scrolling isn't taken as a swipe.
    private var listScrolls: (vertical: Bool, horizontal: Bool) = (false, false)

    // Read here rather than in a view: lists inside (the agenda, the tray)
    // keep scroll events to themselves, which used to leave the island stuck
    // on those pages.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .scrollWheel { readSwipe(event) }
        super.sendEvent(event)
    }

    private func readSwipe(_ event: NSEvent) {
        guard event.hasPreciseScrollingDeltas else { return }
        if event.phase == .began {
            reader.begin()
            listScrolls = scrollableList(at: event.locationInWindow)
        }
        // Momentum after the fingers lift isn't a new swipe.
        guard event.momentumPhase == [] else { return }
        let dy = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
        let dx = event.scrollingDeltaX * (event.isDirectionInvertedFromDevice ? 1 : -1)
        if let gesture = reader.add(dx: dx, dy: dy) {
            let vertical = gesture == .up || gesture == .down
            if !(vertical ? listScrolls.vertical : listScrolls.horizontal) { onGesture?(gesture) }
        }
        if event.phase == .ended || event.phase == .cancelled { reader.begin() }
    }

    /// Which ways the scroll view under `point` (window coordinates) can move.
    private func scrollableList(at point: NSPoint) -> (vertical: Bool, horizontal: Bool) {
        guard let content = contentView, let hit = content.hitTest(content.convert(point, from: nil)) else { return (false, false) }
        var view: NSView? = hit
        while let current = view, current !== content {
            if let scroll = current as? NSScrollView, let document = scroll.documentView {
                let visible = scroll.contentSize
                return (document.frame.height > visible.height + 1, document.frame.width > visible.width + 1)
            }
            view = current.superview
        }
        return (false, false)
    }
}

/// Hosts an island and takes the first click (swipes are read by `IslandPanel`).
final class IslandHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
