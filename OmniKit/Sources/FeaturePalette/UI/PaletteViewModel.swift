import Foundation
import Observation

/// Where the palette gets its items. Closures so the view model stays testable
/// and doesn't own any services.
@MainActor
struct PaletteSources {
    /// Apps and System Settings panes (rebuilt when the index changes).
    var staticItems: () -> [PaletteItem]
    /// Commands of enabled features (read live, they change with toggles).
    var commandItems: () -> [PaletteItem]
    var answers: (String) -> [QuickAnswer]
    var usage: () -> UsageHistory
}

/// Query, results, and selection of the palette.
@MainActor
@Observable
final class PaletteViewModel {
    var query = "" {
        didSet { if query != oldValue { recompute() } }
    }
    private(set) var results: [PaletteItem] = []
    private(set) var selection = 0
    /// Bumped to ask the view to focus the search field.
    private(set) var focusRequest = 0

    @ObservationIgnored private let sources: PaletteSources
    @ObservationIgnored var onResultsChanged: (() -> Void)?

    init(sources: PaletteSources) {
        self.sources = sources
    }

    var selectedItem: PaletteItem? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    /// Clears the query and shows recent items; called each time the palette opens.
    func reset() {
        if query.isEmpty { recompute() } else { query = "" }
        focusRequest += 1
    }

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = min(max(selection + delta, 0), results.count - 1)
    }

    func select(_ index: Int) {
        if results.indices.contains(index) { selection = index }
    }

    func recompute(now: Date = Date()) {
        let answers = sources.answers(query).enumerated().map { offset, answer in
            PaletteItem(
                id: "answer:\(offset)", title: answer.title, subtitle: answer.subtitle,
                icon: .symbol(Self.symbol(for: answer.kind)), kind: .answer, action: .copy(answer.copyText)
            )
        }
        let ranked = PaletteRanker.rank(
            sources.staticItems() + sources.commandItems(), query: query, usage: sources.usage(), now: now
        )
        results = answers + ranked
        selection = 0
        onResultsChanged?()
    }

    private static func symbol(for kind: QuickAnswer.Kind) -> String {
        switch kind {
        case .calculation: "equal.circle.fill"
        case .unit: "ruler.fill"
        case .currency: "dollarsign.circle.fill"
        }
    }
}
