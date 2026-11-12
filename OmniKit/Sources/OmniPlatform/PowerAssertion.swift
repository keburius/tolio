import Foundation
import IOKit.pwr_mgt

/// Holds an IOKit power assertion that keeps the Mac (and optionally the
/// display) from idle-sleeping. Released on `release()`.
@MainActor
public final class PowerAssertion {
    public enum Kind: String, Sendable {
        /// Keeps the display on (implies the system stays awake).
        case display = "PreventUserIdleDisplaySleep"
        /// Lets the display sleep but keeps the system awake.
        case system = "PreventUserIdleSystemSleep"
    }

    private var assertionID: IOPMAssertionID = 0
    public private(set) var heldKind: Kind?

    public init() {}

    public var isHeld: Bool { heldKind != nil }

    /// Creates (or replaces) the assertion. Returns false if IOKit refused.
    @discardableResult
    public func hold(_ kind: Kind, reason: String) -> Bool {
        if heldKind == kind { return true }
        release()
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kind.rawValue as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &id
        )
        guard result == kIOReturnSuccess else { return false }
        assertionID = id
        heldKind = kind
        return true
    }

    public func release() {
        guard heldKind != nil else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        heldKind = nil
    }
}
