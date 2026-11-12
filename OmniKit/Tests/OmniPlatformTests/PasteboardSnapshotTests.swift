import AppKit
import OmniCore
@testable import OmniPlatform
import Testing

@MainActor
struct PasteboardSnapshotTests {
    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("omni.tests.\(UUID().uuidString)"))
    }

    @Test func restoresAllItemsAndTypes() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let first = NSPasteboardItem()
        first.setString("hello", forType: .string)
        first.setData(Data("{\\rtf1 hi}".utf8), forType: .rtf)
        let second = NSPasteboardItem()
        second.setString("https://example.com", forType: .URL)
        pasteboard.clearContents()
        pasteboard.writeObjects([first, second])

        let snapshot = PasteboardSnapshot.capture(pasteboard)
        TemporaryPasteboard.write("temporary", to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "temporary")

        snapshot.restore(to: pasteboard)
        #expect(pasteboard.pasteboardItems?.count == 2)
        #expect(pasteboard.string(forType: .string) == "hello")
        #expect(pasteboard.data(forType: .rtf) == Data("{\\rtf1 hi}".utf8))
        #expect(pasteboard.pasteboardItems?[1].string(forType: .URL) == "https://example.com")
    }

    @Test func restoredAndTemporaryWritesAreMarkedInternal() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let internalType = NSPasteboard.PasteboardType(PasteboardTypes.omniInternal)
        TemporaryPasteboard.write("x", to: pasteboard)
        #expect(pasteboard.types?.contains(internalType) == true)
        #expect(pasteboard.types?.contains(NSPasteboard.PasteboardType(PasteboardTypes.transient)) == true)

        let snapshot = PasteboardSnapshot(items: [["public.utf8-plain-text": Data("y".utf8)]])
        snapshot.restore(to: pasteboard)
        #expect(pasteboard.types?.contains(internalType) == true)
        #expect(pasteboard.string(forType: .string) == "y")
    }

    @Test func emptyPasteboardGivesEmptySnapshot() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        #expect(PasteboardSnapshot.capture(pasteboard).isEmpty)
    }
}
