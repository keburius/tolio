import Foundation
import OmniCore

/// macOS's own "Save picture of selected area as a file" shortcut (⇧⌘4 unless
/// changed). When it's on and Tolio's area shortcut is the same, macOS takes
/// the key press first, so Settings asks the user to switch macOS's off.
/// Tolio changes it only when the user clicks "Use ⇧⌘4 for Tolio" (and
/// confirms), and can turn it back on.
public enum MacScreenshotShortcut {
    static var domain: CFString { "com.apple.symbolichotkeys" as CFString }
    static var dictionaryKey: CFString { "AppleSymbolicHotKeys" as CFString }
    /// Applies changed system shortcuts without logging out (what System Settings uses).
    static let activateSettings = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
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
        CFPreferencesAppSynchronize(domain)
        let hotKeys = CFPreferencesCopyAppValue(dictionaryKey, domain) as? [String: Any]
        return conflicts(with: combo, symbolicHotKeys: hotKeys)
    }

    /// `symbolicHotKeys` with only the selected-area entry's `enabled` changed
    /// (its key combination is kept; macOS's default is filled in if missing).
    static func updating(_ symbolicHotKeys: [String: Any]?, enabled: Bool) -> [String: Any] {
        var all = symbolicHotKeys ?? [:]
        var entry = all[selectedAreaID] as? [String: Any] ?? [:]
        if entry["value"] == nil {
            entry["value"] = ["type": "standard", "parameters": [52, 21, 1_179_648]] as [String: Any]
        }
        entry["enabled"] = enabled
        all[selectedAreaID] = entry
        return all
    }

    /// Switches macOS's selected-area shortcut on or off for this user and
    /// applies it right away. Returns false if it couldn't be applied now
    /// (it then takes effect after logging out and in).
    @discardableResult
    public static func setMacShortcutEnabled(_ enabled: Bool) -> Bool {
        let current = CFPreferencesCopyAppValue(dictionaryKey, domain) as? [String: Any]
        let updated = updating(current, enabled: enabled)
        CFPreferencesSetAppValue(dictionaryKey, updated as CFDictionary, domain)
        CFPreferencesAppSynchronize(domain)
        Log.logger("screenshots").notice("macOS selected-area screenshot shortcut turned \(enabled ? "on" : "off", privacy: .public)")
        guard FileManager.default.isExecutableFile(atPath: activateSettings) else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: activateSettings)
        process.arguments = ["-u"]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
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
