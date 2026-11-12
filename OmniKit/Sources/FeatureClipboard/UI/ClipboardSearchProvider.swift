import Foundation
import OmniCore

/// Launcher results for "clip …". An empty query lists the newest items
/// first (the control panel shows the first three).
@MainActor
final class ClipboardSearchProvider: SearchProvider {
    let keyword = "clip"
    var title: String { L10n.Clipboard.searchTitle }
    var emptyMessage: String? { L10n.Clipboard.emptyHistory }
    private weak var feature: ClipboardHistoryFeature?
    private let relative = RelativeDateTimeFormatter()

    init(feature: ClipboardHistoryFeature) {
        self.feature = feature
        relative.unitsStyle = .short
    }

    func results(for query: String, limit: Int) -> [SearchResult] {
        guard let feature, let store = feature.store else { return [] }
        let isEmpty = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let records = isEmpty ? feature.newestRecords(limit: limit) : feature.records(matching: query, limit: limit)
        return records.map { record in
            let icon: SearchResult.Icon = switch record.kind {
            case .text: .symbol("text.alignleft")
            case .image: store.thumbnailURL(for: record).map { .image($0) } ?? .symbol("photo")
            case .files: record.fileURLs.first.map { .file($0) } ?? .symbol("doc")
            }
            var subtitle = [record.sourceAppName, relative.localizedString(for: record.createdAt, relativeTo: Date())]
                .compactMap { $0 }.joined(separator: " · ")
            if record.pinned { subtitle = L10n.Clipboard.pinnedSubtitle(subtitle) }
            return SearchResult(
                id: "\(record.id ?? 0)", title: record.title, subtitle: subtitle, icon: icon,
                primaryAction: feature.pasteAction(for: record),
                alternateAction: { [weak feature] in feature?.copy(record) }
            )
        }
    }
}
