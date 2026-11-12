import Observation

/// An entry the command palette can show and run. Every feature registers its
/// commands here.
public struct Command: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let keywords: [String]
    /// SF Symbol name.
    public let symbolName: String
    public let action: @MainActor @Sendable () -> Void

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        keywords: [String] = [],
        symbolName: String,
        action: @escaping @MainActor @Sendable () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.symbolName = symbolName
        self.action = action
    }
}

/// Registers palette commands and search providers on behalf of a feature.
@MainActor
public protocol CommandRegistering: AnyObject {
    func register(_ command: Command, owner: FeatureID)
    func registerProvider(_ provider: any SearchProvider, owner: FeatureID)
    /// Removes the owner's commands and providers.
    func unregisterAll(owner: FeatureID)
    /// Commands of all enabled features, for the palette to search.
    var allCommands: [Command] { get }
    var allProviders: [any SearchProvider] { get }
    /// Opens the palette with `query` prefilled, if the palette is enabled.
    func openPalette(query: String)
    /// Set by the palette feature while enabled.
    var paletteHandler: (@MainActor (String) -> Void)? { get set }
}

/// Holds the commands and search providers of all enabled features.
@MainActor
@Observable
public final class CommandRegistry: CommandRegistering {
    public private(set) var commandsByOwner: [FeatureID: [Command]] = [:]
    @ObservationIgnored private var providersByOwner: [FeatureID: [any SearchProvider]] = [:]
    @ObservationIgnored public var paletteHandler: (@MainActor (String) -> Void)?

    public init() {}

    public var allProviders: [any SearchProvider] {
        providersByOwner.keys.sorted { $0.rawValue < $1.rawValue }.flatMap { providersByOwner[$0] ?? [] }
    }

    public func registerProvider(_ provider: any SearchProvider, owner: FeatureID) {
        providersByOwner[owner, default: []].removeAll { $0.keyword == provider.keyword }
        providersByOwner[owner, default: []].append(provider)
    }

    public func openPalette(query: String) {
        paletteHandler?(query)
    }

    /// All commands, sorted by title.
    public var allCommands: [Command] {
        commandsByOwner.values.joined().sorted { $0.title < $1.title }
    }

    /// Adds a command, replacing one with the same id from the same owner.
    public func register(_ command: Command, owner: FeatureID) {
        var list = commandsByOwner[owner, default: []]
        list.removeAll { $0.id == command.id }
        list.append(command)
        commandsByOwner[owner] = list
    }

    public func unregisterAll(owner: FeatureID) {
        commandsByOwner[owner] = nil
        providersByOwner[owner] = nil
    }
}
