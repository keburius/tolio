import AppKit
import Observation
import OmniCore
import OmniPlatform

/// Everything the control panel shows, gathered when it opens.
@MainActor
@Observable
final class ControlPanelModel {
    enum ActionState: Equatable {
        case ready(active: Bool)
        case recording(elapsed: String)
        case off(feature: String)
        case needsPermission(feature: String, permission: Permission)
    }

    /// What a button does: a feature's quick action (menu bar icon) or a command.
    enum Kind: Equatable {
        case quickAccess(QuickAccessID)
        case command(String)
    }

    /// One button in the grid or the More list.
    struct Action: Identifiable {
        let id: String
        let featureID: FeatureID
        let title: String
        let kind: Kind
        let shortcut: String?
        var state: ActionState
    }

    /// A line in "Running now".
    struct Running: Identifiable, Equatable {
        enum Control: Equatable { case toggle(isOn: Bool), button(String), none }
        let id: String
        let featureID: FeatureID
        let title: String
        let detail: String
        let control: Control
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

    var grid: [Action] = []
    var more: [Action] = []
    var running: [Running] = []
    /// Only the Window Layouts icon's grid uses this.
    var window: WindowState = .none
    var layouts: [Layout] = []
    var focus = ControlPanelFocus(rows: [])
    /// Shows a "Turn On" prompt below the grid for this off action.
    var turnOnPrompt: String?
    var showsFocusRing = false

    /// The grid (two rows of four) and the More list, as in the design.
    struct Spec {
        let id: String
        let featureID: FeatureID
        let title: () -> String
        let kind: Kind
    }

    static let gridSpecs: [Spec] = [
        .init(id: "clipboard", featureID: "clipboard", title: { L10n.PanelUI.clipboard }, kind: .quickAccess(.clipboard)),
        .init(id: "screenshot", featureID: "screenshots", title: { L10n.PanelUI.screenshot }, kind: .quickAccess(.screenshot)),
        .init(id: "record", featureID: "screenshots", title: { L10n.PanelUI.record }, kind: .quickAccess(.recording)),
        .init(id: "layouts", featureID: "windows", title: { L10n.PanelUI.layouts }, kind: .quickAccess(.windowLayouts)),
        .init(id: "dropring", featureID: "dropring", title: { L10n.PanelUI.dropRing }, kind: .command("dropring.show")),
        .init(id: "reminder", featureID: "deskminder", title: { L10n.PanelUI.reminder }, kind: .command("deskminder.show")),
        .init(id: "island", featureID: "island", title: { L10n.PanelUI.island }, kind: .command("island.open")),
        .init(id: "lock", featureID: "keyboardclean", title: { L10n.PanelUI.lockKeys }, kind: .quickAccess(.lockKeyboard)),
    ]

    static let moreSpecs: [Spec] = [
        .init(id: "capturetext", featureID: "capturetext", title: { L10n.PanelUI.captureText }, kind: .quickAccess(.captureText)),
        .init(id: "note", featureID: "stickynotes", title: { L10n.PanelUI.newNote }, kind: .command("stickynotes.new")),
        .init(id: "cheatsheet", featureID: "shortcuts", title: { L10n.PanelUI.cheatSheet }, kind: .command("shortcuts.show")),
    ]

    static let layoutSpecs: [(command: String, title: () -> String, span: (CGFloat, CGFloat))] = [
        ("windows.leftHalf", { L10n.Panel.leftHalf }, (0, 0.5)),
        ("windows.rightHalf", { L10n.Panel.rightHalf }, (0.5, 0.5)),
        ("windows.firstThird", { L10n.Panel.leftThird }, (0, 1.0 / 3)),
        ("windows.centerThird", { L10n.Panel.centerThird }, (1.0 / 3, 1.0 / 3)),
        ("windows.lastThird", { L10n.Panel.rightThird }, (2.0 / 3, 1.0 / 3)),
        ("windows.maximize", { L10n.Panel.maximize }, (0, 1)),
    ]

    func action(_ id: String) -> Action? {
        grid.first { $0.id == id } ?? more.first { $0.id == id }
    }

    func rebuildFocus() {
        var rows: [[ControlPanelFocus.Target]] = []
        // The grid's two rows of four, so up/down keeps the column.
        stride(from: 0, to: grid.count, by: 4).forEach { start in
            rows.append(grid[start ..< min(start + 4, grid.count)].map { .action($0.id) })
        }
        rows += running.filter { $0.control != .none }.map { [.running($0.id)] }
        rows += more.map { [.action($0.id)] }
        rows.append([.settings, .quit])
        let previous = focus.current
        focus = ControlPanelFocus(rows: rows)
        if let previous { focus.focus(previous) }
    }
}
