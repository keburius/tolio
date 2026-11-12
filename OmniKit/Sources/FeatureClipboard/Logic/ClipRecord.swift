import Foundation
import GRDB
import OmniCore

/// A stored clipboard history entry.
public struct ClipRecord: Codable, Identifiable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "clip"

    public var id: Int64?
    public var kind: ClipKind
    public var text: String?
    /// File name inside the store's images folder.
    public var imageFile: String?
    public var thumbnailFile: String?
    public var pixelWidth: Int?
    public var pixelHeight: Int?
    public var contentHash: String
    public var sourceBundleID: String?
    public var sourceAppName: String?
    public var createdAt: Date
    public var pinned: Bool
    public var byteSize: Int

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    /// For `.files`: the copied file URLs.
    public var fileURLs: [URL] {
        guard kind == .files, let text else { return [] }
        return text.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
    }

    /// One-line summary for lists.
    public var title: String {
        switch kind {
        case .text:
            let firstLine = (text ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
            return trimmed.count > 120 ? String(trimmed.prefix(120)) + "…" : (trimmed.isEmpty ? L10n.Clipboard.whitespaceItem : trimmed)
        case .image:
            if let pixelWidth, let pixelHeight { return L10n.Clipboard.imageItem(width: pixelWidth, height: pixelHeight) }
            return L10n.Clipboard.imageItem
        case .files:
            let names = fileURLs.map(\.lastPathComponent)
            let shown = names.prefix(3).joined(separator: ", ")
            return names.count > 3 ? L10n.Clipboard.moreFiles(shown, names.count - 3) : shown
        }
    }
}
