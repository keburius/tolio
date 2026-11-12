import Foundation
import OmniCore

/// One menu bar item or menu item, read from Accessibility (or a test fixture).
public struct MenuNode: Equatable, Sendable {
    public var title: String
    /// Formatted shortcut (see `ShortcutFormatter`), nil if none.
    public var shortcut: String?
    public var isEnabled: Bool
    /// Index into the reader's element table, used to press the item.
    public var ref: Int?
    public var children: [MenuNode]

    public init(title: String, shortcut: String? = nil, isEnabled: Bool = true, ref: Int? = nil, children: [MenuNode] = []) {
        self.title = title
        self.shortcut = shortcut
        self.isEnabled = isEnabled
        self.ref = ref
        self.children = children
    }
}

public struct ShortcutEntry: Equatable, Sendable, Identifiable {
    public var id: String
    /// Item title, prefixed with its submenu path ("Find › Find Next").
    public var title: String
    public var shortcut: String
    public var isEnabled: Bool
    public var ref: Int?
}

public struct ShortcutSection: Equatable, Sendable, Identifiable {
    public var title: String
    public var entries: [ShortcutEntry]
    public var id: String { title }
    /// Rows it occupies in the overlay: a header plus one per entry.
    public var rowCount: Int { entries.count + 1 }
}

/// Flattens a menu bar into one section per top-level menu, keeping only
/// items that have a keyboard shortcut.
public enum ShortcutCatalog {
    public static func sections(from menuBar: [MenuNode], includeDisabled: Bool = true) -> [ShortcutSection] {
        var result: [ShortcutSection] = []
        var usedTitles: [String: Int] = [:]
        for (menuIndex, menu) in menuBar.enumerated() {
            var entries: [ShortcutEntry] = []
            var seen = Set<String>()
            collect(menu.children, path: [], into: &entries, seen: &seen, includeDisabled: includeDisabled, idPrefix: "\(menuIndex)")
            guard !entries.isEmpty else { continue }
            // Section titles must be unique for SwiftUI identity.
            var title = menu.title.isEmpty ? L10n.Cheatsheet.untitledMenu : menu.title
            if let count = usedTitles[title] {
                usedTitles[title] = count + 1
                title += " (\(count + 1))"
            } else {
                usedTitles[title] = 1
            }
            result.append(ShortcutSection(title: title, entries: entries))
        }
        return result
    }

    private static func collect(
        _ items: [MenuNode], path: [String], into entries: inout [ShortcutEntry], seen: inout Set<String>,
        includeDisabled: Bool, idPrefix: String
    ) {
        for (index, item) in items.enumerated() {
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            if let shortcut = item.shortcut, includeDisabled || item.isEnabled {
                let fullTitle = (path + [title]).joined(separator: " › ")
                if seen.insert(fullTitle + "\u{0}" + shortcut).inserted {
                    entries.append(ShortcutEntry(
                        id: "\(idPrefix).\(index)", title: fullTitle, shortcut: shortcut,
                        isEnabled: item.isEnabled, ref: item.ref
                    ))
                }
            }
            if !item.children.isEmpty {
                collect(item.children, path: path + [title], into: &entries, seen: &seen,
                        includeDisabled: includeDisabled, idPrefix: "\(idPrefix).\(index)")
            }
        }
    }

    /// Case-insensitive filter on entry title, section title, or shortcut.
    public static func filter(_ sections: [ShortcutSection], query: String) -> [ShortcutSection] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return sections }
        return sections.compactMap { section in
            if section.title.lowercased().contains(needle) { return section }
            var copy = section
            copy.entries = section.entries.filter {
                $0.title.lowercased().contains(needle) || $0.shortcut.lowercased() == needle
            }
            return copy.entries.isEmpty ? nil : copy
        }
    }
}

/// Splits sections into columns in reading order, balancing their heights.
public enum ColumnPacker {
    /// - Parameters:
    ///   - rowCounts: rows per section, in order.
    ///   - maxColumns: columns that fit on screen.
    ///   - rowsPerColumn: rows that fit vertically before more columns are worth using.
    /// - Returns: section indices per column; never more than `maxColumns`, never empty columns.
    public static func pack(rowCounts: [Int], maxColumns: Int, rowsPerColumn: Int) -> [[Int]] {
        guard !rowCounts.isEmpty else { return [] }
        let total = rowCounts.reduce(0, +)
        let wanted = Int((Double(total) / Double(max(rowsPerColumn, 1))).rounded(.up))
        let columnCount = min(max(maxColumns, 1), max(wanted, 1), rowCounts.count)
        let target = Int((Double(total) / Double(columnCount)).rounded(.up))
        var columns: [[Int]] = [[]]
        var height = 0
        for (index, rows) in rowCounts.enumerated() {
            let remainingSections = rowCounts.count - index
            let remainingColumns = columnCount - columns.count
            let overTarget = height + rows > target && height > 0
            // Start a new column when this one is full, or when every
            // remaining column needs at least one section.
            if !columns[columns.count - 1].isEmpty, remainingColumns > 0,
               overTarget || remainingSections <= remainingColumns {
                // Keep the section here if it's closer to the target than leaving a gap.
                let keep = overTarget && (height + rows - target) < (target - height) && remainingSections > remainingColumns
                if !keep {
                    columns.append([])
                    height = 0
                }
            }
            columns[columns.count - 1].append(index)
            height += rows
        }
        return columns
    }
}
