import Foundation
import Observation
import OmniCore

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
    /// Dynamic result sources of enabled features (clipboard, snippets…).
    var providers: () -> [any SearchProvider]
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

    /// Provider results mixed into normal search, per provider.
    static let mixedProviderLimit = 3
    /// How many top-ranked items stay above mixed provider results.
    static let topRankedBeforeProviders = 5

    /// The provider whose keyword starts the query ("clip foo"), and the rest.
    func scopedProvider() -> (provider: any SearchProvider, query: String)? {
        let lower = query.lowercased()
        for provider in sources.providers() {
            let prefix = provider.keyword.lowercased() + " "
            if lower.hasPrefix(prefix) {
                return (provider, String(query.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }

    func recompute(now: Date = Date()) {
        if let scoped = scopedProvider() {
            results = scoped.provider.results(for: scoped.query, limit: 50).map {
                PaletteItem(result: $0, provider: scoped.provider)
            }
            selection = 0
            onResultsChanged?()
            return
        }
        let answers = sources.answers(query).enumerated().map { offset, answer in
            PaletteItem(
                id: "answer:\(offset)", title: answer.title, subtitle: answer.subtitle,
                icon: .symbol(Self.symbol(for: answer.kind)), kind: .answer, action: .copy(answer.copyText)
            )
        }
        let ranked = PaletteRanker.rank(
            sources.staticItems() + sources.commandItems(), query: query, usage: sources.usage(), now: now
        )
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let provided = trimmed.count < 2 ? [] : sources.providers().flatMap { provider in
            provider.results(for: trimmed, limit: Self.mixedProviderLimit).map { PaletteItem(result: $0, provider: provider) }
        }
        let top = ranked.prefix(Self.topRankedBeforeProviders)
        results = answers + top + provided + ranked.dropFirst(top.count)
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
