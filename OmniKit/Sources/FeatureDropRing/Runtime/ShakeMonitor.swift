import AppKit

/// Watches the pointer (listen-only, no permission needed) and reports a
/// shake. While `onlyWhileDragging`, only moves with the button held count.
@MainActor
final class ShakeMonitor {
    private var monitors: [Any] = []
    private var detector: ShakeDetector
    private let onlyWhileDragging: () -> Bool
    private let onShake: () -> Void

    init(sensitivity: Double, onlyWhileDragging: @escaping () -> Bool, onShake: @escaping () -> Void) {
        detector = ShakeDetector(sensitivity: sensitivity)
        self.onlyWhileDragging = onlyWhileDragging
        self.onShake = onShake
    }

    var sensitivity: Double {
        get { detector.sensitivity }
        set { detector.sensitivity = newValue }
    }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) { monitors.append(local) }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        detector.reset()
    }

    private func handle(_ event: NSEvent) {
        if onlyWhileDragging(), event.type != .leftMouseDragged {
            detector.reset()
            return
        }
        if detector.add(x: NSEvent.mouseLocation.x, time: event.timestamp) { onShake() }
    }
}
