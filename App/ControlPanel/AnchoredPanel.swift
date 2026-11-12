import AppKit
import OmniPlatform
import SwiftUI

/// A popover-style panel under a menu bar icon. It takes the keyboard
/// without activating Omni, so the app you were using stays active (paste
/// and window layouts act on it). Closes on Esc, a click elsewhere, or when
/// another app becomes active.
@MainActor
final class AnchoredPanel: NSObject, NSWindowDelegate {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    private let panel: Panel
    private var keyMonitor: Any?
    /// Return true if the key was handled.
    var onKey: ((NSEvent) -> Bool)?
    var onClose: (() -> Void)?

    init<Content: View>(content: Content) {
        panel = Panel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        super.init()
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.delegate = self
        let host = NSHostingView(rootView: content)
        panel.contentView = host
    }

    var isVisible: Bool { panel.isVisible }

    /// Shows the panel below `button` (or centered at the top of the main screen).
    func show(below button: NSView?) {
        guard let host = panel.contentView else { return }
        let size = host.fittingSize
        var origin: CGPoint
        if let button, let window = button.window {
            let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
            origin = CGPoint(x: frame.midX - size.width / 2, y: frame.minY - size.height - 6)
            if let visible = window.screen?.visibleFrame {
                origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            }
        } else {
            let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            origin = CGPoint(x: visible.maxX - size.width - 16, y: visible.maxY - size.height - 8)
        }
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        installKeyMonitor()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Re-fits the panel to its content (e.g. after the clip list changed).
    func refit() {
        guard panel.isVisible, let host = panel.contentView else { return }
        let size = host.fittingSize
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true)
    }

    func close() {
        guard panel.isVisible else { return }
        removeKeyMonitor()
        panel.orderOut(nil)
        onClose?()
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            if event.keyCode == 53 { // Esc
                self.close()
                return nil
            }
            return self.onKey?(event) == true ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
