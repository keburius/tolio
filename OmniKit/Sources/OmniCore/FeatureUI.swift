import Foundation

// UI-facing descriptions a feature can provide. None of them changes what a
// feature does; they let the app show and reach it (menu bar icons, the
// control panel, Settings search, the shortcuts table, reset and erase).

/// A shortcut that isn't a key combination, e.g. "⌘ ⌘ hold" or "⌥ Tab".
public struct GestureShortcut: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    /// How to do it, e.g. "⌥ Tab".
    public let gesture: String
    /// Settings anchor where it can be changed, if any.
    public let settingsAnchor: String?

    public init(id: String, title: String, gesture: String, settingsAnchor: String? = nil) {
        self.id = id
        self.title = title
        self.gesture = gesture
        self.settingsAnchor = settingsAnchor
    }
}

/// One searchable setting on a feature's page.
public struct SettingsEntry: Hashable, Sendable {
    /// The view id the page scrolls to (`.settingsAnchor(_:)`).
    public let anchor: String
    /// The label as shown on the page.
    public let label: String
    /// Extra words people might search for.
    public let keywords: [String]

    public init(anchor: String, label: String, keywords: [String] = []) {
        self.anchor = anchor
        self.label = label
        self.keywords = keywords
    }
}

/// Identifiers of the optional menu bar icons, in their default order.
public enum QuickAccessID: String, Codable, CaseIterable, Sendable {
    case keepAwake = "keepawake"
    case screenshot
    case clipboard
    case recording
    case lockKeyboard = "lockkeyboard"
    case windowLayouts = "windowlayouts"
}

/// What a quick-access icon currently shows.
public struct QuickAccessState: Equatable, Sendable {
    public var isActive: Bool
    /// Short status, e.g. "until 18:30". Shown in tooltips and on tiles.
    public var detail: String?
    /// While set, the icon shows a running timer (recording).
    public var timerStart: Date?

    public init(isActive: Bool = false, detail: String? = nil, timerStart: Date? = nil) {
        self.isActive = isActive
        self.detail = detail
        self.timerStart = timerStart
    }

    public static let idle = QuickAccessState()
}

/// One entry of an options menu (right-click on an icon or tile).
public enum MenuEntry {
    case action(MenuAction)
    /// A disabled line describing state, e.g. "On, until 18:30".
    case header(String)
    case separator
    case submenu(title: String, entries: [MenuEntry])

    /// Titles, for tests and accessibility.
    public var title: String? {
        switch self {
        case let .action(action): action.title
        case let .header(text): text
        case .separator: nil
        case let .submenu(title, _): title
        }
    }
}

public struct MenuAction {
    public let title: String
    /// Hotkey action ID whose current shortcut is shown next to the title.
    public let shortcutID: String?
    public let isChecked: Bool
    public let isEnabled: Bool
    /// Asks for confirmation before running, with this question.
    public let confirmation: String?
    /// Small image shown before the title (thumbnails, file icons, symbols).
    public let icon: SearchResult.Icon?
    /// 1–9: the item also answers to ⌘1–⌘9 while the menu is open.
    public let commandDigit: Int?
    /// Longer text shown on hover.
    public let toolTip: String?
    public let perform: @MainActor () -> Void

    public init(
        _ title: String, shortcutID: String? = nil, isChecked: Bool = false, isEnabled: Bool = true,
        confirmation: String? = nil, icon: SearchResult.Icon? = nil, commandDigit: Int? = nil, toolTip: String? = nil,
        perform: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.shortcutID = shortcutID
        self.isChecked = isChecked
        self.isEnabled = isEnabled
        self.confirmation = confirmation
        self.icon = icon
        self.commandDigit = commandDigit
        self.toolTip = toolTip
        self.perform = perform
    }
}

/// A menu bar icon / control panel tile a feature offers.
@MainActor
public struct QuickAccessItem: Identifiable {
    public let id: QuickAccessID
    public let title: String
    public let symbolName: String
    /// Shown while `state().isActive` (e.g. a filled cup).
    public let activeSymbolName: String?
    /// What a left-click does, for Settings → Menu Bar ("turn on or off").
    public let clickHint: String
    /// Hotkey action ID of the main action, to show its shortcut.
    public let shortcutID: String?
    public let state: @MainActor () -> QuickAccessState
    public let primary: @MainActor () -> Void
    public let menu: @MainActor () -> [MenuEntry]
    /// If set, a left-click shows this menu under the icon instead of running `primary`.
    public let clickMenu: (@MainActor () -> [MenuEntry])?

    public init(
        id: QuickAccessID, title: String, symbolName: String, activeSymbolName: String? = nil,
        clickHint: String, shortcutID: String?,
        state: @escaping @MainActor () -> QuickAccessState = { .idle },
        primary: @escaping @MainActor () -> Void,
        menu: @escaping @MainActor () -> [MenuEntry],
        clickMenu: (@MainActor () -> [MenuEntry])? = nil
    ) {
        self.clickMenu = clickMenu
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.activeSymbolName = activeSymbolName
        self.clickHint = clickHint
        self.shortcutID = shortcutID
        self.state = state
        self.primary = primary
        self.menu = menu
    }
}

/// Implemented by System Stats so the app can show its numbers in the
/// control panel and hide its own menu bar item in one-icon mode.
@MainActor
public protocol StatsLineProviding: AnyObject {
    /// One line such as "CPU 12% · Memory 61% · Battery 84%", or nil before the first sample.
    var statsLine: String? { get }
    /// Hides or shows the feature's own menu bar item (one-icon mode).
    func setOwnMenuBarItemHidden(_ hidden: Bool)
    /// Samples now and keeps `statsLine` fresh while `active` (control panel open).
    func setLiveUpdates(_ active: Bool)
}

/// Lets a feature ask the app to show one of its menus (e.g. ⌃⌥V shows the
/// clipboard list): under its menu bar icon if shown, else at the pointer.
@MainActor
public enum QuickAccessCenter {
    /// Set by the app. Returns false if the menu couldn't be shown.
    public static var showClickMenu: ((QuickAccessID) -> Bool)?
}
