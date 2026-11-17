import Foundation
import GRDB
import OmniCore

/// SQLite-backed clipboard history (GRDB). Images live as PNG files next to
/// the database. Thread-safe; callable from any thread.
public final class ClipboardStore: Sendable {
    public enum Failure: Error { case imageUnreadable }

    private let db: DatabaseQueue
    /// Folder for image files; nil only for in-memory stores without images.
    public let imagesDirectory: URL
    /// Removes a file. Safety rule: destructive file operations go to the
    /// Trash (and are logged), so this moves files there; tests inject a fake.
    private let trash: @Sendable (URL) throws -> Void

    /// Opens (or creates) the store in `directory`. Pass nil for an
    /// in-memory database (tests); images then go to a temporary folder.
    public init(directory: URL?, trash: @escaping @Sendable (URL) throws -> Void = ClipboardStore.moveToTrash) throws {
        self.trash = trash
        if let directory {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
            )
            imagesDirectory = directory.appendingPathComponent("images", isDirectory: true)
            db = try DatabaseQueue(path: directory.appendingPathComponent("clipboard.sqlite").path)
        } else {
            imagesDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("omni-clip-\(UUID().uuidString)", isDirectory: true)
            db = try DatabaseQueue()
        }
        try FileManager.default.createDirectory(
            at: imagesDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        try Self.migrator.migrate(db)
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "clip") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("kind", .text).notNull()
                t.column("text", .text)
                t.column("imageFile", .text)
                t.column("thumbnailFile", .text)
                t.column("pixelWidth", .integer)
                t.column("pixelHeight", .integer)
                t.column("contentHash", .text).notNull().unique()
                t.column("sourceBundleID", .text)
                t.column("sourceAppName", .text)
                t.column("createdAt", .datetime).notNull().indexed()
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("byteSize", .integer).notNull()
            }
            try db.create(virtualTable: "clip_fts", using: FTS5()) { t in
                t.synchronize(withTable: "clip")
                t.tokenizer = .unicode61()
                t.column("text")
                t.column("sourceAppName")
            }
        }
        return migrator
    }

    // MARK: - Writing

    /// Stores a clip. If identical content exists, moves it to the top instead
    /// of duplicating. Returns the stored record.
    @discardableResult
    public func insert(_ clip: CapturedClip, at date: Date) throws -> ClipRecord {
        let hash = clip.contentHash
        if let existing = try db.write({ db -> ClipRecord? in
            guard var record = try ClipRecord.filter(Column("contentHash") == hash).fetchOne(db) else { return nil }
            record.createdAt = date
            if clip.sourceBundleID != nil {
                record.sourceBundleID = clip.sourceBundleID
                record.sourceAppName = clip.sourceAppName
            }
            try record.update(db)
            return record
        }) {
            return existing
        }

        var record = ClipRecord(
            id: nil, kind: clip.kind, text: clip.text, imageFile: nil, thumbnailFile: nil,
            pixelWidth: nil, pixelHeight: nil, contentHash: hash, sourceBundleID: clip.sourceBundleID,
            sourceAppName: clip.sourceAppName, createdAt: date, pinned: false, byteSize: clip.byteSize
        )
        if clip.kind == .image, let data = clip.imageData {
            guard let image = ImageProcessing.process(data) else { throw Failure.imageUnreadable }
            let name = "\(hash).png", thumbName = "\(hash)-thumb.png"
            try image.png.write(to: imagesDirectory.appendingPathComponent(name), options: .atomic)
            try image.thumbnail.write(to: imagesDirectory.appendingPathComponent(thumbName), options: .atomic)
            record.imageFile = name
            record.thumbnailFile = thumbName
            record.pixelWidth = image.width
            record.pixelHeight = image.height
            record.byteSize = image.png.count
        }
        try db.write { db in try record.insert(db) }
        return record
    }

    public func setPinned(_ pinned: Bool, id: Int64) throws {
        _ = try db.write { db in
            try ClipRecord.filter(id: id).updateAll(db, Column("pinned").set(to: pinned))
        }
    }

    public func delete(id: Int64) throws {
        let removed = try db.write { db -> [ClipRecord] in
            let rows = try ClipRecord.filter(id: id).fetchAll(db)
            _ = try ClipRecord.filter(id: id).deleteAll(db)
            return rows
        }
        removeFiles(of: removed)
    }

    /// Deletes everything, or everything except pinned items.
    public func deleteAll(keepPinned: Bool) throws {
        let removed = try db.write { db -> [ClipRecord] in
            let request = keepPinned ? ClipRecord.filter(Column("pinned") == false) : ClipRecord.all()
            let rows = try request.fetchAll(db)
            _ = try request.deleteAll(db)
            return rows
        }
        removeFiles(of: removed)
    }

    /// Applies retention to unpinned items: keep at most `maxItems`, and none
    /// older than `maxAge` (nil = no age limit). Returns how many were removed.
    @discardableResult
    public func prune(maxItems: Int, maxAge: TimeInterval?, now: Date) throws -> Int {
        let removed = try db.write { db -> [ClipRecord] in
            var doomed = try ClipRecord
                .filter(Column("pinned") == false)
                .order(Column("createdAt").desc)
                .limit(Int.max, offset: maxItems)
                .fetchAll(db)
            if let maxAge {
                doomed += try ClipRecord
                    .filter(Column("pinned") == false && Column("createdAt") < now.addingTimeInterval(-maxAge))
                    .fetchAll(db)
            }
            let ids = Set(doomed.compactMap(\.id))
            _ = try ClipRecord.filter(keys: ids).deleteAll(db)
            return doomed.filter { ids.contains($0.id ?? -1) }
        }
        let unique = Dictionary(removed.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values
        removeFiles(of: Array(unique))
        return unique.count
    }

    // MARK: - Reading

    /// Pinned first, then newest.
    public func recent(limit: Int) throws -> [ClipRecord] {
        try db.read { db in
            try ClipRecord.order(Column("pinned").desc, Column("createdAt").desc).limit(limit).fetchAll(db)
        }
    }

    /// Full-text prefix search over text, file paths, and source app names.
    public func search(_ query: String, limit: Int) throws -> [ClipRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try recent(limit: limit) }
        return try db.read { db in
            if let pattern = FTS5Pattern(matchingAllPrefixesIn: trimmed) {
                let sql = """
                    SELECT clip.* FROM clip
                    JOIN clip_fts ON clip_fts.rowid = clip.id AND clip_fts MATCH ?
                    ORDER BY clip.pinned DESC, clip.createdAt DESC LIMIT ?
                    """
                return try ClipRecord.fetchAll(db, sql: sql, arguments: [pattern, limit])
            }
            // Punctuation-only queries: plain substring match.
            return try ClipRecord
                .filter(Column("text").like("%\(trimmed)%"))
                .order(Column("pinned").desc, Column("createdAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func count() throws -> Int {
        try db.read { db in try ClipRecord.fetchCount(db) }
    }

    /// Number of items that aren't pinned (what "clear, keep pinned" removes).
    public func unpinnedCount() throws -> Int {
        try db.read { db in try ClipRecord.filter(Column("pinned") == false).fetchCount(db) }
    }

    /// Newest first, pinned or not (recently copied lists).
    public func newest(limit: Int) throws -> [ClipRecord] {
        try db.read { db in
            try ClipRecord.order(Column("createdAt").desc).limit(limit).fetchAll(db)
        }
    }

    public func imageURL(for record: ClipRecord) -> URL? {
        record.imageFile.map { imagesDirectory.appendingPathComponent($0) }
    }

    public func thumbnailURL(for record: ClipRecord) -> URL? {
        record.thumbnailFile.map { imagesDirectory.appendingPathComponent($0) }
    }

    /// Moves the image and thumbnail files of deleted records to the Trash
    /// and logs how many (never which). Missing files are ignored.
    private func removeFiles(of records: [ClipRecord]) {
        var moved = 0
        for record in records {
            for name in [record.imageFile, record.thumbnailFile].compactMap({ $0 }) {
                let url = imagesDirectory.appendingPathComponent(name)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                do {
                    try trash(url)
                    moved += 1
                } catch {
                    Log.logger("clipboard").error("Couldn't move a clipboard image to the Trash: \((error as NSError).code)")
                }
            }
        }
        if moved > 0 {
            Log.logger("clipboard").notice("Moved \(moved) clipboard image file(s) to the Trash")
        }
    }

    /// The default: Finder's Trash.
    public static let moveToTrash: @Sendable (URL) throws -> Void = { url in
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}
