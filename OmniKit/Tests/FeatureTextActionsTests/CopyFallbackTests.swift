import Testing
@testable import FeatureTextActions

/// A pasteboard whose "app" responds to ⌘C as configured.
@MainActor
final class FakePasteboard: BorrowablePasteboard {
    struct Content: Equatable {
        var types: Set<String>
        var string: String?
    }

    var changeCount = 10
    var content: Content
    var restored: [Content] = []
    var cleared = 0
    /// What the app writes on ⌘C (nil = nothing selected, no write).
    var onCopy: Content?
    /// Something else writes the pasteboard after this many waits.
    var interloper: (afterWaits: Int, content: Content)?
    private var waits = 0

    init(content: Content) { self.content = content }

    var types: Set<String> { content.types }
    var string: String? { content.string }
    func snapshot() -> Content { content }
    func restore(_ snapshot: Content) -> Int {
        content = snapshot
        changeCount += 1
        restored.append(snapshot)
        return changeCount
    }
    func clear() {
        content = Content(types: [], string: nil)
        changeCount += 1
        cleared += 1
    }
    var snapshotIsEmpty: (Content) -> Bool { { $0.types.isEmpty } }

    func sendCopy() {
        guard let onCopy else { return }
        content = onCopy
        changeCount += 1
    }

    func wait() {
        waits += 1
        if let interloper, waits == interloper.afterWaits {
            content = interloper.content
            changeCount += 1
        }
    }
}

@MainActor
struct CopyFallbackTests {
    static let text = "public.utf8-plain-text"
    let original = FakePasteboard.Content(types: [text, "public.html"], string: "previous clipboard")

    private func run(_ pb: FakePasteboard) async -> CopyFallback.Outcome {
        await CopyFallback.read(from: pb, sendCopy: { pb.sendCopy() }, wait: { _ in pb.wait() })
    }

    @Test func readsTextAndRestores() async {
        let pb = FakePasteboard(content: original)
        pb.onCopy = .init(types: [Self.text], string: "selected words")
        #expect(await run(pb) == .text("selected words"))
        #expect(pb.content == original)
        #expect(pb.restored == [original])
    }

    @Test func nothingSelectedLeavesPasteboardAlone() async {
        let pb = FakePasteboard(content: original)
        let before = pb.changeCount
        #expect(await run(pb) == .nothingCopied)
        #expect(pb.changeCount == before)
        #expect(pb.restored.isEmpty)
    }

    @Test func emptyPreviousPasteboardIsClearedAgain() async {
        let pb = FakePasteboard(content: .init(types: [], string: nil))
        pb.onCopy = .init(types: [Self.text], string: "x")
        #expect(await run(pb) == .text("x"))
        #expect(pb.cleared == 1)
        #expect(pb.content.types.isEmpty)
    }

    @Test func concealedIsDiscardedAndRestored() async {
        let pb = FakePasteboard(content: original)
        pb.onCopy = .init(types: [Self.text, "org.nspasteboard.ConcealedType"], string: "hunter2")
        #expect(await run(pb) == .discarded(.concealed))
        #expect(pb.content == original)
    }

    @Test func filesAreNotText() async {
        let pb = FakePasteboard(content: original)
        pb.onCopy = .init(types: ["public.file-url", Self.text], string: "report.pdf")
        #expect(await run(pb) == .discarded(.notText))
        #expect(pb.content == original)
    }

    @Test func imagesAreNotText() async {
        let pb = FakePasteboard(content: original)
        pb.onCopy = .init(types: ["public.png"], string: nil)
        #expect(await run(pb) == .discarded(.notText))
        #expect(pb.content == original)
    }

    @Test func whitespaceOnlyIsEmpty() async {
        let pb = FakePasteboard(content: original)
        pb.onCopy = .init(types: [Self.text], string: "  \n ")
        #expect(await run(pb) == .discarded(.empty))
        #expect(pb.content == original)
    }

    @Test func userCopyDuringReadWins() async {
        // The app copies, then the user copies something before we restore.
        let pb = FakePasteboard(content: original)
        pb.onCopy = .init(types: [Self.text], string: "selected")
        let theirs = FakePasteboard.Content(types: [Self.text], string: "user's new copy")
        pb.interloper = (afterWaits: 1, content: theirs)
        #expect(await run(pb) == .discarded(.raced))
        #expect(pb.content == theirs)
        #expect(pb.restored.isEmpty)
    }
}
