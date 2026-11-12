import Foundation
import OmniCore

/// Notes on disk: one JSON file, written atomically, readable only by you.
/// Recently deleted notes are kept (up to 20) so a deletion can be undone.
/// Note text is never logged.
@MainActor
public final class NoteStore {
    struct File: Codable {
        var notes: [StickyNote]
        var recentlyDeleted: [StickyNote]
    }

    public private(set) var notes: [StickyNote] = []
    public private(set) var recentlyDeleted: [StickyNote] = []
    private let url: URL
    static let deletedLimit = 20

    /// Loads `url` if it exists. A damaged file is kept aside (".damaged")
    /// rather than overwritten, and the store starts empty.
    public init(url: URL) {
        self.url = url
        guard let data = try? Data(contentsOf: url) else { return }
        if let file = try? JSONDecoder.notes.decode(File.self, from: data) {
            notes = file.notes
            recentlyDeleted = file.recentlyDeleted
        } else {
            try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("damaged"))
        }
    }

    public func note(_ id: UUID) -> StickyNote? { notes.first { $0.id == id } }

    public func add(_ note: StickyNote) {
        notes.append(note)
        save()
    }

    /// Updates a note; `modified` changes only when the text does.
    public func update(_ note: StickyNote, now: Date = Date()) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }), notes[index] != note else { return }
        var updated = note
        if notes[index].text != note.text { updated.modified = now }
        notes[index] = updated
        save()
    }

    public func delete(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let removed = notes.remove(at: index)
        // Empty notes aren't worth restoring.
        if !removed.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            recentlyDeleted.insert(removed, at: 0)
            if recentlyDeleted.count > Self.deletedLimit { recentlyDeleted.removeLast(recentlyDeleted.count - Self.deletedLimit) }
        }
        save()
    }

    /// Brings back the most recently deleted note.
    @discardableResult
    public func restoreLastDeleted() -> StickyNote? {
        guard !recentlyDeleted.isEmpty else { return nil }
        let note = recentlyDeleted.removeFirst()
        notes.append(note)
        save()
        return note
    }

    /// Deletes every note and the recently deleted list ("Erase Data…").
    public func eraseAll() {
        notes.removeAll()
        recentlyDeleted.removeAll()
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder.notes.encode(File(notes: notes, recentlyDeleted: recentlyDeleted))
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            // Only the error kind; never note text.
            Log.logger("stickynotes").error("Saving notes failed: \((error as NSError).domain, privacy: .public) \((error as NSError).code)")
        }
    }
}

extension JSONEncoder {
    static var notes: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var notes: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
