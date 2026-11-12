import Foundation
import OmniCore

/// What the palette shows next to an item.
public enum PaletteIcon: Sendable, Hashable {
    case file(URL)
    case symbol(String)
    /// A small image file shown as a thumbnail.
    case image(URL)
}

/// What happens when an item is chosen.
public enum PaletteAction: Sendable {
    case launchApp(URL)
    case openURL(URL)
    case command(Command)
    case copy(String)
    /// From a feature's `SearchProvider`; `alternate` runs on ⌘↩.
    case provided(primary: @MainActor @Sendable () -> Void, alternate: (@MainActor @Sendable () -> Void)?)
}

/// One searchable row in the palette.
public struct PaletteItem: Identifiable, Sendable {
    public enum Kind: String, Sendable {
        case answer, app, setting, command, provided

        var label: String {
            switch self {
            case .answer: L10n.Launcher.kindResult
            case .app: L10n.Launcher.kindApp
            case .setting: L10n.Launcher.kindSetting
            case .command: L10n.Launcher.kindCommand
            case .provided: ""
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
    /// Right-hand label; defaults to the kind's label.
    public let kindLabel: String

    public init(
        id: String, title: String, subtitle: String? = nil, icon: PaletteIcon,
        kind: Kind, keywords: [String] = [], action: PaletteAction, kindLabel: String? = nil
    ) {
        self.kindLabel = kindLabel ?? kind.label
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.kind = kind
        self.action = action
        targets = ([title] + keywords).map(FuzzyTarget.init)
    }
}

extension PaletteItem {
    /// Wraps a provider result.
    @MainActor
    init(result: SearchResult, provider: any SearchProvider) {
        let icon: PaletteIcon = switch result.icon {
        case let .symbol(name): .symbol(name)
        case let .file(url): .file(url)
        case let .image(url): .image(url)
        }
        self.init(
            id: "provided:\(provider.keyword):\(result.id)", title: result.title, subtitle: result.subtitle,
            icon: icon, kind: .provided,
            action: .provided(primary: result.primaryAction, alternate: result.alternateAction),
            kindLabel: provider.title
        )
    }
}
