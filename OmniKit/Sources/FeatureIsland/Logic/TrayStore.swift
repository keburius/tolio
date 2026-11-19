import Foundation
import Observation
import OmniCore

/// One file kept in the Tray. The Tray holds a reference (a bookmark), not
/// a copy, so a file renamed or moved in Finder is still found. Text or
/// images dropped from an app are saved as files in Tolio's own folder.
public struct TrayItem: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var bookmark: Data
    /// Last known path, used when the bookmark can't be resolved.
    public var path: String
    public var added: Date
    /// Made by the Tray itself (dropped text or an image); deleted on removal.
    public var owned: Bool

    public init(id: UUID = UUID(), bookmark: Data, path: String, added: Date = Date(), owned: Bool = false) {
        self.id = id
        self.bookmark = bookmark
        self.path = path
        self.added = added
        self.owned = owned
    }

    public var name: String { (path as NSString).lastPathComponent }
}

/// The Tray's files, saved between launches.
@MainActor
@Observable
public final class TrayStore {
    public private(set) var items: [TrayItem] = []
    /// Resolved locations, by id.
    public private(set) var urls: [UUID: URL] = [:]

    @ObservationIgnored private let file: URL?
    @ObservationIgnored let folder: URL?

    /// - Parameter directory: where `tray.json` and dropped snippets live;
    ///   nil keeps everything in memory (tests).
    public init(directory: URL?) {
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            file = directory.appendingPathComponent("tray.json")
            folder = directory.appendingPathComponent("Dropped", isDirectory: true)
        } else {
            file = nil
            folder = nil
        }
        load()
    }

    public var isEmpty: Bool { items.isEmpty }

    public var allURLs: [URL] { items.compactMap { urls[$0.id] } }

    /// Adds files; ones already in the Tray move to the front instead.
    @discardableResult
    public func add(_ newURLs: [URL], owned: Bool = false) -> Int {
        var added = 0
        for url in newURLs.reversed() {
            let path = url.standardizedFileURL.path
            if let existing = items.firstIndex(where: { urls[$0.id]?.standardizedFileURL.path == path }) {
                let item = items.remove(at: existing)
                items.insert(item, at: 0)
                continue
            }
            let bookmark = (try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)) ?? Data()
            let item = TrayItem(bookmark: bookmark, path: path, owned: owned)
            items.insert(item, at: 0)
            urls[item.id] = url
            added += 1
        }
        save()
        return added
    }

    /// Saves dropped text as a `.txt` file in the Tray's folder and adds it.
    @discardableResult
    public func addText(_ text: String, name: String) -> URL? {
        guard let folder else { return nil }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = Self.unique(folder.appendingPathComponent(name).appendingPathExtension("txt"))
        guard (try? text.write(to: url, atomically: true, encoding: .utf8)) != nil else { return nil }
        add([url], owned: true)
        return url
    }

    /// Saves dropped image data (PNG) and adds it.
    @discardableResult
    public func addImage(_ data: Data, name: String) -> URL? {
        guard let folder else { return nil }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = Self.unique(folder.appendingPathComponent(name).appendingPathExtension("png"))
        guard (try? data.write(to: url)) != nil else { return nil }
        add([url], owned: true)
        return url
    }

    public func remove(_ ids: Set<UUID>) {
        for item in items where ids.contains(item.id) && item.owned {
            if let url = urls[item.id] { try? FileManager.default.removeItem(at: url) }
        }
        items.removeAll { ids.contains($0.id) }
        ids.forEach { urls[$0] = nil }
        save()
    }

    public func clear() { remove(Set(items.map(\.id))) }

    /// Drops files that no longer exist.
    public func prune() {
        let gone = items.filter { item in
            guard let url = urls[item.id] else { return true }
            return !FileManager.default.fileExists(atPath: url.path)
        }
        if !gone.isEmpty { remove(Set(gone.map(\.id))) }
    }

    // MARK: Saving

    private func load() {
        guard let file, let data = try? Data(contentsOf: file),
              let stored = try? JSONDecoder().decode([TrayItem].self, from: data) else { return }
        for var item in stored {
            var stale = false
            let resolved = (try? URL(resolvingBookmarkData: item.bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale))
                ?? URL(fileURLWithPath: item.path)
            guard FileManager.default.fileExists(atPath: resolved.path) else { continue }
            item.path = resolved.path
            if stale, let fresh = try? resolved.bookmarkData() { item.bookmark = fresh }
            items.append(item)
            urls[item.id] = resolved
        }
    }

    private func save() {
        guard let file else { return }
        let snapshot = items.map { item -> TrayItem in
            var item = item
            if let url = urls[item.id] { item.path = url.path }
            return item
        }
        try? JSONEncoder().encode(snapshot).write(to: file, options: .atomic)
    }

    /// "Note.txt", then "Note 2.txt", "Note 3.txt"…
    nonisolated static func unique(_ url: URL) -> URL {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let dir = url.deletingLastPathComponent()
        for n in 2...999 {
            let candidate = dir.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            if !manager.fileExists(atPath: candidate.path) { return candidate }
        }
        return dir.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
    }
}
