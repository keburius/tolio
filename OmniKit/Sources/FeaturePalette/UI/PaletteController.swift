import AppKit
import OmniCore
import os
import SwiftUI

extension Duration {
    var milliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}

/// A panel that can take keyboard focus without activating Omni, so the
/// frontmost app stays frontmost (like Spotlight).
final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Owns the palette panel: showing, hiding, sizing, and keyboard navigation.
/// The panel is created once and reused, so opening is just ordering it front.
@MainActor
final class PaletteController: NSObject, NSWindowDelegate {
    private let panel: PalettePanel
    private let model: PaletteViewModel
    private let perform: (PaletteItem, _ alternate: Bool) -> Void
    private let log = Log.logger("palette")
    private var keyMonitor: Any?
    private var topEdge: CGFloat = 0
    /// Time from hotkey to panel on screen for the last open.
    private(set) var lastOpenDuration: Duration?

    init(model: PaletteViewModel, perform: @escaping (PaletteItem, _ alternate: Bool) -> Void) {
        self.model = model
        self.perform = perform
        panel = PalettePanel(
            contentRect: NSRect(x: 0, y: 0, width: PaletteView.width, height: PaletteView.headerHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.delegate = self

        let host = NSHostingView(rootView: PaletteView(model: model) { [weak self] index in
            self?.activate(index: index, alternate: false)
        })
        host.sizingOptions = []
        panel.contentView = host
        model.onResultsChanged = { [weak self] in self?.resize() }
        // Lay out once now so the first open doesn't pay for it.
        model.recompute()
        host.layoutSubtreeIfNeeded()
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(startedAt: ContinuousClock.Instant) {
        isVisible ? hide() : show(startedAt: startedAt)
    }

    func show(startedAt: ContinuousClock.Instant) {
        model.reset()
        position()
        installKeyMonitor()
        panel.makeKeyAndOrderFront(nil)
        panel.displayIfNeeded()
        let elapsed = ContinuousClock.now - startedAt
        lastOpenDuration = elapsed
        log.info("Palette open took \(elapsed.milliseconds, format: .fixed(precision: 1)) ms")
    }

    func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    /// Releases the panel; the controller can't be shown again afterwards.
    func close() {
        hide()
        model.onResultsChanged = nil
        panel.delegate = nil
        panel.contentView = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - Layout

    /// Centers horizontally on the screen with the mouse, in the upper third.
    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        topEdge = visible.maxY - visible.height * 0.22
        let height = PaletteView.height(forResults: model.results.count)
        panel.setFrame(NSRect(x: visible.midX - PaletteView.width / 2, y: topEdge - height, width: PaletteView.width, height: height), display: false)
    }

    /// Grows or shrinks downward, keeping the search field in place.
    private func resize() {
        let height = PaletteView.height(forResults: model.results.count)
        var frame = panel.frame
        guard frame.height != height else { return }
        frame.origin.y = (topEdge > 0 ? topEdge : frame.maxY) - height
        frame.size.height = height
        panel.setFrame(frame, display: panel.isVisible)
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns true if the key was handled (and should not reach the text field).
    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch (event.keyCode, flags.contains(.control)) {
        case (125, _), (45, true): model.move(1); return true          // ↓, ⌃N
        case (126, _), (35, true): model.move(-1); return true         // ↑, ⌃P
        case (121, _): model.move(PaletteView.maxVisibleRows); return true  // Page Down
        case (116, _): model.move(-PaletteView.maxVisibleRows); return true // Page Up
        case (53, _): hide(); return true                              // Esc
        case (36, _), (76, _):                                         // Return, Enter
            activate(index: model.selection, alternate: flags.contains(.command))
            return true
        default:
            return false
        }
    }

    private func activate(index: Int, alternate: Bool) {
        model.select(index)
        guard let item = model.selectedItem else { return }
        hide()
        perform(item, alternate)
    }
}
