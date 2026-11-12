import OmniCore
import Foundation
@testable import FeaturePalette
import Testing

struct PaletteRankerTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func app(_ name: String, keywords: [String] = []) -> PaletteItem {
        PaletteItem(
            id: "app:\(name)", title: name, icon: .symbol("app"), kind: .app,
            keywords: keywords, action: .copy(name)
        )
    }

    private var catalog: [PaletteItem] {
        ["Safari", "Slack", "System Settings", "Messages", "Terminal", "Notes", "Visual Studio Code"].map { app($0) }
    }

    @Test func ordersByMatchQuality() {
        let titles = PaletteRanker.rank(catalog, query: "s", usage: UsageHistory(), now: now).map(\.title)
        #expect(titles.first == "Slack" || titles.first == "Safari") // short prefix matches first
        #expect(titles.contains("Messages"))
        #expect(!titles.contains("Terminal"))
    }

    @Test func usageBoostReordersEquivalentMatches() {
        var usage = UsageHistory()
        for _ in 0..<5 { usage.record("app:Slack", at: now) }
        let titles = PaletteRanker.rank(catalog, query: "s", usage: usage, now: now).map(\.title)
        #expect(titles.first == "Slack")
    }

    @Test func keywordsMatchButTitleMatchesWin() {
        let items = [app("Display Tool"), app("Monitor Thing"), app("Displays", keywords: ["monitor", "resolution"])]
        let titles = PaletteRanker.rank(items, query: "monitor", usage: UsageHistory(), now: now).map(\.title)
        #expect(titles == ["Monitor Thing", "Displays"])
    }

    @Test func emptyQueryShowsRecentlyUsedOnly() {
        var usage = UsageHistory()
        usage.record("app:Notes", at: now)
        let titles = PaletteRanker.rank(catalog, query: "  ", usage: usage, now: now).map(\.title)
        #expect(titles == ["Notes"])
    }

    @Test func highlightsTitleMatches() throws {
        let first = try #require(PaletteRanker.rank(catalog, query: "term", usage: UsageHistory(), now: now).first)
        #expect(first.highlighted == [0, 1, 2, 3])
    }

    @Test func respectsLimit() {
        #expect(PaletteRanker.rank(catalog, query: "e", usage: UsageHistory(), now: now, limit: 2).count == 2)
    }
}

struct UsageHistoryTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func boostGrowsWithCountAndDecaysWithAge() {
        var usage = UsageHistory()
        usage.record("a", at: now)
        let once = usage.boost(for: "a", at: now)
        usage.record("a", at: now)
        #expect(usage.boost(for: "a", at: now) > once)
        let later = now.addingTimeInterval(14 * 86_400)
        #expect(abs(usage.boost(for: "a", at: later) - usage.boost(for: "a", at: now) / 2) < 0.0001)
        #expect(usage.boost(for: "never", at: now) == 0)
    }

    @Test func prunesOldestBeyondCap() {
        var usage = UsageHistory()
        for i in 0...UsageHistory.maxEntries {
            usage.record("item\(i)", at: now.addingTimeInterval(Double(i)))
        }
        #expect(usage.entries.count == UsageHistory.maxEntries)
        #expect(usage.entries["item0"] == nil)
    }
}

@MainActor
final class StubProvider: SearchProvider {
    let keyword = "clip"
    let title = "Clipboard"
    private(set) var queries: [String] = []

    func results(for query: String, limit: Int) -> [SearchResult] {
        queries.append(query)
        return (0..<limit).map { SearchResult(id: "\($0)", title: "clip \(query) \($0)", icon: .symbol("doc"), primaryAction: {}) }
    }
}

@MainActor
struct PaletteProviderTests {
    private func model(_ provider: StubProvider) -> PaletteViewModel {
        let apps = ["Safari", "Slack", "System Settings", "Messages", "Mail", "Maps", "Music", "Stocks"].map {
            PaletteItem(id: "app:\($0)", title: $0, icon: .symbol("app"), kind: .app, action: .copy($0))
        }
        return PaletteViewModel(sources: PaletteSources(
            staticItems: { apps }, commandItems: { [] }, answers: { _ in [] },
            usage: { UsageHistory() }, providers: { [provider] }
        ))
    }

    @Test func keywordScopesToProvider() {
        let provider = StubProvider()
        let model = model(provider)
        model.query = "clip hello"
        #expect(provider.queries.last == "hello")
        #expect(model.results.count == 50)
        #expect(model.results.allSatisfy { $0.kind == .provided && $0.kindLabel == "Clipboard" })
    }

    @Test func keywordWithEmptyRestShowsRecent() {
        let provider = StubProvider()
        let model = model(provider)
        model.query = "CLIP "
        #expect(provider.queries.last == "")
    }

    @Test func providerResultsMixAfterTopRanked() {
        let provider = StubProvider()
        let model = model(provider)
        model.query = "sa"
        let kinds = model.results.map(\.kind)
        let firstProvided = kinds.firstIndex(of: .provided)
        #expect(firstProvided != nil)
        #expect(firstProvided! <= PaletteViewModel.topRankedBeforeProviders)
        #expect(kinds.filter { $0 == .provided }.count == PaletteViewModel.mixedProviderLimit)
    }

    @Test func singleCharacterQueryDoesNotHitProviders() {
        let provider = StubProvider()
        let model = model(provider)
        model.query = "s"
        #expect(!model.results.contains { $0.kind == .provided })
    }
}
