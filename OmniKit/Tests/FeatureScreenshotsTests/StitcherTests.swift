import CoreGraphics
import Foundation
import Testing
@testable import FeatureScreenshots

struct StitcherTests {
    /// Content rows 0..<n as unique fingerprints; header/footer are fixed rows.
    func frames(content: Int, height: Int, offsets: [Int], header: Int = 0, footer: Int = 0) -> [[UInt64]] {
        let body = height - header - footer
        return offsets.map { offset in
            (0..<header).map { UInt64(1_000_000 + $0) }
                + (0..<body).map { UInt64(min(offset + $0, content - 1) * 7 + 1) }
                + (0..<footer).map { UInt64(2_000_000 + $0) }
        }
    }

    func rows(_ frames: [[UInt64]], _ plan: [ScrollStitcher.Slice]) -> [UInt64] {
        plan.flatMap { Array(frames[$0.frame][$0.rows]) }
    }

    @Test func stitchesPlainScroll() {
        let f = frames(content: 500, height: 100, offsets: [0, 40, 80, 120])
        let plan = ScrollStitcher.plan(frames: f)
        #expect(rows(f, plan) == (0..<220).map { UInt64($0 * 7 + 1) })
    }

    @Test func fixedHeaderAndFooterAppearOnce() {
        let f = frames(content: 500, height: 100, offsets: [0, 30, 60], header: 12, footer: 8)
        let plan = ScrollStitcher.plan(frames: f)
        let out = rows(f, plan)
        let header = (0..<12).map { UInt64(1_000_000 + $0) }
        let footer = (0..<8).map { UInt64(2_000_000 + $0) }
        #expect(out == header + (0..<(80 + 60)).map { UInt64($0 * 7 + 1) } + footer)
    }

    @Test func stopsWhenContentEnds() {
        // Content ends at row 150: the last two frames are identical.
        let f = frames(content: 150, height: 100, offsets: [0, 50, 50])
        #expect(ScrollStitcher.analyze(previous: f[1], next: f[2])?.newRows == 0)
        #expect(rows(f, ScrollStitcher.plan(frames: f)).count == 150)
    }

    @Test func noOverlapIsRejected() {
        let f = frames(content: 1000, height: 100, offsets: [0, 300])
        #expect(ScrollStitcher.analyze(previous: f[0], next: f[1]) == nil)
        #expect(ScrollStitcher.plan(frames: f).count == 1)
    }

    @Test func blankRowsDontFakeAMatch() {
        // Mostly blank page: only informative rows count.
        let blank: UInt64 = 42
        var a = [UInt64](repeating: blank, count: 100)
        var b = a
        for i in stride(from: 0, to: 100, by: 9) { a[i] = UInt64(i + 100) }
        for i in stride(from: 0, to: 100, by: 9) where i >= 27 { b[i - 27] = UInt64(i + 100) }
        let step = ScrollStitcher.analyze(previous: a, next: b) { $0 == blank }
        #expect(step?.newRows == 27)
    }

    @Test func realImagesRoundTrip() throws {
        let tall = Synthetic.gradient(width: 64, height: 400)
        let shots = try [0, 70, 140].map { try #require(tall.cropping(to: CGRect(x: 0, y: $0, width: 64, height: 120))) }
        let hashed = try shots.map { try #require(ScrollStitcher.rowHashes(of: $0)) }
        let plan = ScrollStitcher.plan(frames: hashed.map(\.hashes))
        let out = try #require(ScrollStitcher.compose(shots, plan: plan))
        #expect(out.height == 260)
        let expected = try #require(tall.cropping(to: CGRect(x: 0, y: 0, width: 64, height: 260)))
        #expect(Synthetic.pixels(out) == Synthetic.pixels(expected))
    }
}
