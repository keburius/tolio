import CoreGraphics
import Foundation

/// Selected text in another app, as handed to actions.
public struct TextSelection: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        /// Read through Accessibility; the pasteboard was not touched.
        case accessibility
        /// Read with a simulated ⌘C; the pasteboard was restored afterwards.
        case copyFallback
    }

    public var text: String
    public var source: Source
    /// Whether the selection can be replaced. nil = unknown (copy fallback).
    public var isEditable: Bool?
    /// Selection bounds in AppKit screen coordinates, if the app reports them.
    public var bounds: CGRect?
    public var appBundleID: String?

    public init(text: String, source: Source, isEditable: Bool? = nil, bounds: CGRect? = nil, appBundleID: String? = nil) {
        self.text = text
        self.source = source
        self.isEditable = isEditable
        self.bounds = bounds
        self.appBundleID = appBundleID
    }

    /// The text without surrounding whitespace.
    public var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
}
