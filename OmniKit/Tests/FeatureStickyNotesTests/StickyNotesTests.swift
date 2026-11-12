import CoreGraphics
import Foundation
import Testing
@testable import FeatureStickyNotes

@MainActor
struct NoteStoreTests {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("omni-notes-\(UUID().uuidString)/notes.json")
    }

    @Test func addUpdatePersist() throws {
        let url = tempURL()
        let store = NoteStore(url: url)
        var note = StickyNote(text: "Buy milk", frame: CGRect(x: 10, y: 10, width: 200, height: 150), now: Date(timeIntervalSince1970: 0))
        store.add(note)
        note.text = "Buy milk\nand bread"
        note.tint = .blue
        store.update(note, now: Date(timeIntervalSince1970: 100))
        let reloaded = NoteStore(url: url)
        #expect(reloaded.notes.count == 1)
        #expect(reloaded.notes[0].text == "Buy milk\nand bread")
        #expect(reloaded.notes[0].tint == .blue)
        #expect(reloaded.notes[0].modified == Date(timeIntervalSince1970: 100))
        #expect(reloaded.notes[0].title == "Buy milk")
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }

    @Test func movingDoesNotChangeModifiedDate() {
        let store = NoteStore(url: tempURL())
        var note = StickyNote(text: "x", frame: .zero, now: Date(timeIntervalSince1970: 0))
        store.add(note)
        note.frame = CGRect(x: 50, y: 50, width: 300, height: 300)
        store.update(note, now: Date(timeIntervalSince1970: 500))
        #expect(store.notes[0].modified == Date(timeIntervalSince1970: 0))
        #expect(store.notes[0].frame.width == 300)
    }

    @Test func deleteAndRestore() {
        let store = NoteStore(url: tempURL())
        let a = StickyNote(text: "keep me", frame: .zero)
        let empty = StickyNote(text: "  ", frame: .zero)
        store.add(a)
        store.add(empty)
        store.delete(empty.id)
        #expect(store.recentlyDeleted.isEmpty) // empty notes aren't kept
        store.delete(a.id)
        #expect(store.notes.isEmpty)
        #expect(store.restoreLastDeleted()?.text == "keep me")
        #expect(store.notes.map(\.id) == [a.id])
        #expect(store.restoreLastDeleted() == nil)
    }

    @Test func deletedListIsCapped() {
        let store = NoteStore(url: tempURL())
        for i in 0..<25 {
            let note = StickyNote(text: "note \(i)", frame: .zero)
            store.add(note)
            store.delete(note.id)
        }
        #expect(store.recentlyDeleted.count == NoteStore.deletedLimit)
        #expect(store.recentlyDeleted.first?.text == "note 24")
    }

    @Test func damagedFileIsKeptAside() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let store = NoteStore(url: url)
        #expect(store.notes.isEmpty)
        #expect(FileManager.default.fileExists(atPath: url.appendingPathExtension("damaged").path))
    }

    @Test func eraseAll() {
        let store = NoteStore(url: tempURL())
        store.add(StickyNote(text: "a", frame: .zero))
        let b = StickyNote(text: "b", frame: .zero)
        store.add(b)
        store.delete(b.id)
        store.eraseAll()
        #expect(store.notes.isEmpty && store.recentlyDeleted.isEmpty)
    }
}

struct NotePlacementTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)

    @Test func newNoteAtClickPoint() {
        let frame = NotePlacement.frame(at: CGPoint(x: 100, y: 800), in: screen)
        #expect(frame == CGRect(x: 100, y: 580, width: 260, height: 220))
    }

    @Test func newNoteNearEdgeStaysOnScreen() {
        let frame = NotePlacement.frame(at: CGPoint(x: 1400, y: 50), in: screen)
        #expect(screen.contains(frame))
        #expect(frame.maxX == 1440 && frame.minY == 0)
    }

    @Test func clampEnforcesMinimumAndScreenSize() {
        let tiny = NotePlacement.clamp(CGRect(x: 10, y: 10, width: 20, height: 20), to: screen)
        #expect(tiny.size == StickyNote.minimumSize)
        let huge = NotePlacement.clamp(CGRect(x: -50, y: -50, width: 5000, height: 5000), to: screen)
        #expect(huge == screen)
    }

    @Test func restoreToBestScreenOrFallback() {
        let second = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let onSecond = CGRect(x: 2000, y: 500, width: 200, height: 200)
        #expect(NotePlacement.restore(onSecond, screens: [screen, second], fallback: screen) == onSecond)
        // Second display unplugged: the note comes back on the main screen.
        let restored = NotePlacement.restore(onSecond, screens: [screen], fallback: screen)
        #expect(screen.contains(restored))
    }

    @Test func cascadeAvoidsExactOverlap() {
        let first = NotePlacement.frame(at: CGPoint(x: 100, y: 800), in: screen)
        let next = NotePlacement.cascade(first, avoiding: [first], in: screen)
        #expect(next == first.offsetBy(dx: 24, dy: -24))
    }
}

struct NoteURLTests {
    @Test func parsesNewNoteLinks() {
        #expect(NoteURL.newNotePoint(URL(string: "omni://note/new?x=120&y=640")!) == .some(CGPoint(x: 120, y: 640)))
        #expect(NoteURL.newNotePoint(URL(string: "omni://note/new")!) == .some(nil))
        #expect(NoteURL.newNotePoint(NoteURL.make(at: CGPoint(x: 5.7, y: 9.2))) == .some(CGPoint(x: 5, y: 9)))
    }

    @Test func rejectsOtherOrOddLinks() {
        #expect(NoteURL.newNotePoint(URL(string: "omni://note/delete")!) == nil)
        #expect(NoteURL.newNotePoint(URL(string: "omni://palette")!) == nil)
        #expect(NoteURL.newNotePoint(URL(string: "https://note/new")!) == nil)
        // Nonsense numbers fall back to "near the pointer".
        #expect(NoteURL.newNotePoint(URL(string: "omni://note/new?x=nan&y=1e999")!) == .some(nil))
    }
}
