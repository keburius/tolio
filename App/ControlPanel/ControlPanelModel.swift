import AppKit
import Observation
import OmniCore
import OmniPlatform

/// Everything the control panel shows, gathered when it opens.
@MainActor
@Observable
final class ControlPanelModel {
    enum TileState: Equatable {
        case ready(active: Bool, detail: String?)
        case recording(elapsed: String)
        case off(feature: String)
        case needsPermission(feature: String, permission: Permission)
    }

    struct Tile: Identifiable {
        let id: QuickAccessID
        let title: String
        let symbol: String
        let shortcut: String?
        var state: TileState
    }

    enum ClipsState {
        case items([SearchResult])
        case empty
        case featureOff(String)
    }

    struct Layout: Identifiable {
        let id: String // command ID
        let title: String
        let shortcut: String?
        /// Fraction of the screen the window takes: x, width.
        let span: (x: CGFloat, width: CGFloat)
    }

    enum WindowState {
        case window(app: String, title: String?)
        case none
        case featureOff(String)
    }

    var tiles: [Tile] = []
    var clips: ClipsState = .empty
    /// Only the Window Layouts icon's grid uses this; the control panel no longer has a window section.
    var window: WindowState = .none
    var layouts: [Layout] = []
    var statsLine: String?
    var focus = ControlPanelFocus(rows: [])
    /// Shows a "Turn on" prompt below the tiles for this off feature.
    var turnOnPrompt: QuickAccessID?
    var showsFocusRing = false

    /// How many recent copies the panel lists (keys 1–9 and 0 open them).
    static let recentCount = 10

    static let tileOrder: [QuickAccessID] = [.screenshot, .recording, .clipboard, .keepAwake, .lockKeyboard]

    static let layoutSpecs: [(command: String, title: () -> String, span: (CGFloat, CGFloat))] = [
        ("windows.leftHalf", { L10n.Panel.leftHalf }, (0, 0.5)),
        ("windows.rightHalf", { L10n.Panel.rightHalf }, (0.5, 0.5)),
        ("windows.firstThird", { L10n.Panel.leftThird }, (0, 1.0 / 3)),
        ("windows.centerThird", { L10n.Panel.centerThird }, (1.0 / 3, 1.0 / 3)),
        ("windows.lastThird", { L10n.Panel.rightThird }, (2.0 / 3, 1.0 / 3)),
        ("windows.maximize", { L10n.Panel.maximize }, (0, 1)),
    ]

    func rebuildFocus() {
        var rows: [[ControlPanelFocus.Target]] = [tiles.map { .tile($0.id) }]
        if case let .items(results) = clips {
            // The list is vertical: "Show All" first (it sits in the header), then one row per copy.
            rows.append([.showAllClips])
            rows += results.indices.map { [.recent($0)] }
        }
        rows.append([.settings, .quit])
        let previous = focus.current
        focus = ControlPanelFocus(rows: rows)
        if let previous { focus.focus(previous) }
    }
}
