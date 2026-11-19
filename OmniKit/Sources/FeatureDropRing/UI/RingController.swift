import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Shows and hides the ring around the pointer, and the Cargo shelf.
@MainActor
final class RingController {
    let model = RingModel()
    private var panel: RingPanel?
    private var shelf: ShelfPanel?
    private(set) var isShown = false

    func toggle() {
        isShown ? hide() : show()
    }

    func show() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let frame = screen.frame
        let panel = panel ?? makePanel()
        panel.setFrame(frame, display: false)
        // Window coordinates, top-left origin, as SwiftUI lays out.
        let center = CGPoint(x: mouse.x - frame.minX, y: frame.maxY - mouse.y)
        let visible = screen.visibleFrame
        let bounds = CGRect(x: visible.minX - frame.minX, y: frame.maxY - visible.maxY, width: visible.width, height: visible.height)
        model.layout = RingLayout(count: model.items.count, orbSize: model.layout.orbSize, center: center, bounds: bounds)
        model.hovered = nil
        model.appeared = false
        panel.orderFrontRegardless()
        panel.makeKey()
        isShown = true
        DispatchQueue.main.async { [model] in model.appeared = true }
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        model.appeared = false
        model.hovered = nil
        panel?.orderOut(nil)
    }

    func close() {
        hide()
        hideShelf()
        panel = nil
        shelf = nil
    }

    private func makePanel() -> RingPanel {
        let panel = RingPanel(frame: .zero)
        panel.onCancel = { [weak self] in self?.hide() }
        panel.contentView = NSHostingView(rootView: RingView(model: model))
        self.panel = panel
        return panel
    }

    // MARK: Cargo shelf

    var isShelfShown: Bool { shelf?.isVisible ?? false }

    func showShelf(_ view: some View) {
        let size = NSSize(width: 260, height: 210)
        let shelf = shelf ?? ShelfPanel(size: size)
        shelf.contentView = NSHostingView(rootView: view)
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }?.visibleFrame ?? .zero
        let x = min(max(mouse.x - size.width / 2, screen.minX + 8), screen.maxX - size.width - 8)
        let y = min(max(mouse.y - size.height / 2, screen.minY + 8), screen.maxY - size.height - 8)
        shelf.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        shelf.orderFrontRegardless()
        self.shelf = shelf
    }

    func hideShelf() {
        shelf?.orderOut(nil)
    }
}
