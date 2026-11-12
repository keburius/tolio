import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Posts synthetic keystrokes. Requires Accessibility.
///
/// Every posted event carries `eventMarker` in `eventSourceUserData`, so
/// Omni's own event taps can recognize and ignore them.
@MainActor
public enum KeySender {
    public static let eventMarker: Int64 = 0x4F4D_4E49

    /// True if `event` was posted by `KeySender`.
    public static func isOwnEvent(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == eventMarker
    }

    public static func press(_ keyCode: CGKeyCode, flags: CGEventFlags = [], times: Int = 1) {
        let source = CGEventSource(stateID: .privateState)
        for _ in 0..<max(0, times) {
            for down in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { continue }
                event.flags = flags
                event.setIntegerValueField(.eventSourceUserData, value: eventMarker)
                event.post(tap: .cghidEventTap)
            }
        }
    }

    public static func backspace(times: Int) { press(CGKeyCode(kVK_Delete), times: times) }
    public static func left(times: Int) { press(CGKeyCode(kVK_LeftArrow), times: times) }

    /// ⌘V using the key that types "v" in the current ASCII-capable layout
    /// (differs on Dvorak and similar; non-Latin layouts use their ASCII fallback).
    public static func paste() {
        press(keyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
    }

    /// ⌘C, layout-aware like `paste()`.
    public static func copy() {
        press(keyCode(for: "c") ?? CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
    }

    /// Finds the virtual key code that produces `character` without modifiers.
    static func keyCode(for character: Character) -> CGKeyCode? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        let target = String(character)
        return data.withUnsafeBytes { buffer -> CGKeyCode? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for code in 0..<128 {
                var deadKeys: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars
                )
                if status == noErr, length > 0, String(utf16CodeUnits: chars, count: length) == target {
                    return CGKeyCode(code)
                }
            }
            return nil
        }
    }
}
