import CoreGraphics
import Foundation
import Testing
@testable import FeatureDropRing

struct RingLayoutTests {
    let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)

    @Test func firstOrbAtTopEvenlySpaced() {
        let layout = RingLayout(count: 4, orbSize: 72, center: CGPoint(x: 800, y: 500), bounds: screen)
        #expect(layout.positions.count == 4)
        #expect(abs(layout.positions[0].x - 800) < 0.001)
        #expect(layout.positions[0].y < 500)
        #expect(layout.positions[1].x > 800) // clockwise: next one is to the right
        let gaps = (0..<4).map { i in hypot(layout.positions[i].x - layout.positions[(i + 1) % 4].x, layout.positions[i].y - layout.positions[(i + 1) % 4].y) }
        #expect(gaps.allSatisfy { abs($0 - gaps[0]) < 0.01 })
    }

    @Test func manyOrbsWidenTheRing() {
        let few = RingLayout(count: 4, orbSize: 72, center: CGPoint(x: 800, y: 500), bounds: screen)
        let many = RingLayout(count: 16, orbSize: 72, center: CGPoint(x: 800, y: 500), bounds: screen)
        #expect(few.radius == RingLayout.minimumRadius)
        #expect(many.radius > few.radius)
    }

    @Test func staysOnScreenNearAnEdge() {
        let layout = RingLayout(count: 8, orbSize: 80, center: CGPoint(x: 5, y: 990), bounds: screen)
        for point in layout.positions {
            #expect(point.x - 40 >= 0 && point.x + 40 <= 1600)
            #expect(point.y - 40 >= 0 && point.y + 40 <= 1000)
        }
    }

    @Test func hitTesting() {
        let layout = RingLayout(count: 6, orbSize: 70, center: CGPoint(x: 800, y: 500), bounds: screen)
        #expect(layout.hit(layout.positions[3]) == 3)
        #expect(layout.hit(CGPoint(x: layout.positions[2].x + 20, y: layout.positions[2].y)) == 2)
        #expect(layout.hit(layout.center) == nil)
    }
}

struct FileTransferTests {
    func makeTemp() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dropring-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func copyNeverOverwrites() throws {
        let root = try makeTemp()
        let source = root.appendingPathComponent("src"), target = root.appendingPathComponent("dst")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let file = source.appendingPathComponent("Report.pdf")
        try Data("new".utf8).write(to: file)
        try Data("old".utf8).write(to: target.appendingPathComponent("Report.pdf"))
        try Data("old2".utf8).write(to: target.appendingPathComponent("Report 2.pdf"))

        let result = FileTransfer.transfer([file], to: target, mode: .copy)
        #expect(result.done.map(\.lastPathComponent) == ["Report 3.pdf"])
        #expect(try String(contentsOf: target.appendingPathComponent("Report.pdf"), encoding: .utf8) == "old")
        #expect(FileManager.default.fileExists(atPath: file.path)) // copy keeps the original
    }

    @Test func moveRemovesOriginalAndSkipsSameFolder() throws {
        let root = try makeTemp()
        let target = root.appendingPathComponent("dst")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("notes")
        try Data("x".utf8).write(to: file)

        let moved = FileTransfer.transfer([file], to: target, mode: .move)
        #expect(moved.done.count == 1)
        #expect(!FileManager.default.fileExists(atPath: file.path))

        let again = FileTransfer.transfer(moved.done, to: target, mode: .move)
        #expect(again.skipped.count == 1 && again.done.isEmpty)
    }

    @Test func folderCantGoInsideItself() throws {
        let root = try makeTemp()
        let inner = root.appendingPathComponent("a/b")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        let result = FileTransfer.transfer([root.appendingPathComponent("a")], to: inner, mode: .move)
        #expect(result.failed.count == 1)
        #expect(FileManager.default.fileExists(atPath: inner.path))
    }
}

struct ShakeDetectorTests {
    /// Side-to-side strokes of `width` points, `step` seconds apart.
    func shake(_ detector: inout ShakeDetector, strokes: Int, width: Double, step: TimeInterval) -> Bool {
        var time = 0.0, x = 500.0, fired = false
        for stroke in 0..<strokes {
            let direction = stroke.isMultiple(of: 2) ? 1.0 : -1.0
            for _ in 0..<5 {
                x += direction * width / 5
                time += step / 5
                if detector.add(x: x, time: time) { fired = true }
            }
        }
        return fired
    }

    @Test func quickShakeFires() {
        var detector = ShakeDetector(sensitivity: 0.5)
        #expect(shake(&detector, strokes: 7, width: 80, step: 0.07))
    }

    @Test func slowOrSmallMovesDont() {
        var slow = ShakeDetector(sensitivity: 0.5)
        #expect(!shake(&slow, strokes: 7, width: 80, step: 0.4))
        var small = ShakeDetector(sensitivity: 0.0)
        #expect(!shake(&small, strokes: 7, width: 30, step: 0.07))
    }

    @Test func higherSensitivityNeedsLess() {
        var high = ShakeDetector(sensitivity: 1)
        #expect(shake(&high, strokes: 5, width: 30, step: 0.07))
    }

    @Test func straightLineDoesNotFire() {
        var detector = ShakeDetector(sensitivity: 1)
        var fired = false
        for i in 0..<200 where detector.add(x: Double(i) * 10, time: Double(i) * 0.01) { fired = true }
        #expect(!fired)
    }
}

struct RingItemTests {
    @Test func initials() {
        #expect(RingItem.initials("Jens Olson") == "JO")
        #expect(RingItem.initials("ana") == "A")
        #expect(RingItem.initials("  ") == "?")
    }

    @Test func roundTripsThroughJSON() throws {
        let items = RingItem.starterRing(home: URL(fileURLWithPath: "/Users/test")) + [
            RingItem(kind: .contact(name: "Jens", handle: "+995555", channel: .messages)),
            RingItem(kind: .shortcut(name: "Resize")),
            RingItem(kind: .app(path: "/Applications/Preview.app")),
        ]
        let decoded = try JSONDecoder().decode([RingItem].self, from: JSONEncoder().encode(items))
        #expect(decoded == items)
        #expect(items[0].folderURL?.path == "/Users/test/Desktop")
    }
}

struct ShareMatchTests {
    let titles = ["AirDrop", "Mail", "Messages", "Notes", "WhatsApp Desktop", "Slack", "Add to Photos"]

    @Test func matchesTheAppsOwnService() {
        #expect(ShareServices.bestMatch(appName: "Messages", titles: titles) == 2)
        #expect(ShareServices.bestMatch(appName: "Slack", titles: titles) == 5)
        #expect(ShareServices.bestMatch(appName: "WhatsApp", titles: titles) == 4)
        #expect(ShareServices.bestMatch(appName: "air drop", titles: titles) == 0)
    }

    @Test func otherAppsOpenNormally() {
        #expect(ShareServices.bestMatch(appName: "Preview", titles: titles) == nil)
        #expect(ShareServices.bestMatch(appName: "M", titles: titles) == nil)
        #expect(ShareServices.bestMatch(appName: "Photos", titles: ["Notes"]) == nil)
    }
}
