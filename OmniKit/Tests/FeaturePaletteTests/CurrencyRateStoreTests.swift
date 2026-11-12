import Foundation
@testable import FeaturePalette
import Testing

@MainActor
struct CurrencyRateStoreTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func tempFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("rates-\(UUID().uuidString).json")
    }

    @Test func refreshStoresRatesAndCachesToDisk() async {
        let url = tempFile()
        let store = CurrencyRateStore(cacheURL: url) { CurrencyTests.fixture }
        #expect(store.needsRefresh(now: now))
        await store.refresh(now: now)
        #expect(store.rates?.date == "2026-11-11")
        #expect(!store.needsRefresh(now: now.addingTimeInterval(60)))

        // A new store (e.g. next launch, offline) reads the cache.
        let offline = CurrencyRateStore(cacheURL: url) { throw URLError(.notConnectedToInternet) }
        #expect(offline.rates?.rates["USD"] == 1.1)
    }

    @Test func staleAfterMaxAge() async {
        let store = CurrencyRateStore(cacheURL: nil) { CurrencyTests.fixture }
        await store.refresh(now: now)
        #expect(store.needsRefresh(now: now.addingTimeInterval(CurrencyRateStore.maxAge + 1)))
    }

    @Test func failureKeepsOldRatesAndBacksOff() async {
        let url = tempFile()
        let good = CurrencyRateStore(cacheURL: url) { CurrencyTests.fixture }
        await good.refresh(now: now)

        let failing = CurrencyRateStore(cacheURL: url) { throw URLError(.timedOut) }
        let later = now.addingTimeInterval(CurrencyRateStore.maxAge + 1)
        await failing.refresh(now: later)
        #expect(failing.rates?.date == "2026-11-11")
        #expect(failing.lastError != nil)
        #expect(!failing.needsRefresh(now: later.addingTimeInterval(60)))
        #expect(failing.needsRefresh(now: later.addingTimeInterval(CurrencyRateStore.retryDelay + 1)))
    }

    @Test func nbgSourceUsesItsParser() async {
        let store = CurrencyRateStore(source: .nbg, cacheURL: nil) { CurrencyTests.nbgFixture }
        await store.refresh(now: now)
        #expect(store.rates?.source == "NBG")
        #expect(store.rates?.supports("GEL") == true)
    }

    @Test func sourcesUseSeparateCacheFiles() {
        #expect(RateSource.ecb.cacheFileName != RateSource.nbg.cacheFileName)
    }

    @Test func corruptCacheIsIgnored() throws {
        let url = tempFile()
        try Data("garbage".utf8).write(to: url)
        #expect(CurrencyRateStore(cacheURL: url) { Data() }.rates == nil)
    }
}
