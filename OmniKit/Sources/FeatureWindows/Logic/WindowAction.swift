import OmniCore

/// Something the user can do to the focused window.
public enum WindowAction: String, CaseIterable, Codable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case firstThird, centerThird, lastThird, firstTwoThirds, lastTwoThirds
    case topLeft, topRight, bottomLeft, bottomRight
    case maximize, center
    case nextDisplay, previousDisplay
    case restore

    public var title: String {
        switch self {
        case .leftHalf: L10n.Windows.leftHalf
        case .rightHalf: L10n.Windows.rightHalf
        case .topHalf: L10n.Windows.topHalf
        case .bottomHalf: L10n.Windows.bottomHalf
        case .firstThird: L10n.Windows.firstThird
        case .centerThird: L10n.Windows.centerThird
        case .lastThird: L10n.Windows.lastThird
        case .firstTwoThirds: L10n.Windows.firstTwoThirds
        case .lastTwoThirds: L10n.Windows.lastTwoThirds
        case .topLeft: L10n.Windows.topLeft
        case .topRight: L10n.Windows.topRight
        case .bottomLeft: L10n.Windows.bottomLeft
        case .bottomRight: L10n.Windows.bottomRight
        case .maximize: L10n.Windows.maximize
        case .center: L10n.Windows.center
        case .nextDisplay: L10n.Windows.nextDisplay
        case .previousDisplay: L10n.Windows.previousDisplay
        case .restore: L10n.Windows.restore
        }
    }

    /// ID of this action's hotkey and command.
    public var hotkeyID: String { "windows.\(rawValue)" }

    /// The global shortcut registered for this action.
    public var hotkey: HotkeyAction { HotkeyAction(id: hotkeyID, title: title, defaultCombo: defaultCombo) }

    public var symbolName: String {
        switch self {
        case .leftHalf: "rectangle.lefthalf.filled"
        case .rightHalf: "rectangle.righthalf.filled"
        case .topHalf: "rectangle.tophalf.filled"
        case .bottomHalf: "rectangle.bottomhalf.filled"
        case .firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds: "rectangle.split.3x1"
        case .topLeft: "rectangle.inset.topleft.filled"
        case .topRight: "rectangle.inset.topright.filled"
        case .bottomLeft: "rectangle.inset.bottomleft.filled"
        case .bottomRight: "rectangle.inset.bottomright.filled"
        case .maximize: "rectangle.inset.filled"
        case .center: "rectangle.center.inset.filled"
        case .nextDisplay, .previousDisplay: "display.2"
        case .restore: "arrow.uturn.backward.square"
        }
    }

    /// Default shortcuts, ⌃⌥ plus a key (display moves add ⌘).
    public var defaultCombo: KeyCombo? {
        let ctrlOpt: ModifierSet = [.control, .option]
        let code: UInt32? = switch self {
        case .leftHalf: 123       // ←
        case .rightHalf: 124      // →
        case .topHalf: 126        // ↑
        case .bottomHalf: 125     // ↓
        case .topLeft: 32         // U
        case .topRight: 34        // I
        case .bottomLeft: 38      // J
        case .bottomRight: 40     // K
        case .firstThird: 2       // D
        case .centerThird: 3      // F
        case .lastThird: 5        // G
        case .firstTwoThirds: 14  // E
        case .lastTwoThirds: 17   // T
        case .maximize: 36        // ↩
        case .center: 8           // C
        case .restore: 51         // ⌫
        case .nextDisplay, .previousDisplay: nil
        }
        if let code { return KeyCombo(keyCode: code, modifiers: ctrlOpt) }
        switch self {
        case .nextDisplay: return KeyCombo(keyCode: 124, modifiers: [.control, .option, .command])
        case .previousDisplay: return KeyCombo(keyCode: 123, modifiers: [.control, .option, .command])
        default: return nil
        }
    }

    /// Edges the window should stay aligned to if it can't shrink to the
    /// target size (e.g. a right-half window keeps its right edge).
    var anchorsRight: Bool {
        [.rightHalf, .lastThird, .lastTwoThirds, .topRight, .bottomRight].contains(self)
    }

    var anchorsBottom: Bool {
        [.bottomHalf, .bottomLeft, .bottomRight].contains(self)
    }

    /// Centered horizontally/vertically when too large.
    var centersHorizontally: Bool { [.centerThird, .center, .topHalf, .bottomHalf, .maximize].contains(self) }
    var centersVertically: Bool { [.center, .maximize].contains(self) }
}
