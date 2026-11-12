import Testing
@testable import FeatureShortcutOverlay

struct ShortcutCatalogTests {
    /// A small editor-like menu bar (Apple menu already dropped by the reader).
    static let fixture: [MenuNode] = [
        MenuNode(title: "Code", children: [
            MenuNode(title: "About Code"),
            MenuNode(title: "Settings…", shortcut: "⌘,", ref: 0),
            MenuNode(title: "Quit Code", shortcut: "⌘Q", ref: 1),
        ]),
        MenuNode(title: "File", children: [
            MenuNode(title: "New File", shortcut: "⌘N", ref: 2),
            MenuNode(title: "Open Recent", children: [
                MenuNode(title: "Reopen Closed Editor", shortcut: "⇧⌘T", ref: 3),
                MenuNode(title: "More…"),
            ]),
            MenuNode(title: "   "),
            MenuNode(title: "Save", shortcut: "⌘S", isEnabled: false, ref: 4),
        ]),
        MenuNode(title: "Window", children: [MenuNode(title: "Zoom")]),
        MenuNode(title: "Edit", children: [
            MenuNode(title: "Undo", shortcut: "⌘Z", ref: 5),
            MenuNode(title: "Undo", shortcut: "⌘Z", ref: 6),
        ]),
        MenuNode(title: "Edit", children: [MenuNode(title: "Find", shortcut: "⌘F", ref: 7)]),
    ]

    @Test func flattensAndGroups() {
        let sections = ShortcutCatalog.sections(from: Self.fixture)
        #expect(sections.map(\.title) == ["Code", "File", "Edit", "Edit (2)"])
        let file = sections[1]
        #expect(file.entries.map(\.title) == ["New File", "Open Recent › Reopen Closed Editor", "Save"])
        #expect(file.entries.map(\.shortcut) == ["⌘N", "⇧⌘T", "⌘S"])
        #expect(file.entries[1].ref == 3)
        #expect(file.entries[2].isEnabled == false)
        #expect(Set(sections.flatMap(\.entries).map(\.id)).count == sections.flatMap(\.entries).count)
    }

    @Test func duplicatesRemovedAndEmptyMenusDropped() {
        let sections = ShortcutCatalog.sections(from: Self.fixture)
        #expect(sections[2].entries.count == 1)
        #expect(!sections.contains { $0.title == "Window" })
    }

    @Test func disabledCanBeExcluded() {
        let sections = ShortcutCatalog.sections(from: Self.fixture, includeDisabled: false)
        #expect(!sections.flatMap(\.entries).contains { $0.title == "Save" })
    }

    @Test func filter() {
        let sections = ShortcutCatalog.sections(from: Self.fixture)
        #expect(ShortcutCatalog.filter(sections, query: "").count == 4)
        let reopen = ShortcutCatalog.filter(sections, query: "REOPEN")
        #expect(reopen.map(\.title) == ["File"])
        #expect(reopen[0].entries.count == 1)
        // Section title match keeps the whole section.
        #expect(ShortcutCatalog.filter(sections, query: "file").first?.entries.count == 3)
        // Exact shortcut match.
        #expect(ShortcutCatalog.filter(sections, query: "⌘q").flatMap(\.entries).map(\.title) == ["Quit Code"])
    }

    @Test func packingKeepsOrderAndBalances() {
        let packed = ColumnPacker.pack(rowCounts: [10, 10, 10, 10], maxColumns: 2, rowsPerColumn: 25)
        #expect(packed == [[0, 1], [2, 3]])
        // Fits in one column.
        #expect(ColumnPacker.pack(rowCounts: [3, 4, 5], maxColumns: 4, rowsPerColumn: 30) == [[0, 1, 2]])
        #expect(ColumnPacker.pack(rowCounts: [], maxColumns: 3, rowsPerColumn: 10) == [])
    }

    @Test func packingInvariants() {
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let counts = (0..<Int.random(in: 1...20, using: &rng)).map { _ in Int.random(in: 1...60, using: &rng) }
            let maxColumns = Int.random(in: 1...6, using: &rng)
            let packed = ColumnPacker.pack(rowCounts: counts, maxColumns: maxColumns, rowsPerColumn: Int.random(in: 5...80, using: &rng))
            #expect(packed.flatMap { $0 } == Array(counts.indices))
            #expect(packed.count <= maxColumns)
            #expect(!packed.contains { $0.isEmpty })
        }
    }
}
