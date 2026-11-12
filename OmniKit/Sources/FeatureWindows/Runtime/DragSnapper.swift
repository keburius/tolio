import AppKit
import OmniCore
import OmniPlatform

/// Drag a window by its title bar to a screen edge or corner to snap it.
/// Uses a listen-only event tap, so it never interferes with the drag.
@MainActor
final class DragSnapper {
    /// Height of the area at the top of a window treated as its title bar.
    static let titleBarHeight: CGFloat = 40

    private let manager: WindowManager
    private var tap: EventTap?
    private let preview = SnapPreview()

    private var mouseDown: CGPoint?
    private var probed = false
    private var window: AXWindow?
    private var startFrame: CGRect?
    private var zone: (action: WindowAction, screen: Int)?

    init(manager: WindowManager) {
        self.manager = manager
    }

    var isRunning: Bool { tap != nil }

    func start() throws {
        guard tap == nil else { return }
        let tap = EventTap(mask: EventTap.mask(.leftMouseDown, .leftMouseDragged, .leftMouseUp), mode: .listenOnly) {
            [weak self] type, event in
            self?.handle(type, at: event.location)
            return false
        }
        try tap.start()
        self.tap = tap
    }

    func stop() {
        tap?.stop()
        tap = nil
        reset()
    }

    private func handle(_ type: CGEventType, at point: CGPoint) {
        switch type {
        case .leftMouseDown:
            reset()
            mouseDown = point
        case .leftMouseDragged:
            if !probed, let start = mouseDown {
                probed = true
                // AX calls are IPC; do them after the tap callback returns.
                Task { @MainActor [weak self] in self?.probeWindow(at: start) }
            }
            guard window != nil else { return }
            updateZone(at: point)
        case .leftMouseUp:
            finish()
        default:
            break
        }
    }

    private func probeWindow(at point: CGPoint) {
        guard mouseDown != nil, let candidate = AXWindow.at(point), let frame = candidate.frame,
              candidate.pid != ProcessInfo.processInfo.processIdentifier,
              candidate.isStandard, candidate.isResizable, !candidate.isFullScreen,
              point.y - frame.minY <= Self.titleBarHeight, point.y >= frame.minY else { return }
        window = candidate
        startFrame = frame
    }

    private func updateZone(at point: CGPoint) {
        let screens = manager.screens
        guard let action = SnapZones.action(at: point, screens: screens),
              let screen = screens.firstIndex(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }),
              let current = window?.frame,
              let target = WindowLayout.frame(for: action, window: current, visible: screens[screen].visibleFrame) else {
            zone = nil
            preview.hide()
            return
        }
        if zone?.action != action || zone?.screen != screen {
            zone = (action, screen)
            preview.show(axFrame: target)
        }
    }

    private func finish() {
        preview.hide()
        defer { reset() }
        guard let window, let zone, let startFrame, let now = window.frame,
              now.origin != startFrame.origin else { return } // The window didn't move: not a drag.
        manager.apply(zone.action, to: window, screenIndex: zone.screen)
    }

    private func reset() {
        mouseDown = nil
        probed = false
        window = nil
        startFrame = nil
        zone = nil
        preview.hide()
    }
}

/// Translucent rectangle showing where a dragged window will snap.
@MainActor
final class SnapPreview {
    private lazy var panel: NSPanel = {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
        view.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.7).cgColor
        view.layer?.borderWidth = 2
        panel.contentView = view
        return panel
    }()

    func show(axFrame: CGRect) {
        let frame = ScreenGeometry.toAppKit(axFrame, primaryHeight: ScreenFrames.primaryHeight).insetBy(dx: 4, dy: 4)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
