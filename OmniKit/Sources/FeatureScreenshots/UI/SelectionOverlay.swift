import AppKit
import OmniCore
import OmniPlatform

/// What the user picked on the selection overlay.
enum OverlayResult {
    /// AppKit global points.
    case area(CGRect)
    case window(PickableWindow)
    case cancelled
}

enum OverlayMode {
    case screenshot, text, record, scrolling

    var hint: String {
        switch self {
        case .screenshot: L10n.Screenshots.hintScreenshot
        case .text: L10n.Screenshots.hintText
        case .record: L10n.Screenshots.hintRecord
        case .scrolling: L10n.Screenshots.hintScrolling
        }
    }

    /// Only screenshots can pick a whole window; Capture Text always takes a dragged area.
    var picksWindows: Bool { self == .screenshot }
}

/// Full-screen panels on every display for choosing what to capture.
@MainActor
final class SelectionOverlay {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    /// Shared by the views on all displays (a drag can cross displays).
    final class State {
        var start: CGPoint?
        var current: CGPoint?
        var hovered: PickableWindow?
        var windows: [PickableWindow] = []
        let mode: OverlayMode

        init(mode: OverlayMode) { self.mode = mode }

        var selection: CGRect? {
            guard let start, let current else { return nil }
            return CGRect(x: min(start.x, current.x), y: min(start.y, current.y), width: abs(start.x - current.x), height: abs(start.y - current.y))
        }
    }

    /// Whether ⇧ was held when the last selection ended (Capture Text's append mode).
    static var lastFinishedWithShift = false

    private var panels: [Panel] = []
    private var continuation: CheckedContinuation<OverlayResult, Never>?
    private let state: State
    private static var active: SelectionOverlay?

    private init(mode: OverlayMode) {
        state = State(mode: mode)
    }

    /// Shows the overlay and waits for a choice. Only one runs at a time.
    static func choose(_ mode: OverlayMode) async -> OverlayResult {
        guard active == nil else { return .cancelled }
        let overlay = SelectionOverlay(mode: mode)
        active = overlay
        let result = await withCheckedContinuation { continuation in
            overlay.continuation = continuation
            overlay.show()
        }
        active = nil
        // Let the window server remove the overlay before anything is captured.
        try? await Task.sleep(for: .milliseconds(120))
        return result
    }

    private func show() {
        if state.mode.picksWindows { state.windows = WindowPicker.windows() }
        state.current = NSEvent.mouseLocation
        updateHover()
        for screen in NSScreen.screens {
            let panel = Panel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isReleasedWhenClosed = false
            panel.acceptsMouseMovedEvents = true
            // The overlay draws nothing before a drag; without this macOS would
            // pass clicks on its transparent pixels to the app underneath.
            panel.ignoresMouseEvents = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size), screenFrame: screen.frame, scale: screen.backingScaleFactor, state: state)
            view.onFinish = { [weak self] result in self?.finish(result) }
            view.onChange = { [weak self] in self?.redraw() }
            panel.contentView = view
            panel.setFrame(screen.frame, display: false)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        let mouse = NSEvent.mouseLocation
        if let panel = panels.first(where: { $0.frame.contains(mouse) }) ?? panels.first {
            panel.makeKey()
            panel.makeFirstResponder(panel.contentView) // so Esc reaches the view
        }
        NSCursor.crosshair.push()
    }

    private func updateHover() {
        guard state.mode.picksWindows, state.start == nil, let point = state.current else {
            state.hovered = nil
            return
        }
        state.hovered = state.windows.first { $0.frame.contains(point) }
    }

    private func redraw() {
        updateHover()
        for panel in panels { panel.contentView?.needsDisplay = true }
    }

    private func finish(_ result: OverlayResult) {
        guard let continuation else { return }
        self.continuation = nil
        NSCursor.pop()
        for panel in panels { panel.orderOut(nil) }
        panels.removeAll()
        continuation.resume(returning: result)
    }
}

/// Draws the dimmed screen, the selection or hovered window, and handles input.
private final class SelectionView: NSView {
    let screenFrame: CGRect
    let scale: CGFloat
    let state: SelectionOverlay.State
    var onFinish: (OverlayResult) -> Void = { _ in }
    var onChange: () -> Void = {}

