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
}

/// Hosts an island: takes the first click, and turns two-finger swipes into
/// gestures (sideways: pages or tracks; down: open; up: close).
final class IslandHostingView<Content: View>: NSHostingView<Content> {
    var onGesture: ((SwipeReader.Gesture) -> Void)?
    private var reader = SwipeReader()

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        guard event.hasPreciseScrollingDeltas else { return super.scrollWheel(with: event) }
        if event.phase == .began { reader.begin() }
        // Momentum after the fingers lift isn't a new swipe.
        guard event.momentumPhase == [] else { return super.scrollWheel(with: event) }
        let dy = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
        if let gesture = reader.add(dx: event.scrollingDeltaX * (event.isDirectionInvertedFromDevice ? 1 : -1), dy: dy) {
            onGesture?(gesture)
        }
        // Lists and notes inside still scroll.
        super.scrollWheel(with: event)
        if event.phase == .ended || event.phase == .cancelled { reader.begin() }
    }
}
