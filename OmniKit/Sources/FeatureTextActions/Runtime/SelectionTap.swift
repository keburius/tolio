import AppKit
import Carbon.HIToolbox
import CoreGraphics
import OmniPlatform

/// Listen-only tap for the selection gestures. It can't block or change
/// input. Key events are only classified (navigation with ⇧ or "other");
/// their characters are never read, stored, or logged.
@MainActor
final class SelectionTap {
    enum Event {
        case trigger(SelectionTrigger.Input)
        /// AppKit coordinates.
        case mouseDown(CGPoint)
    }

    private var tap: EventTap?
    private let onEvent: (Event) -> Void
    private static let navigationKeys: Set<Int> = [
        kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow, kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown,
    ]

    init(onEvent: @escaping (Event) -> Void) {
        self.onEvent = onEvent
    }

    func start() throws {
        let mask = EventTap.mask(.leftMouseDown, .leftMouseUp, .leftMouseDragged, .keyDown, .keyUp, .scrollWheel)
        let tap = EventTap(mask: mask, mode: .listenOnly) { [weak self] type, event in
            self?.handle(type, event)
            return false
        }
        try tap.start()
        self.tap = tap
    }

    func stop() {
        tap?.stop()
        tap = nil
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        guard !KeySender.isOwnEvent(event) else { return }
        switch type {
        case .leftMouseDown:
            let point = Self.appKitPoint(event.location)
            let clicks = Int(event.getIntegerValueField(.mouseEventClickState))
            onEvent(.mouseDown(point))
            onEvent(.trigger(.mouseDown(point, clickCount: clicks, shift: event.flags.contains(.maskShift))))
        case .leftMouseDragged:
            onEvent(.trigger(.mouseDragged(Self.appKitPoint(event.location))))
        case .leftMouseUp:
            onEvent(.trigger(.mouseUp(Self.appKitPoint(event.location))))
        case .keyDown:
            let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
            // ⇧+navigation extends a selection; don't close the popup for it.
            if event.flags.contains(.maskShift) && Self.navigationKeys.contains(key) { return }
            onEvent(.trigger(.keyDown))
        case .keyUp:
            let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
            if event.flags.contains(.maskShift) && Self.navigationKeys.contains(key) {
                onEvent(.trigger(.shiftNavigationKeyUp))
            }
        case .scrollWheel:
            onEvent(.trigger(.scroll))
        default:
            break
        }
    }

    /// CG (top-left of primary display) → AppKit (bottom-left).
    static func appKitPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    static func appKitRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }
}
