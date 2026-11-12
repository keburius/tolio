import Foundation
import OmniCore

/// What the palette shows next to an item.
public enum PaletteIcon: Sendable, Hashable {
    case file(URL)
    case symbol(String)
}

/// What happens when an item is chosen.
public enum PaletteAction: Sendable {
    case launchApp(URL)
    case openURL(URL)
    case command(Command)
    case copy(String)
}

/// One searchable row in the palette.
public struct PaletteItem: Identifiable, Sendable {
    public enum Kind: String, Sendable {
        case answer, app, setting, command

        var label: String {
            switch self {
            case .answer: "Result"
            case .app: "Application"
            case .setting: "System Settings"
            case .command: "Command"
            }
        }
    }

    public let id: String
    public let title: String
    public let subtitle: String?
    public let icon: PaletteIcon
    public let kind: Kind
    public let action: PaletteAction
    /// Title first, then keywords.
    let targets: [FuzzyTarget]
    /// Matched title characters for highlighting; set by the ranker.
    public internal(set) var highlighted: [Int] = []

    public init(
        id: String, title: String, subtitle: String? = nil, icon: PaletteIcon,
        kind: Kind, keywords: [String] = [], action: PaletteAction
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.kind = kind
        self.action = action
        targets = ([title] + keywords).map(FuzzyTarget.init)
    }

    public var kindLabel: String { kind.label }
}
