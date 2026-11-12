import CryptoKit
import Foundation

/// The kind of content in a history entry.
public enum ClipKind: String, Codable, Sendable, CaseIterable {
    case text, image, files
}

/// Content read from the pasteboard, ready to store. Never logged.
public struct CapturedClip: Sendable, Equatable {
    public let kind: ClipKind
    /// Text for `.text`; for `.files`, the paths joined by newlines.
    public let text: String?
    public let fileURLs: [URL]
    /// Encoded image data (PNG or TIFF) for `.image`.
    public let imageData: Data?
    public let sourceBundleID: String?
    public let sourceAppName: String?

    /// Largest text stored (in UTF-8 bytes); larger copies are skipped.
    public static let maxTextBytes = 2_000_000
    /// Largest image stored; larger copies are skipped.
    public static let maxImageBytes = 25_000_000

    public static func text(_ text: String, app: String? = nil, appName: String? = nil) -> CapturedClip {
        CapturedClip(kind: .text, text: text, fileURLs: [], imageData: nil, sourceBundleID: app, sourceAppName: appName)
    }

    public static func files(_ urls: [URL], app: String? = nil, appName: String? = nil) -> CapturedClip {
        CapturedClip(
            kind: .files, text: urls.map(\.path).joined(separator: "\n"), fileURLs: urls,
            imageData: nil, sourceBundleID: app, sourceAppName: appName
        )
    }

    public static func image(_ data: Data, app: String? = nil, appName: String? = nil) -> CapturedClip {
        CapturedClip(kind: .image, text: nil, fileURLs: [], imageData: data, sourceBundleID: app, sourceAppName: appName)
    }

    /// Identity for de-duplication: same kind and same bytes.
    public var contentHash: String {
        var hasher = SHA256()
        hasher.update(data: Data(kind.rawValue.utf8))
        if let text { hasher.update(data: Data(text.utf8)) }
        if let imageData { hasher.update(data: imageData) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public var byteSize: Int {
        (text?.utf8.count ?? 0) + (imageData?.count ?? 0)
    }

    public var exceedsLimits: Bool {
        (text?.utf8.count ?? 0) > Self.maxTextBytes || (imageData?.count ?? 0) > Self.maxImageBytes
    }
}
