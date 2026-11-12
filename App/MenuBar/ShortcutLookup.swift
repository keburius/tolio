import Carbon.HIToolbox
import AppKit
import OmniCore
import OmniPlatform

/// Finds the current shortcut of any declared hotkey action (feature on or off).
@MainActor
struct ShortcutLookup {
    let services: AppServices

    var allActions: [String: HotkeyAction] {
        var result: [String: HotkeyAction] = [AppHotkeys.controlPanel.id: AppHotkeys.controlPanel]
        for feature in services.features.features {
            for action in feature.declaredHotkeys { result[action.id] = action }
        }
        return result
    }

    func combo(for actionID: String?) -> KeyCombo? {
        guard let actionID, let action = allActions[actionID] else { return nil }
        return services.hotkeys.bindings.combo(for: action)
    }

    func text(for actionID: String?) -> String? { combo(for: actionID)?.displayString }

    /// Applies a combo as an NSMenuItem key equivalent so menus show it.
    static func apply(_ combo: KeyCombo?, to item: NSMenuItem) {
        guard let combo, let key = keyEquivalent(for: Int(combo.keyCode)) else { return }
        item.keyEquivalent = key
        var mask: NSEvent.ModifierFlags = []
        if combo.modifiers.contains(.command) { mask.insert(.command) }
        if combo.modifiers.contains(.option) { mask.insert(.option) }
        if combo.modifiers.contains(.control) { mask.insert(.control) }
        if combo.modifiers.contains(.shift) { mask.insert(.shift) }
        item.keyEquivalentModifierMask = mask
    }

    private static func keyEquivalent(for keyCode: Int) -> String? {
        let special: [Int: Int] = [
            kVK_LeftArrow: NSLeftArrowFunctionKey, kVK_RightArrow: NSRightArrowFunctionKey,
            kVK_UpArrow: NSUpArrowFunctionKey, kVK_DownArrow: NSDownArrowFunctionKey,
            kVK_Return: 0x0D, kVK_Delete: 0x08, kVK_Space: 0x20, kVK_Tab: 0x09, kVK_Escape: 0x1B,
        ]
        if let scalar = special[keyCode].flatMap(UnicodeScalar.init) { return String(scalar) }
        let name = KeyNames.name(for: UInt32(keyCode))
        return name.count == 1 ? name.lowercased() : nil
    }
}

/// App-level shortcuts (not owned by a feature).
enum AppHotkeys {
    static let owner: FeatureID = "app"
    /// ⌃⌥⌘M
    static let controlPanel = HotkeyAction(
        id: "app.controlPanel", title: L10n.App.openControlPanelAction,
        defaultCombo: KeyCombo(keyCode: UInt32(kVK_ANSI_M), modifiers: [.control, .option, .command])
    )
}
