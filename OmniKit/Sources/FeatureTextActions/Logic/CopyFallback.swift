import Foundation

/// The pasteboard operations the ⌘C fallback needs, so the borrow/restore
/// logic can be tested against a fake.
@MainActor
public protocol BorrowablePasteboard: AnyObject {
    associatedtype Snapshot
    var changeCount: Int { get }
    var types: Set<String> { get }
    var string: String? { get }
    func snapshot() -> Snapshot
    /// Puts the snapshot back (tagged as Omni's own write); returns the new change count.
    func restore(_ snapshot: Snapshot) -> Int
    func clear()
    var snapshotIsEmpty: (Snapshot) -> Bool { get }
}

/// Reads a selection by simulating ⌘C, then puts the pasteboard back.
///
/// Rules: (1) restore only if the pasteboard still holds what the copy
/// produced, so a copy the user makes meanwhile wins; (2) never return
/// concealed (password-manager) content; (3) only plain text counts; files
/// or images mean ⌘C copied something that isn't a text selection.
@MainActor
public enum CopyFallback {
    public enum Outcome: Equatable, Sendable {
        case text(String)
        /// ⌘C didn't change the pasteboard: nothing selected (or no ⌘C support).
        case nothingCopied
        case discarded(Reason)
    }

    public enum Reason: Equatable, Sendable {
        case concealed
        case notText
        case empty
        /// Someone else wrote the pasteboard during the copy; theirs was kept.
        case raced
    }

    static let concealedTypes: Set<String> = ["org.nspasteboard.ConcealedType", "com.agilebits.onepassword"]
    static let fileTypes: Set<String> = ["public.file-url", "NSFilenamesPboardType"]
    static let textTypes: Set<String> = ["public.utf8-plain-text", "NSStringPboardType", "public.utf16-plain-text"]

    /// - Parameters:
    ///   - sendCopy: posts ⌘C.
    ///   - wait: sleeps between polls; `timeout` bounds the total wait.
    public static func read<P: BorrowablePasteboard>(
        from pasteboard: P,
        sendCopy: () -> Void,
        wait: (Duration) async -> Void,
        pollInterval: Duration = .milliseconds(10),
        timeout: Duration = .milliseconds(300)
    ) async -> Outcome {
        let saved = pasteboard.snapshot()
        let before = pasteboard.changeCount
        sendCopy()
        var waited: Duration = .zero
        while pasteboard.changeCount == before && waited < timeout {
            await wait(pollInterval)
            waited += pollInterval
        }
        guard pasteboard.changeCount != before else { return .nothingCopied }
        let copied = pasteboard.changeCount
        // Give the app a moment to finish writing all of its types (adding
        // data doesn't bump the change count; another write would).
        await wait(pollInterval)
        guard pasteboard.changeCount == copied else { return .discarded(.raced) }
        let types = pasteboard.types
        let outcome: Outcome
        if !types.isDisjoint(with: concealedTypes) {
            outcome = .discarded(.concealed)
        } else if !types.isDisjoint(with: fileTypes) || types.isDisjoint(with: textTypes) {
            outcome = .discarded(.notText)
        } else if let text = pasteboard.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            outcome = .text(text)
        } else {
            outcome = .discarded(.empty)
        }
        // Put the previous contents back, unless the pasteboard moved on again.
        if pasteboard.changeCount == copied {
            if pasteboard.snapshotIsEmpty(saved) { pasteboard.clear() } else { _ = pasteboard.restore(saved) }
        } else {
            return .discarded(.raced)
        }
        return outcome
    }
}
