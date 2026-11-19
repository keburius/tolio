import AppKit
import SwiftUI

/// The full-screen, see-through window that holds the ring. It takes key
/// focus (for Esc) without activating Tolio, and catches clicks and drops.
final class RingPanel: NSPanel {
    var onCancel: (() -> Void)?

    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

/// A small floating window (the Cargo shelf).
final class ShelfPanel: NSPanel {
    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool { true }
}

/// Starts a drag of several files at once (SwiftUI's `onDrag` handles one).
struct FileDragSource: NSViewRepresentable {
    let urls: [URL]
    let onEnd: (_ dropped: Bool) -> Void

    func makeNSView(context: Context) -> FileDragView {
        FileDragView()
    }

    func updateNSView(_ view: FileDragView, context: Context) {
        view.urls = urls
        view.onEnd = onEnd
    }
}

final class FileDragView: NSView, NSDraggingSource {
    var urls: [URL] = []
    var onEnd: (Bool) -> Void = { _ in }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {
        guard !urls.isEmpty else { return }
        let start = convert(event.locationInWindow, from: nil)
        let items = urls.enumerated().map { index, url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let offset = CGFloat(min(index, 4)) * 5
            item.setDraggingFrame(NSRect(x: start.x - 24 + offset, y: start.y - 24 - offset, width: 48, height: 48), contents: icon)
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .generic, .link] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onEnd(operation != [])
    }
}