    init(frame: CGRect, screenFrame: CGRect, scale: CGFloat, state: SelectionOverlay.State) {
        self.screenFrame = screenFrame
        self.scale = scale
        self.state = state
        super.init(frame: frame)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func cursorUpdate(with event: NSEvent) { NSCursor.crosshair.set() }

    private func local(_ global: CGRect) -> CGRect {
        global.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
    }

    /// Before dragging the screen stays as it is: only a hint above the
    /// pointer (and, for screenshots, a light outline around the window a
    /// click would take). While dragging, everything outside the area dims.
    override func draw(_ dirtyRect: NSRect) {
        // An almost invisible fill keeps every pixel "hit", so clicks and drags
        // always land on the overlay (belt and braces with ignoresMouseEvents).
        NSColor.black.withAlphaComponent(0.002).setFill()
        bounds.fill()
        if let selection = state.selection {
            let hole = local(selection)
            NSColor.black.withAlphaComponent(0.3).setFill()
            let path = NSBezierPath(rect: bounds)
            path.append(NSBezierPath(rect: hole))
            path.windingRule = .evenOdd
            path.fill()
            let border = NSBezierPath(rect: hole.insetBy(dx: -0.5, dy: -0.5))
            border.lineWidth = 1
            NSColor.white.setStroke()
            border.stroke()
            if selection.intersects(screenFrame) {
                drawLabel(L10n.Screenshots.sizeLabel(Int((selection.width * scale).rounded()), Int((selection.height * scale).rounded())),
                          near: CGPoint(x: hole.maxX, y: hole.minY))
            }
        } else if let window = state.hovered?.frame {
            drawWindowOutline(local(window))
        }
        let mouse = NSEvent.mouseLocation
        if screenFrame.contains(mouse) && state.start == nil {
            drawPointerHint(state.mode.hint, at: CGPoint(x: mouse.x - screenFrame.minX, y: mouse.y - screenFrame.minY))
        }
    }

    /// A light outline (white with a dark edge, visible on any background).
    private func drawWindowOutline(_ rect: CGRect) {
        let shape = rect.insetBy(dx: 1.5, dy: 1.5)
        let dark = NSBezierPath(roundedRect: shape, xRadius: 10, yRadius: 10)
        dark.lineWidth = 4
        NSColor.black.withAlphaComponent(0.25).setStroke()
        dark.stroke()
        let light = NSBezierPath(roundedRect: shape, xRadius: 10, yRadius: 10)
        light.lineWidth = 2
        NSColor.white.withAlphaComponent(0.9).setStroke()
        light.stroke()
    }

    private func drawLabel(_ text: String, near point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        var rect = CGRect(x: point.x - size.width - 12, y: point.y - size.height - 10, width: size.width + 10, height: size.height + 4)
        rect.origin.x = max(4, min(rect.minX, bounds.maxX - rect.width - 4))
        rect.origin.y = max(4, rect.minY)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: rect, xRadius: OmniStyle.controlRadius, yRadius: OmniStyle.controlRadius).fill()
        string.draw(at: CGPoint(x: rect.minX + 5, y: rect.minY + 2))
    }

    /// A small pill just above the pointer (below it near the top edge).
    private func drawPointerHint(_ text: String, at point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.white]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        var rect = CGRect(x: point.x - size.width / 2 - 10, y: point.y + 22, width: size.width + 20, height: size.height + 10)
        if rect.maxY > bounds.maxY - 4 { rect.origin.y = point.y - 30 - rect.height }
        rect.origin.x = max(4, min(rect.minX, bounds.maxX - rect.width - 4))
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
        string.draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 5))
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
        state.current = NSEvent.mouseLocation
        onChange()
    }

    override func mouseDown(with event: NSEvent) {
        state.start = NSEvent.mouseLocation
        state.current = state.start
        onChange()
    }

    override func mouseDragged(with event: NSEvent) {
        state.current = NSEvent.mouseLocation
        onChange()
    }

    override func mouseUp(with event: NSEvent) {
        SelectionOverlay.lastFinishedWithShift = event.modifierFlags.contains(.shift)
        state.current = NSEvent.mouseLocation
        let selection = state.selection
        let point = NSEvent.mouseLocation
        state.start = nil
        if let selection, selection.width >= 3, selection.height >= 3 {
            onFinish(.area(selection))
            return
        }
        switch state.mode {
        case .record:
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) { onFinish(.area(screen.frame)) }
        case .screenshot:
            if let window = state.windows.first(where: { $0.frame.contains(point) }) { onFinish(.window(window)) }
        case .text, .scrolling: // a plain click doesn't pick anything; keep waiting for a drag
            break
        }
        onChange()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onFinish(.cancelled) } // Esc
    }

    override func rightMouseDown(with event: NSEvent) { onFinish(.cancelled) }
}
