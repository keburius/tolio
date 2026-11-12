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
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .firstThird: "First Third"
        case .centerThird: "Center Third"
        case .lastThird: "Last Third"
        case .firstTwoThirds: "First Two Thirds"
        case .lastTwoThirds: "Last Two Thirds"
        case .topLeft: "Top Left Quarter"
        case .topRight: "Top Right Quarter"
        case .bottomLeft: "Bottom Left Quarter"
        case .bottomRight: "Bottom Right Quarter"
        case .maximize: "Maximize"
        case .center: "Center"
        case .nextDisplay: "Move to Next Display"
        case .previousDisplay: "Move to Previous Display"
        case .restore: "Restore Previous Size"
        }
    }

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
