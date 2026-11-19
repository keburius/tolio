import AppKit
import OmniCore
import SwiftUI

/// A borderless window that can take typing without bringing Tolio forward.
final class MinderPanel: NSPanel {
    var onCancel: (() -> Void)?

    init(level: NSWindow.Level) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }

    /// Any click on the bar makes it the key window first, so typing goes
    /// into the bar and the click never falls through to the desktop.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow { makeKey() }
        super.sendEvent(event)
    }
}

/// Places the bar above the Dock and the alert over the whole screen.
@MainActor
final class MinderWindows {
    private var bar: MinderPanel?
    private var alert: MinderPanel?

    var isBarShown: Bool { bar?.isVisible ?? false }
    var isAlertShown: Bool { alert?.isVisible ?? false }

    func showBar(_ view: some View, takeFocus: Bool, onCancel: @escaping () -> Void) {
        let screen = Self.screenWithPointer()
        let visible = screen.visibleFrame
        // As wide as the screen so the bar can grow both ways from the middle;
        // the clear parts let clicks through.
        let frame = NSRect(x: visible.minX, y: visible.minY + 14, width: visible.width, height: 104)
        let panel = bar ?? MinderPanel(level: .floating)
        panel.onCancel = onCancel
        let host = FirstClickHostingView(rootView: view.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom))
        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        if takeFocus { panel.makeKey() }
        bar = panel
    }

    func hideBar() {
        bar?.orderOut(nil)
    }

    func showAlert(_ view: some View, onCancel: @escaping () -> Void) {
        let screen = Self.screenWithPointer()
        let panel = alert ?? MinderPanel(level: .screenSaver)
        panel.onCancel = onCancel
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let blur = NSVisualEffectView()
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.appearance = NSAppearance(named: .darkAqua)
        let host = NSHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: blur.leadingAnchor), host.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            host.topAnchor.constraint(equalTo: blur.topAnchor), host.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
        ])
        panel.contentView = blur
        panel.setFrame(screen.frame, display: true)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        alert = panel
    }

    func hideAlert() {
        alert?.orderOut(nil)
        alert?.contentView = nil
    }

    func close() {
        hideBar()
        hideAlert()
        bar = nil
        alert = nil
    }

    static func screenWithPointer() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

/// Reacts to the first click even while Tolio isn't the active app, so the
/// bar can be grabbed straight away.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
