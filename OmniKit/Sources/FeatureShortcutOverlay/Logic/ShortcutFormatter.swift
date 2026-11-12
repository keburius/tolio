import Foundation

/// Turns the AX menu-item shortcut attributes into a display string like "⌥⇧⌘S".
public enum ShortcutFormatter {
    /// `AXMenuItemCmdModifiers` bits (Carbon `kMenu*Modifier`). Command is
    /// implied unless `noCommand` is set.
    public struct Modifiers: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let shift = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let noCommand = Modifiers(rawValue: 1 << 3)
        /// fn / 🌐 (not in Carbon's list; seen on e.g. "Emoji & Symbols" = 24).
        public static let function = Modifiers(rawValue: 1 << 4)
    }

    /// Modifier symbols in Apple's order: fn, then ⌃⌥⇧⌘.
    public static func modifierSymbols(_ raw: Int) -> String {
        let mods = Modifiers(rawValue: raw)
        var result = mods.contains(.function) ? "fn " : ""
        if mods.contains(.control) { result += "⌃" }
        if mods.contains(.option) { result += "⌥" }
        if mods.contains(.shift) { result += "⇧" }
        if !mods.contains(.noCommand) { result += "⌘" }
        return result
    }

    /// The full shortcut, or nil if the item has none.
    public static func format(cmdChar: String?, modifiers: Int?, glyph: Int?, virtualKey: Int?) -> String? {
        guard let key = keyName(cmdChar: cmdChar, glyph: glyph, virtualKey: virtualKey) else { return nil }
        return modifierSymbols(modifiers ?? 0) + key
    }

    /// Glyph first (it is what the menu draws), then the character, then the key code.
    static func keyName(cmdChar: String?, glyph: Int?, virtualKey: Int?) -> String? {
        if let glyph, glyph != 0, let name = glyphNames[glyph] { return name }
        if let cmdChar, let scalar = cmdChar.unicodeScalars.first, cmdChar.unicodeScalars.count == 1 {
            if let name = characterNames[scalar.value] { return name }
            if (0xF704...0xF71F).contains(scalar.value) { return "F\(scalar.value - 0xF704 + 1)" }
            if scalar.properties.generalCategory == .control || (0xF700...0xF8FF).contains(scalar.value) { return nil }
            return cmdChar.uppercased()
        }
        if let cmdChar, !cmdChar.isEmpty, cmdChar.trimmingCharacters(in: .whitespaces).count == cmdChar.count {
            return cmdChar.uppercased()
        }
        if let virtualKey, let name = virtualKeyNames[virtualKey] { return name }
        return nil
    }

    /// Carbon `kMenu*Glyph` values (Menus.h).
    static let glyphNames: [Int: String] = [
        0x02: "⇥", 0x03: "⇤", 0x04: "⌤", 0x05: "⇧", 0x06: "⌃", 0x07: "⌥", 0x09: "Space",
        0x0A: "⌦", 0x0B: "↩", 0x0C: "↩", 0x0D: "↩", 0x11: "⌘", 0x17: "⌫", 0x1B: "⎋", 0x1C: "⌧",
        0x62: "⇞", 0x63: "⇪", 0x64: "←", 0x65: "→", 0x66: "↖", 0x67: "?⃝", 0x68: "↑", 0x69: "↘",
        0x6A: "↓", 0x6B: "⇟", 0x6E: "⌽",
        0x6F: "F1", 0x70: "F2", 0x71: "F3", 0x72: "F4", 0x73: "F5", 0x74: "F6", 0x75: "F7",
        0x76: "F8", 0x77: "F9", 0x78: "F10", 0x79: "F11", 0x7A: "F12", 0x87: "F13", 0x88: "F14",
        0x89: "F15", 0x8C: "⏏", 0x8F: "F16", 0x90: "F17", 0x91: "F18", 0x92: "F19",
    ]

    /// Control and AppKit function-key characters (NSUpArrowFunctionKey etc.).
    static let characterNames: [UInt32: String] = [
        0x03: "⌤", 0x08: "⌫", 0x09: "⇥", 0x0D: "↩", 0x1B: "⎋", 0x20: "Space", 0x7F: "⌫",
        0xF700: "↑", 0xF701: "↓", 0xF702: "←", 0xF703: "→", 0xF728: "⌦", 0xF729: "↖",
        0xF72B: "↘", 0xF72C: "⇞", 0xF72D: "⇟",
    ]

    /// Fallback when only `AXMenuItemCmdVirtualKey` is set (ANSI names).
    static let virtualKeyNames: [Int: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 117: "⌦", 115: "↖", 119: "↘",
        116: "⇞", 121: "⇟", 123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}
