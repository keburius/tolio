import AppKit
@testable import FeatureClipboard
import OmniCore
import OmniPlatform
import Testing

/// Drives the real monitor against a private named pasteboard.
@MainActor
struct ClipboardMonitorTests {
    private let pasteboard = NSPasteboard(name: NSPasteboard.Name("omni.tests.\(UUID().uuidString)"))

    private func makeMonitor(
        app: String? = "com.apple.TextEdit", excluded: Set<String> = [], into captured: Box
    ) -> ClipboardMonitor {
        ClipboardMonitor(
            pasteboard: pasteboard,
            excludedApps: { excluded },
            frontmostApp: { ClipboardMonitor.Source(bundleID: app, name: "TextEdit") }
        ) { captured.items.append($0) }
    }

    final class Box { var items: [CapturedClip] = [] }

    private func write(_ text: String, extraTypes: [String] = []) {
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        for type in extraTypes { item.setData(Data(), forType: NSPasteboard.PasteboardType(type)) }
        pasteboard.writeObjects([item])
    }

    @Test func capturesPlainTextWithSource() {
        let box = Box()
        let monitor = makeMonitor(into: box)
        write("hello")
        monitor.poll()
        #expect(box.items == [.text("hello", app: "com.apple.TextEdit", appName: "TextEdit")])
        pasteboard.releaseGlobally()
    }

    @Test func ignoresUnchangedPasteboard() {
        let box = Box()
        let monitor = makeMonitor(into: box)
        write("once")
        monitor.poll()
        monitor.poll()
        #expect(box.items.count == 1)
        pasteboard.releaseGlobally()
    }

    /// The selection popup's ⌘C fallback: the borrowed selection is never
    /// recorded, and neither is the restored original.
    @Test func borrowedPasteboardIsNeverRecorded() {
        write("original")
        let box = Box()
        let monitor = makeMonitor(into: box)
        let snapshot = PasteboardSnapshot.capture(pasteboard)
        PasteboardLease.begin()
        write("selected text")
        monitor.poll()
        snapshot.restore(to: pasteboard)
        PasteboardLease.end()
        monitor.poll()
        #expect(box.items.isEmpty)
        #expect(pasteboard.string(forType: .string) == "original")
        // A real copy afterwards is recorded again.
        write("later copy")
        monitor.poll()
        #expect(box.items == [.text("later copy", app: "com.apple.TextEdit", appName: "TextEdit")])
        pasteboard.releaseGlobally()
    }

    @Test func preExistingContentIsNotRecorded() {
        write("before monitoring")
        let box = Box()
        let monitor = makeMonitor(into: box)
        monitor.poll()
        #expect(box.items.isEmpty)
        pasteboard.releaseGlobally()
    }

    @Test func concealedItemsAreNeverCaptured() {
        let box = Box()
        let monitor = makeMonitor(into: box)
        write("hunter2", extraTypes: [PasteboardTypes.concealed])
        monitor.poll()
        write("secret", extraTypes: [PasteboardTypes.transient])
        monitor.poll()
        write("own", extraTypes: [PasteboardTypes.omniInternal])
        monitor.poll()
        #expect(box.items.isEmpty)
        pasteboard.releaseGlobally()
    }

    @Test func excludedAppsAreNeverCaptured() {
        let box = Box()
        let monitor = makeMonitor(app: "com.example.chat", excluded: ["com.example.chat"], into: box)
        write("private")
        monitor.poll()
        let pm = makeMonitor(app: "com.1password.1password", into: box)
        write("unmarked password")
        pm.poll()
        #expect(box.items.isEmpty)
        pasteboard.releaseGlobally()
    }

    @Test func filesWinOverTheirNames() {
        let box = Box()
        let monitor = makeMonitor(into: box)
        pasteboard.clearContents()
        let url = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        pasteboard.writeObjects([url as NSURL])
        monitor.poll()
        #expect(box.items.first?.kind == .files)
        #expect(box.items.first?.fileURLs == [url])
        pasteboard.releaseGlobally()
    }

    @Test func whitespaceOnlyTextIsIgnored() {
        let box = Box()
        let monitor = makeMonitor(into: box)
        write("   \n ")
        monitor.poll()
        #expect(box.items.isEmpty)
        pasteboard.releaseGlobally()
    }

    @Test func timerRunsOnlyWhileStarted() {
        let monitor = makeMonitor(into: Box())
        #expect(!monitor.isRunning)
        monitor.start()
        #expect(monitor.isRunning)
        monitor.stop()
        #expect(!monitor.isRunning)
        pasteboard.releaseGlobally()
    }
}
