import Foundation

/// One target on the ring. Stored in settings, so its shape must stay
/// decodable across versions.
public struct RingItem: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var kind: Kind

    public init(id: UUID = UUID(), kind: Kind) {
        self.id = id
        self.kind = kind
    }

    public enum Kind: Codable, Sendable, Equatable {
        /// Dropped files are copied or moved into the folder; a click opens it.
        case folder(path: String, mode: FolderMode)
        /// Dropped files open with the app; a click launches it.
        case app(path: String)
        /// Dropped files are attached to a new message or email to this person.
        /// Nothing is sent until you press Send.
        case contact(name: String, handle: String, channel: Channel)
        /// A Shortcut from the Shortcuts app, run with dropped files as input.
        case shortcut(name: String)
        /// Collects files to drag out together later.
        case cargo
        /// Moves dropped files to the Trash.
        case trash
    }

    public enum FolderMode: String, Codable, Sendable, CaseIterable {
        case copy, move
    }

    public enum Channel: String, Codable, Sendable, CaseIterable {
        case messages, mail
    }

    public var folderURL: URL? {
        if case let .folder(path, _) = kind { URL(fileURLWithPath: path, isDirectory: true) } else { nil }
    }

    public var appURL: URL? {
        if case let .app(path) = kind { URL(fileURLWithPath: path, isDirectory: true) } else { nil }
    }

    /// File-system path the item points at, if any (to spot missing ones).
    public var path: String? {
        switch kind {
        case let .folder(path, _), let .app(path): path
        default: nil
        }
    }

    /// Initials for a contact's round avatar ("Jens Olson" → "JO").
    public static func initials(_ name: String) -> String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" }).prefix(2)
        let letters = words.compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }

    /// Ring for a new user: Desktop, Downloads and Documents (copy), Cargo and Trash.
    public static func starterRing(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [RingItem] {
        ["Desktop", "Downloads", "Documents"].map { // l10n-ignore
            RingItem(kind: .folder(path: home.appendingPathComponent($0).path, mode: .copy))
        } + [RingItem(kind: .cargo), RingItem(kind: .trash)]
    }
}
