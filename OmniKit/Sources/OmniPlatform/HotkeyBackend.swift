import Carbon.HIToolbox
import OmniCore

/// Low-level hotkey registration. Abstracted so `HotkeyManager` can be tested.
@MainActor
public protocol HotkeyBackend: AnyObject {
    /// Called with the id passed to `register` when that hotkey is pressed.
    var onPress: (@MainActor (UInt32) -> Void)? { get set }
    /// Returns `noErr` (0) on success, otherwise an `OSStatus`.
    func register(id: UInt32, combo: KeyCombo) -> Int32
    func unregister(id: UInt32)
}

/// Global hotkeys via Carbon `RegisterEventHotKey`. Needs no permission.
/// The event handler is installed only while at least one hotkey is registered.
@MainActor
public final class CarbonHotkeyBackend: HotkeyBackend {
    public var onPress: (@MainActor (UInt32) -> Void)?

    private static let signature: OSType = 0x4F4D_4E49 // "OMNI"
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlerRef: EventHandlerRef?

    public init() {}

    public func register(id: UInt32, combo: KeyCombo) -> Int32 {
        unregister(id: id)
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            combo.keyCode, combo.modifiers.carbonFlags, hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        if status == noErr, let ref {
            refs[id] = ref
        } else {
            removeHandlerIfIdle()
        }
        return status
    }

    public func unregister(id: UInt32) {
        guard let ref = refs.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(ref)
        removeHandlerIfIdle()
    }

    fileprivate func handlePress(id: UInt32) {
        onPress?(id)
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), carbonHotkeyCallback, 1, &spec, context, &handlerRef)
    }

    private func removeHandlerIfIdle() {
        guard refs.isEmpty, let handlerRef else { return }
        RemoveEventHandler(handlerRef)
        self.handlerRef = nil
    }
}

/// Carbon delivers hotkey events on the main thread's event loop.
private func carbonHotkeyCallback(
    _ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
    )
    guard status == noErr else { return status }
    let id = hotKeyID.id
    // Pass the address as an integer: raw pointers aren't Sendable, but the
    // backend is owned by the app for the whole process lifetime.
    let address = UInt(bitPattern: userData)
    MainActor.assumeIsolated {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: address) else { return }
        Unmanaged<CarbonHotkeyBackend>.fromOpaque(pointer).takeUnretainedValue().handlePress(id: id)
    }
    return noErr
}
