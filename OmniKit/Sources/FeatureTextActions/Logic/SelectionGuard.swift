import Foundation
import OmniCore

/// Decides whether Omni may look at the selection at all. Pure, so the
/// password-field rules are covered by a decision-table test.
public enum SelectionGuard {
    public enum Decision: Equatable, Sendable {
        /// Read through Accessibility only.
        case accessibilityOnly
        /// Read through Accessibility, and fall back to ⌘C if that gives nothing.
        case accessibilityThenCopy
        case skip(Reason)
    }

    public enum Reason: Equatable, Sendable {
        case secureInput
        case passwordField
        case passwordManager
        case excludedApp
        case ownApp
        case noApp
    }

    public struct Context: Equatable, Sendable {
        public var bundleID: String?
        public var isOwnApp = false
        /// `IsSecureEventInputEnabled()`: some app is protecting typed input (password entry).
        public var secureInputEnabled = false
        /// Role and subrole of the focused element, if any.
        public var role: String?
        public var subrole: String?
        public var userExcluded: Set<String> = []
        public var copyFallbackEnabled = true

        public init(bundleID: String?) { self.bundleID = bundleID }
    }

    static let secureRole = "AXSecureTextField"

    /// Apps where ⌘C on a non-text selection has side effects (copies files).
    /// Accessibility still works there.
    public static let noCopyFallbackApps: Set<String> = ["com.apple.finder"]

    public static func decide(_ c: Context) -> Decision {
        guard let bundleID = c.bundleID else { return .skip(.noApp) }
        if c.isOwnApp { return .skip(.ownApp) }
        if c.secureInputEnabled { return .skip(.secureInput) }
        if c.role == secureRole || c.subrole == secureRole { return .skip(.passwordField) }
        if KnownApps.passwordManagers.contains(bundleID) { return .skip(.passwordManager) }
        if c.userExcluded.contains(bundleID) { return .skip(.excludedApp) }
        if !c.copyFallbackEnabled || noCopyFallbackApps.contains(bundleID) { return .accessibilityOnly }
        return .accessibilityThenCopy
    }
}
