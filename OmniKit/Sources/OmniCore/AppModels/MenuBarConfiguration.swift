import Foundation

/// Which quick-access icons show in the menu bar, in which order, or one icon only.
public struct MenuBarConfiguration: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, Sendable {
        /// Separate icons for the visible quick actions, plus the main icon.
        case separate
        /// Only the main icon; everything is in the control panel.
        case single
    }

    public struct Entry: Codable, Equatable, Sendable {
        public var id: QuickAccessID
        public var isVisible: Bool

        public init(id: QuickAccessID, isVisible: Bool) {
            self.id = id
            self.isVisible = isVisible
        }
    }

    public var mode: Mode
    /// Left to right as in the menu bar.
    public private(set) var entries: [Entry]

    public static let key = SettingKey("app.menuBar", default: MenuBarConfiguration.standard)

    /// Keep Awake, Screenshot, Capture Text and Clipboard on; the rest available but off.
    public static let standard = MenuBarConfiguration(mode: .separate, entries: QuickAccessID.allCases.map {
        Entry(id: $0, isVisible: standardVisible.contains($0))
    })

    public init(mode: Mode, entries: [Entry]) {
        self.mode = mode
        self.entries = entries
        normalize()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = (try? container.decode(Mode.self, forKey: .mode)) ?? .separate
        // Unknown IDs (from a newer or older version) are dropped, not fatal.
        let raw = (try? container.decode([LossyEntry].self, forKey: .entries)) ?? []
        entries = raw.compactMap { entry in entry.id.map { Entry(id: $0, isVisible: entry.isVisible) } }
        normalize()
    }

    private struct LossyEntry: Decodable {
        let id: QuickAccessID?
        let isVisible: Bool

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = QuickAccessID(rawValue: (try? container.decode(String.self, forKey: .id)) ?? "")
            isVisible = (try? container.decode(Bool.self, forKey: .isVisible)) ?? false
        }

        enum CodingKeys: String, CodingKey { case id, isVisible }
    }

    /// Removes duplicates and appends any missing icons with their default visibility.
    private mutating func normalize() {
        var seen = Set<QuickAccessID>()
        entries = entries.filter { seen.insert($0.id).inserted }
        for id in QuickAccessID.allCases where !seen.contains(id) {
            entries.append(Entry(id: id, isVisible: Self.standardVisible.contains(id)))
        }
    }

    private static let standardVisible: Set<QuickAccessID> = [.keepAwake, .screenshot, .captureText, .clipboard, .stickyNotes]

    public func isVisible(_ id: QuickAccessID) -> Bool {
        entries.first { $0.id == id }?.isVisible ?? false
    }

    public mutating func setVisible(_ visible: Bool, for id: QuickAccessID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isVisible = visible
    }

    /// Moves an icon left (negative) or right (positive), clamped to the ends.
    public mutating func move(_ id: QuickAccessID, by offset: Int) {
        guard let from = entries.firstIndex(where: { $0.id == id }) else { return }
        let to = min(max(from + offset, 0), entries.count - 1)
        guard to != from else { return }
        let entry = entries.remove(at: from)
        entries.insert(entry, at: to)
    }

    /// SwiftUI `onMove` semantics: `destination` is an index in the list before removal.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { entries[$0] }
        var remaining = entries.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertAt = destination - source.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: min(max(insertAt, 0), remaining.count))
        entries = remaining
    }

    /// Icons to show, left to right: visible, separate mode, and their feature is on.
    public func iconsToShow(available: Set<QuickAccessID>) -> [QuickAccessID] {
        guard mode == .separate else { return [] }
        return entries.filter { $0.isVisible && available.contains($0.id) }.map(\.id)
    }
}
