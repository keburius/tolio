/// Modifier keys of a shortcut.
public struct ModifierSet: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = ModifierSet(rawValue: 1 << 0)
    public static let option = ModifierSet(rawValue: 1 << 1)
    public static let shift = ModifierSet(rawValue: 1 << 2)
    public static let command = ModifierSet(rawValue: 1 << 3)

    /// Symbols in the standard macOS order: ⌃⌥⇧⌘.
    public var symbols: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }

    /// Carbon modifier flags (`cmdKey`, `shiftKey`, `optionKey`, `controlKey`).
    public var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= 1 << 8 }
        if contains(.shift) { flags |= 1 << 9 }
        if contains(.option) { flags |= 1 << 11 }
        if contains(.control) { flags |= 1 << 12 }
        return flags
    }
}

/// Why a key combination can't be used as a global shortcut.
public enum KeyComboIssue: Equatable, Sendable {
    /// Needs ⌘ or ⌃ (bare keys would steal normal typing).
    case needsModifier
    /// macOS 15+ refuses global shortcuts that use only ⌥ or ⌥⇧.
    case optionOnlyNotAllowed

    public var message: String {
        switch self {
        case .needsModifier: "Add ⌘ or ⌃ to the shortcut."
        case .optionOnlyNotAllowed: "macOS doesn't allow shortcuts with only ⌥ or ⌥⇧. Add ⌘ or ⌃."
        }
    }
}

/// A key plus modifiers, identified by the hardware virtual key code (`kVK_*`).
public struct KeyCombo: Codable, Hashable, Sendable, CustomStringConvertible {
    public var keyCode: UInt32
    public var modifiers: ModifierSet

    public init(keyCode: UInt32, modifiers: ModifierSet) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// For example "⌃⌥⌘T".
    public var displayString: String { modifiers.symbols + KeyNames.name(for: keyCode) }
    public var description: String { displayString }

    public var isFunctionKey: Bool { KeyNames.functionKeyCodes.contains(keyCode) }

    /// `nil` if the combo can be registered as a global shortcut.
    public var issue: KeyComboIssue? {
        if isFunctionKey { return nil }
        if modifiers.isDisjoint(with: [.command, .control]) {
            return modifiers.contains(.option) ? .optionOnlyNotAllowed : .needsModifier
        }
        return nil
    }
}

/// Display names for virtual key codes on an ANSI layout.
/// Layout-aware names (e.g. AZERTY) are deferred; key codes are layout-independent.
public enum KeyNames {
    static let functionKeyCodes: Set<UInt32> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90,
    ]

    private static let table: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
        115: "↖", 116: "⇞", 117: "⌦", 119: "↘", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func name(for keyCode: UInt32) -> String {
        table[keyCode] ?? "Key \(keyCode)"
    }
}
