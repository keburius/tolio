import Foundation
import OmniCore

/// macOS's own "Save picture of selected area as a file" shortcut (⇧⌘4 unless
/// changed). When it's on and Tolio's area shortcut is the same, macOS takes
/// the key press first, so Settings asks the user to switch macOS's off.
/// Read only: Tolio never changes system shortcuts.
public enum MacScreenshotShortcut {
    /// Symbolic hotkey number of "Save picture of selected area as a file".
    static let selectedAreaID = "30"
    static let standard = KeyCombo(keyCode: 21, modifiers: [.shift, .command])

    /// The macOS shortcut when it's switched on, from the
    /// `AppleSymbolicHotKeys` dictionary (nil entry = macOS default, on).
    public static func activeCombo(symbolicHotKeys: [String: Any]?) -> KeyCombo? {
        guard let entry = symbolicHotKeys?[selectedAreaID] as? [String: Any] else { return standard }
        let enabled = (entry["enabled"] as? Bool) ?? (entry["enabled"] as? Int).map { $0 != 0 } ?? true
        guard enabled else { return nil }
        guard let value = entry["value"] as? [String: Any],
              let parameters = value["parameters"] as? [Int], parameters.count >= 3 else { return standard }
        return KeyCombo(keyCode: UInt32(parameters[1]), modifiers: modifiers(cocoaFlags: parameters[2]))
    }

    /// True when macOS's area shortcut is on and equals `combo`.
    public static func conflicts(with combo: KeyCombo?, symbolicHotKeys: [String: Any]?) -> Bool {
        guard let combo, let mac = activeCombo(symbolicHotKeys: symbolicHotKeys) else { return false }
        return mac == combo
    }

    /// The real check, reading the user's system shortcut settings.
    public static func conflicts(with combo: KeyCombo?) -> Bool {
        let hotKeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys")
        return conflicts(with: combo, symbolicHotKeys: hotKeys)
    }

    static func modifiers(cocoaFlags flags: Int) -> ModifierSet {
        var set: ModifierSet = []
        if flags & (1 << 17) != 0 { set.insert(.shift) }
        if flags & (1 << 18) != 0 { set.insert(.control) }
        if flags & (1 << 19) != 0 { set.insert(.option) }
        if flags & (1 << 20) != 0 { set.insert(.command) }
        return set
    }
}
