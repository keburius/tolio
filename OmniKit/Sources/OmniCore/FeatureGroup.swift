/// The sections features are listed under in Settings, the setup guide and
/// the website, in display order.
public enum FeatureGroup: String, CaseIterable, Sendable {
    /// Clipboard History.
    case clipboard
    /// Window Layouts and the Window Switcher.
    case windows
    /// Lock Keyboard.
    case keyboard
    /// Screenshots, screen recording and Capture Text.
    case capture
    /// Drop Ring.
    case files
    /// Notch Island.
    case island
    /// Energy Mode.
    case energy
    /// Everything else: Sticky Notes, the shortcut cheat sheet, text
    /// selection actions, System Stats.
    case extras

    public var title: String {
        switch self {
        case .clipboard: L10n.Groups.clipboard
        case .windows: L10n.Groups.windows
        case .keyboard: L10n.Groups.keyboard
        case .capture: L10n.Groups.capture
        case .files: L10n.Groups.files
        case .island: L10n.Groups.island
        case .energy: L10n.Groups.energy
        case .extras: L10n.Groups.extras
        }
    }

    /// One line under the group's title.
    public var summary: String {
        switch self {
        case .clipboard: L10n.Groups.clipboardSummary
        case .windows: L10n.Groups.windowsSummary
        case .keyboard: L10n.Groups.keyboardSummary
        case .capture: L10n.Groups.captureSummary
        case .files: L10n.Groups.filesSummary
        case .island: L10n.Groups.islandSummary
        case .energy: L10n.Groups.energySummary
        case .extras: L10n.Groups.extrasSummary
        }
    }

    /// SF Symbol name.
    public var symbolName: String {
        switch self {
        case .clipboard: "doc.on.clipboard"
        case .windows: "rectangle.split.2x1"
        case .keyboard: "keyboard"
        case .capture: "camera.viewfinder"
        case .files: "tray.and.arrow.down.fill"
        case .island: "rectangle.topthird.inset.filled"
        case .energy: "bolt.fill"
        case .extras: "square.grid.2x2"
        }
    }
}
