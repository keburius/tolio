import CoreGraphics
import Foundation
import Testing
@testable import FeatureScreenshots

struct CaptureGeometryTests {
    // A 1512×982 Retina laptop with a 1920×1080 @1x monitor to its right,
    // aligned at the bottom.
    let laptop = DisplayInfo(id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982), scale: 2)
    let monitor = DisplayInfo(id: 2, frame: CGRect(x: 1512, y: 0, width: 1920, height: 1080), scale: 1)

    @Test func singleRetinaDisplayIsPixelExact() throws {
        let plan = try #require(CaptureGeometry.plan(area: CGRect(x: 100, y: 200, width: 300, height: 150), displays: [laptop, monitor]))
        #expect(plan.scale == 2)
        #expect(plan.pixelWidth == 600 && plan.pixelHeight == 300)
        #expect(plan.pieces.count == 1)
        let piece = plan.pieces[0]
        // Top-left, display-local: y = 982 - (200 + 150).
        #expect(piece.sourceRect == CGRect(x: 100, y: 632, width: 300, height: 150))
        #expect(piece.pixelWidth == 600 && piece.pixelHeight == 300)
        #expect(piece.destination == CGRect(x: 0, y: 0, width: 600, height: 300))
    }

    @Test func halfPointsSnapToRetinaPixels() throws {
        // 0.5 pt is a whole pixel on Retina, so it's kept; 0.3 pt is not.
        let plan = try #require(CaptureGeometry.plan(area: CGRect(x: 10.5, y: 10.3, width: 20, height: 20), displays: [laptop]))
        #expect(plan.area == CGRect(x: 10.5, y: 10, width: 20, height: 20.5))
        #expect(plan.pixelWidth == 40 && plan.pixelHeight == 41)
    }

    @Test func nonRetinaDisplayUsesScaleOne() throws {
        let plan = try #require(CaptureGeometry.plan(area: CGRect(x: 1600, y: 100, width: 101.4, height: 50), displays: [laptop, monitor]))
        #expect(plan.scale == 1)
        #expect(plan.pixelWidth == 102 && plan.pixelHeight == 50)
        #expect(plan.pieces.map(\.displayID) == [2])
        #expect(plan.pieces[0].sourceRect.minX == 88)
    }

    @Test func mixedDPIAreaComposesAtHighestScale() throws {
        let area = CGRect(x: 1400, y: 100, width: 200, height: 100)
        let plan = try #require(CaptureGeometry.plan(area: area, displays: [laptop, monitor]))
        #expect(plan.scale == 2)
        #expect(plan.pixelWidth == 400 && plan.pixelHeight == 200)
        #expect(plan.pieces.count == 2)
        let left = try #require(plan.pieces.first { $0.displayID == 1 })
        let right = try #require(plan.pieces.first { $0.displayID == 2 })
        // Retina part captured at 2x, 1:1 into the output.
        #expect(left.pixelWidth == 224 && left.destination == CGRect(x: 0, y: 0, width: 224, height: 200))
        // 1x part captured at its native 88×100 px and enlarged into 176×200.
        #expect(right.pixelWidth == 88 && right.pixelHeight == 100)
        #expect(right.destination == CGRect(x: 224, y: 0, width: 176, height: 200))
        #expect(right.sourceRect == CGRect(x: 0, y: 1080 - 200, width: 88, height: 100))
        // Pieces tile the output exactly.
        #expect(Int(plan.pieces.map { $0.destination.width * $0.destination.height }.reduce(0, +)) == 400 * 200)
    }

    @Test func areaOffScreenIsClipped() throws {
        // Above the shorter laptop: only the monitor has pixels there.
        let plan = try #require(CaptureGeometry.plan(area: CGRect(x: 1400, y: 1000, width: 200, height: 50), displays: [laptop, monitor]))
        #expect(plan.pieces.map(\.displayID) == [2])
        #expect(CaptureGeometry.plan(area: CGRect(x: -500, y: -500, width: 10, height: 10), displays: [laptop]) == nil)
    }

    @Test func recordingRectIsEven() throws {
        let r = try #require(CaptureGeometry.recordingRect(area: CGRect(x: 0.5, y: 0, width: 100.5, height: 33.5), display: laptop))
        #expect(r.pixelWidth % 2 == 0 && r.pixelHeight % 2 == 0)
        #expect(r.pixelWidth == 200 && r.pixelHeight == 66)
        #expect(r.source.width * 2 == 200)
        let one = try #require(CaptureGeometry.recordingRect(area: CGRect(x: 1512, y: 0, width: 101, height: 51), display: monitor))
        #expect(one.pixelWidth == 100 && one.pixelHeight == 50)
    }

    @Test func primaryDisplay() {
        #expect(CaptureGeometry.primaryDisplay(for: CGRect(x: 1400, y: 100, width: 300, height: 10), displays: [laptop, monitor])?.id == 2)
        #expect(CaptureGeometry.primaryDisplay(for: CGRect(x: 10, y: 10, width: 10, height: 10), displays: [laptop, monitor])?.id == 1)
    }

    @Test func fileNames() {
        let utc = TimeZone(identifier: "UTC")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 17, minute: 20, second: 31))!
        #expect(FileNaming.baseName(.screenshot, date: date, timeZone: utc) == "Screenshot 2026-11-12 at 17.20.31")
        let folder = URL(fileURLWithPath: "/tmp/shots")
        var existing: Set<String> = ["/tmp/shots/Screenshot 2026-11-12 at 17.20.31.png", "/tmp/shots/Screenshot 2026-11-12 at 17.20.31 (2).png"]
        let url = FileNaming.uniqueURL(in: folder, kind: .screenshot, date: date, timeZone: utc) { existing.contains($0.path) }
        #expect(url.lastPathComponent == "Screenshot 2026-11-12 at 17.20.31 (3).png")
        existing.removeAll()
        let video = FileNaming.uniqueURL(in: folder, kind: .recording, date: date, timeZone: utc) { existing.contains($0.path) }
        #expect(video.lastPathComponent == "Screen Recording 2026-11-12 at 17.20.31.mp4")
    }
}
