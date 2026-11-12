import Foundation
import Observation
import OmniCore

/// Keeps ECB rates cached on disk and refreshes them when stale. Never blocks
/// the palette: conversions use whatever is cached, offline included.
///
/// Network: this is the only outbound request Omni makes.
@MainActor
@Observable
public final class CurrencyRateStore {
    public static let sourceURL = URL(string: "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")!
    /// ECB publishes once per working day; refresh after this age.
    static let maxAge: TimeInterval = 6 * 3600
    /// Wait at least this long after a failed attempt.
    static let retryDelay: TimeInterval = 15 * 60

    public private(set) var rates: CurrencyRates?
    public private(set) var isFetching = false
    public private(set) var lastError: String?

    public typealias Fetch = @Sendable () async throws -> Data

    @ObservationIgnored private let cacheURL: URL?
    @ObservationIgnored private let fetch: Fetch
    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private let log = Log.logger("currency")

    /// - Parameters:
    ///   - cacheURL: JSON cache file; nil disables caching (tests).
    ///   - fetch: downloads the ECB XML. Defaults to an ephemeral URLSession.
    public init(cacheURL: URL?, fetch: @escaping Fetch = CurrencyRateStore.download) {
        self.cacheURL = cacheURL
        self.fetch = fetch
        rates = cacheURL.flatMap(Self.loadCache)
    }

    public func needsRefresh(now: Date) -> Bool {
        if isFetching { return false }
        if let lastAttempt, lastError != nil, now.timeIntervalSince(lastAttempt) < Self.retryDelay { return false }
        guard let rates else { return true }
        return now.timeIntervalSince(rates.fetchedAt) > Self.maxAge
    }

    /// Starts a background refresh if the cache is stale. Returns immediately.
    public func refreshIfNeeded(now: Date = Date()) {
        guard needsRefresh(now: now) else { return }
        Task { await refresh(now: now) }
    }

    /// Downloads and stores fresh rates. Keeps the old rates on failure.
    public func refresh(now: Date = Date()) async {
        guard !isFetching else { return }
        isFetching = true
        lastAttempt = now
        defer { isFetching = false }
        do {
            let fresh = try ECBRateParser.parse(try await fetch(), fetchedAt: now)
            rates = fresh
            lastError = nil
            saveCache(fresh)
            log.info("Currency rates updated (\(fresh.rates.count) currencies, \(fresh.date, privacy: .public))")
        } catch {
            lastError = error.localizedDescription
            log.error("Currency rate refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public static let download: Fetch = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpAdditionalHeaders = ["User-Agent": "Omni"]
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(from: sourceURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func loadCache(_ url: URL) -> CurrencyRates? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CurrencyRates.self, from: data)
    }

    private func saveCache(_ rates: CurrencyRates) {
        guard let cacheURL else { return }
        do {
            try JSONEncoder().encode(rates).write(to: cacheURL, options: .atomic)
        } catch {
            log.error("Could not write currency cache: \(error.localizedDescription, privacy: .public)")
        }
    }
}
