import Foundation
import Observation
import OmniCore

/// A rate publisher: where to download and how to parse.
public struct RateSource: Sendable {
    public let name: String
    public let url: URL
    public let cacheFileName: String
    public let parse: @Sendable (Data, Date) throws -> CurrencyRates

    /// European Central Bank daily reference rates (~30 currencies).
    public static let ecb = RateSource(
        name: "European Central Bank",
        url: URL(string: "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")!,
        cacheFileName: "currency-rates.json",
        parse: ECBRateParser.parse
    )

    /// National Bank of Georgia official rates (GEL and ~40 currencies).
    public static let nbg = RateSource(
        name: "National Bank of Georgia",
        url: URL(string: "https://nbg.gov.ge/gw/api/ct/monetarypolicy/currencies/en/json")!,
        cacheFileName: "currency-rates-nbg.json",
        parse: NBGRateParser.parse
    )
}

/// Keeps one publisher's rates cached on disk and refreshes them when stale.
/// Never blocks the palette: conversions use whatever is cached, offline included.
///
/// Network: the rate downloads are the only outbound requests Omni makes.
/// They are plain GETs with no cookies and no identifying data.
@MainActor
@Observable
public final class CurrencyRateStore {
    /// ECB publishes once per working day; refresh after this age.
    static let maxAge: TimeInterval = 6 * 3600
    /// Wait at least this long after a failed attempt.
    static let retryDelay: TimeInterval = 15 * 60

    public private(set) var rates: CurrencyRates?
    public private(set) var isFetching = false
    public private(set) var lastError: String?

    public typealias Fetch = @Sendable () async throws -> Data

    public let source: RateSource
    @ObservationIgnored private let cacheURL: URL?
    @ObservationIgnored private let fetch: Fetch
    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private let log = Log.logger("currency")

    /// - Parameters:
    ///   - source: the publisher.
    ///   - cacheURL: JSON cache file; nil disables caching (tests).
    ///   - fetch: downloads the document. Defaults to an ephemeral URLSession GET of `source.url`.
    public init(source: RateSource = .ecb, cacheURL: URL?, fetch: Fetch? = nil) {
        self.source = source
        self.cacheURL = cacheURL
        self.fetch = fetch ?? { try await CurrencyRateStore.download(source.url) }
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
            let fresh = try source.parse(try await fetch(), now)
            rates = fresh
            lastError = nil
            saveCache(fresh)
            log.info("\(fresh.source, privacy: .public) rates updated (\(fresh.rates.count) currencies, \(fresh.date, privacy: .public))")
        } catch {
            lastError = error.localizedDescription
            log.error("\(self.source.name, privacy: .public) rate refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Plain GET with an ephemeral session: no cookies, cache, or credentials.
    public static func download(_ url: URL) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpAdditionalHeaders = ["User-Agent": "Omni"]
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(from: url)
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
