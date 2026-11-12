import CoreGraphics
import Foundation
import OmniCore

/// A CGEventTap on the main run loop.
///
/// Safety rule: taps fail open. A `.listenOnly` tap can never block input.
/// A `.filtering` tap that macOS disables (timeout or user input) is **not**
/// re-enabled; it stops and reports through `onDisabled`, so the keyboard
/// keeps working. If the process dies, the tap dies with it.
@MainActor
public final class EventTap {
    public enum Mode {
        /// Observe only; events always pass through.
        case listenOnly
        /// The handler may swallow events by returning `true`.
        case filtering
    }

    public enum Failure: Error, CustomStringConvertible {
        case creationFailed
        public var description: String { "macOS refused to create the event tap. Check Accessibility permission." }
    }

    private let mask: CGEventMask
    private let mode: Mode
    private let handler: @MainActor (CGEventType, CGEvent) -> Bool
    private let onDisabled: @MainActor () -> Void
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private let log = Log.logger("eventtap")

    /// - Parameters:
    ///   - handler: return `true` to swallow the event (ignored for `.listenOnly`).
    ///     Must return quickly; do real work asynchronously.
    ///   - onDisabled: a filtering tap was disabled by the system and has stopped.
    public init(
        mask: CGEventMask, mode: Mode,
        handler: @escaping @MainActor (CGEventType, CGEvent) -> Bool,
        onDisabled: @escaping @MainActor () -> Void = {}
    ) {
        self.mask = mask
        self.mode = mode
        self.handler = handler
        self.onDisabled = onDisabled
    }

    public var isRunning: Bool { port != nil }

    public static func mask(_ types: CGEventType...) -> CGEventMask {
        types.reduce(0) { $0 | (1 << CGEventMask($1.rawValue)) }
    }

    public func start() throws {
        guard port == nil else { return }
        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: mode == .listenOnly ? .listenOnly : .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: info
        ) else { throw Failure.creationFailed }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
    }

    public func stop() {
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        port = nil
        source = nil
    }

    /// Returns false to swallow the event.
    fileprivate func shouldDeliver(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            switch mode {
            case .listenOnly:
                if let port { CGEvent.tapEnable(tap: port, enable: true) }
            case .filtering:
                log.error("Filtering event tap disabled by the system; failing open")
                stop()
                onDisabled()
            }
            return true
        }
        let swallow = handler(type, event)
        return !(swallow && mode == .filtering)
    }
}

/// The tap's source is on the main run loop, so this runs on the main thread.
private func eventTapCallback(
    _ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ info: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let address = UInt(bitPattern: info)
    // The event is only touched on this thread, before and after the
    // synchronous isolated call, so sharing it is safe.
    nonisolated(unsafe) let mainEvent = event
    let deliver = MainActor.assumeIsolated {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: address) else { return true }
        return Unmanaged<EventTap>.fromOpaque(pointer).takeUnretainedValue().shouldDeliver(type: type, event: mainEvent)
    }
    return deliver ? Unmanaged.passUnretained(event) : nil
}
