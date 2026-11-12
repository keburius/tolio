import AppKit
@testable import FeatureClipboard
import Foundation
import Testing

struct ClipboardStoreTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("clipstore-\(UUID().uuidString)")
    }

    private func pngData(width: Int = 40, height: Int = 20) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        return rep.representation(using: .png, properties: [:])!
    }

    @Test func insertsAndListsNewestFirst() throws {
        let store = try ClipboardStore(directory: nil)
        try store.insert(.text("first"), at: now)
        try store.insert(.text("second"), at: now.addingTimeInterval(1))
        #expect(try store.recent(limit: 10).map(\.text) == ["second", "first"])
    }

    @Test func historySurvivesReopen() throws {
        let dir = tempDir()
        do {
            let store = try ClipboardStore(directory: dir)
            try store.insert(.text("persisted"), at: now)
            try store.insert(.image(pngData()), at: now.addingTimeInterval(1))
        }
        let reopened = try ClipboardStore(directory: dir)
        let records = try reopened.recent(limit: 10)
        #expect(records.map(\.kind) == [.image, .text])
        #expect(records.last?.text == "persisted")
        let imageURL = try #require(reopened.imageURL(for: records[0]))
        #expect(FileManager.default.fileExists(atPath: imageURL.path))
    }

    @Test func storeFolderIsPrivate() throws {
        let dir = tempDir()
        _ = try ClipboardStore(directory: dir)
        let permissions = try FileManager.default.attributesOfItem(atPath: dir.path)[.posixPermissions] as? Int
        #expect(permissions == 0o700)
    }

    @Test func duplicateMovesToTopInsteadOfDuplicating() throws {
        let store = try ClipboardStore(directory: nil)
        try store.insert(.text("a"), at: now)
        try store.insert(.text("b"), at: now.addingTimeInterval(1))
        try store.insert(.text("a"), at: now.addingTimeInterval(2))
        #expect(try store.recent(limit: 10).map(\.text) == ["a", "b"])
        #expect(try store.count() == 2)
    }

    @Test func imagesGetPNGAndThumbnailWithDimensions() throws {
        let store = try ClipboardStore(directory: nil)
        let record = try store.insert(.image(pngData(width: 300, height: 200)), at: now)
        #expect(record.pixelWidth == 300)
        #expect(record.pixelHeight == 200)
        #expect(record.title == "Image 300 × 200")
        let thumb = try #require(store.thumbnailURL(for: record))
        let image = try #require(NSImage(contentsOf: thumb))
        #expect(max(image.size.width, image.size.height) <= CGFloat(ImageProcessing.thumbnailMaxPixels))
    }

    @Test func unreadableImageThrows() throws {
        let store = try ClipboardStore(directory: nil)
        #expect(throws: ClipboardStore.Failure.imageUnreadable) {
            try store.insert(.image(Data("not an image".utf8)), at: now)
        }
    }

    @Test func filesAreStoredAsReferences() throws {
        let store = try ClipboardStore(directory: nil)
        let urls = [URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.pdf")]
        let record = try store.insert(.files(urls), at: now)
        #expect(record.fileURLs == urls)
        #expect(record.title == "a.txt, b.pdf")
    }

    @Test func searchUsesPrefixesAndPinnedFirst() throws {
        let store = try ClipboardStore(directory: nil)
        try store.insert(.text("meeting notes for tuesday"), at: now)
        let pinned = try store.insert(.text("tuesday standup link"), at: now.addingTimeInterval(-100))
        try store.insert(.text("unrelated"), at: now.addingTimeInterval(1))
        try store.setPinned(true, id: try #require(pinned.id))
        #expect(try store.search("tues", limit: 10).map(\.text) == ["tuesday standup link", "meeting notes for tuesday"])
        #expect(try store.search("meet tue", limit: 10).map(\.text) == ["meeting notes for tuesday"])
        #expect(try store.search("zzz", limit: 10).isEmpty)
    }

    @Test func searchFindsFilePathsAndPunctuation() throws {
        let store = try ClipboardStore(directory: nil)
        try store.insert(.files([URL(fileURLWithPath: "/Users/me/Report.pdf")]), at: now)
        try store.insert(.text("a -> b"), at: now)
        #expect(try store.search("report", limit: 10).count == 1)
        #expect(try store.search("->", limit: 10).map(\.text) == ["a -> b"])
    }

    @Test func pruneKeepsPinnedAndRespectsCountAndAge() throws {
        let store = try ClipboardStore(directory: nil)
        let old = try store.insert(.text("old pinned"), at: now.addingTimeInterval(-90 * 86_400))
        try store.setPinned(true, id: try #require(old.id))
        try store.insert(.text("old"), at: now.addingTimeInterval(-40 * 86_400))
        for i in 0..<5 { try store.insert(.text("new \(i)"), at: now.addingTimeInterval(Double(i))) }

        let removed = try store.prune(maxItems: 3, maxAge: 30 * 86_400, now: now)
        #expect(removed == 3) // "old" (age and count) + "new 0", "new 1" (count)
        #expect(try store.recent(limit: 10).map(\.text) == ["old pinned", "new 4", "new 3", "new 2"])
    }

    @Test func pruneDeletesImageFiles() throws {
        let store = try ClipboardStore(directory: nil)
        let record = try store.insert(.image(pngData()), at: now.addingTimeInterval(-100 * 86_400))
        let file = try #require(store.imageURL(for: record))
        try store.prune(maxItems: 100, maxAge: 86_400, now: now)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func deleteAllCanKeepPinned() throws {
        let store = try ClipboardStore(directory: nil)
        let keep = try store.insert(.text("keep"), at: now)
        try store.insert(.text("drop"), at: now)
        try store.setPinned(true, id: try #require(keep.id))
        try store.deleteAll(keepPinned: true)
        #expect(try store.recent(limit: 10).map(\.text) == ["keep"])
        try store.deleteAll(keepPinned: false)
        #expect(try store.count() == 0)
    }

    @Test func limitsAreEnforcedOnCapture() {
        let huge = String(repeating: "x", count: CapturedClip.maxTextBytes + 1)
        #expect(CapturedClip.text(huge).exceedsLimits)
        #expect(!CapturedClip.text("small").exceedsLimits)
    }

    @Test func titlesSummarizeContent() {
        let record = ClipRecord(
            id: nil, kind: .text, text: "  line one  \nline two", imageFile: nil, thumbnailFile: nil,
            pixelWidth: nil, pixelHeight: nil, contentHash: "h", sourceBundleID: nil, sourceAppName: nil,
            createdAt: now, pinned: false, byteSize: 0
        )
        #expect(record.title == "line one")
    }
}
