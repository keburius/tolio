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

/// Registers palette commands on behalf of a feature.
@MainActor
public protocol CommandRegistering: AnyObject {
    func register(_ command: Command, owner: FeatureID)
    func unregisterAll(owner: FeatureID)
}

/// Holds the commands of all enabled features.
@MainActor
@Observable
public final class CommandRegistry: CommandRegistering {
    public private(set) var commandsByOwner: [FeatureID: [Command]] = [:]

    public init() {}

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
    }
}
