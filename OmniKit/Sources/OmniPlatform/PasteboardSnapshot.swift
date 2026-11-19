import AppKit
import OmniCore

/// A copy of everything on a pasteboard, so Omni can borrow the pasteboard
/// (to paste text, or to read a selection) and put it back exactly.
///
/// Limitation: types an app only promised (lazy data) are materialized at
/// capture time; types whose data can't be read are skipped.
public struct PasteboardSnapshot: Sendable, Equatable {
    /// One dictionary per pasteboard item: type identifier → data.
    public let items: [[String: Data]]

    public var isEmpty: Bool { items.isEmpty }

    @MainActor
    public static func capture(_ pasteboard: NSPasteboard = .general) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.reduce(into: [String: Data]()) { result, type in
                if let data = item.data(forType: type) { result[type.rawValue] = data }
            }
        }
        return PasteboardSnapshot(items: items.filter { !$0.isEmpty })
    }

    /// Writes the snapshot back, tagged as Omni's own write so clipboard
    /// history doesn't record it again. Returns the new change count.
    @MainActor
    @discardableResult
    public func restore(to pasteboard: NSPasteboard = .general) -> Int {
        pasteboard.clearContents()
        let restored = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: NSPasteboard.PasteboardType(type)) }
            item.setData(Data(), forType: NSPasteboard.PasteboardType(PasteboardTypes.omniInternal))
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
        return pasteboard.changeCount
    }
}

/// Temporary pasteboard writes that other clipboard tools should ignore.
@MainActor
public enum TemporaryPasteboard {
    /// Puts `text` on the pasteboard marked transient and Omni-internal.
    /// Returns the change count after writing.
    @discardableResult
    public static func write(_ text: String, to pasteboard: NSPasteboard = .general) -> Int {
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType(PasteboardTypes.transient))
        item.setData(Data(), forType: NSPasteboard.PasteboardType(PasteboardTypes.omniInternal))
        pasteboard.writeObjects([item])
        return pasteboard.changeCount
    }

    /// Pastes `text` into the frontmost app via ⌘V, then restores the previous
    /// pasteboard after `restoreDelay` unless something else changed it meanwhile.
    /// Needs Accessibility (posts a keystroke).
    public static func paste(
        _ text: String, restoreDelay: Duration = .milliseconds(400), then: (@MainActor () -> Void)? = nil,
        pasteboard: NSPasteboard = .general
    ) {
        let snapshot = PasteboardSnapshot.capture(pasteboard)
        let ourChange = write(text, to: pasteboard)
        KeySender.paste()
        then?()
        Task { @MainActor in
            try? await Task.sleep(for: restoreDelay)
            // If the user or another app copied something meanwhile, keep theirs.
            guard pasteboard.changeCount == ourChange else { return }
            if snapshot.isEmpty {
                pasteboard.clearContents()
            } else {
                snapshot.restore(to: pasteboard)
            }
        }
    }
}

/// Marks a short period in which Omni borrows the pasteboard (e.g. a
/// simulated ⌘C to read a selection). Clipboard history doesn't look at the
/// pasteboard while a lease is active, so the borrowed content is never
/// recorded; it checks again once the lease ends (by then the original
/// content is back, tagged as Omni's own write).
@MainActor
public enum PasteboardLease {
    private static var holders = 0
    private static var expiry: ContinuousClock.Instant?

    /// True while some lease is active. Leases expire after `maxDuration`
    /// even if never ended, so history can't stay paused by a bug.
    public static var isActive: Bool {
        guard holders > 0, let expiry else { return false }
        if ContinuousClock.now >= expiry {
            holders = 0
            self.expiry = nil
            return false
        }
        return true
    }

    public static let maxDuration: Duration = .seconds(2)

    public static func begin() {
        holders += 1
        expiry = .now + maxDuration
    }

    public static func end() {
        holders = max(0, holders - 1)
        if holders == 0 { expiry = nil }
    }
}
