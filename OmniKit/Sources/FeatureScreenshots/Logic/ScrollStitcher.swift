import CoreGraphics
import Foundation

/// Joins frames of a scrolling area into one tall image (experimental).
///
/// Works on row fingerprints, so it's pure and testable. Each new frame is
/// compared with the previous one: rows identical at the same position at
/// the top/bottom are a fixed header/footer; the scroll distance is the
/// shift at which the remaining rows line up best.
public enum ScrollStitcher {
    public struct Step: Equatable, Sendable {
        public var header: Int
        public var footer: Int
        /// Rows the new frame adds at the bottom. 0 = the content stopped scrolling.
        public var newRows: Int
    }

    /// One slice of the output: rows `rows` of frame `frame`.
    public struct Slice: Equatable, Sendable {
        public var frame: Int
        public var rows: Range<Int>
    }

    static let minimumInformativeRows = 6
    static let matchThreshold = 0.92

    /// nil if no trustworthy overlap was found (content changed, or scrolled
    /// further than a frame).
    public static func analyze(previous: [UInt64], next: [UInt64], uniform: (UInt64) -> Bool = { _ in false }) -> Step? {
        let h = previous.count
        guard h == next.count, h > 0 else { return nil }
        if previous == next { return Step(header: 0, footer: 0, newRows: 0) }
        let cap = h / 3
        var header = 0
        while header < cap && previous[header] == next[header] { header += 1 }
        var footer = 0
        while footer < cap && previous[h - 1 - footer] == next[h - 1 - footer] { footer += 1 }
        let body = h - header - footer
        guard body > minimumInformativeRows else { return nil }
        let prevBody = Array(previous[header..<(h - footer)])
        let nextBody = Array(next[header..<(h - footer)])

        var best: (shift: Int, score: Double)?
        for shift in 1..<body {
            let overlap = body - shift
            var informative = 0, matched = 0
            for i in 0..<overlap {
                let row = nextBody[i]
                guard !uniform(row) else { continue }
                informative += 1
                if prevBody[shift + i] == row { matched += 1 }
            }
            guard informative >= minimumInformativeRows else { continue }
            let score = Double(matched) / Double(informative)
            if score >= matchThreshold, score > (best?.score ?? 0) + 1e-9 { best = (shift, score) }
            if score == 1 { break } // smallest shift with a perfect match
        }
        guard let best else { return nil }
        return Step(header: header, footer: footer, newRows: best.shift)
    }

    /// The output layout for frames of equal height. Stops at the first
    /// frame that doesn't line up or doesn't move.
    public static func plan(frames: [[UInt64]], uniform: (UInt64) -> Bool = { _ in false }) -> [Slice] {
        guard let first = frames.first else { return [] }
        let h = first.count
        var steps: [Step] = []
        for index in 1..<max(frames.count, 1) {
            guard let step = analyze(previous: frames[index - 1], next: frames[index], uniform: uniform), step.newRows > 0 else { break }
            steps.append(step)
        }
        guard let firstStep = steps.first, let lastStep = steps.last else {
            return [Slice(frame: 0, rows: 0..<h)]
        }
        var slices = [Slice(frame: 0, rows: 0..<(h - firstStep.footer))]
        for (offset, step) in steps.enumerated() {
            let bottom = h - step.footer
            slices.append(Slice(frame: offset + 1, rows: (bottom - step.newRows)..<bottom))
        }
        if lastStep.footer > 0 {
            slices.append(Slice(frame: steps.count, rows: (h - lastStep.footer)..<h))
        }
        return slices
    }

    // MARK: - Images

    /// FNV-1a fingerprint of each row, from an sRGB RGBA8 rendering.
    public static func rowHashes(of image: CGImage) -> (hashes: [UInt64], uniform: Set<UInt64>)? {
        let width = image.width, height = image.height
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var hashes: [UInt64] = []
        var uniform = Set<UInt64>()
        hashes.reserveCapacity(height)
        for row in 0..<height { // CGContext memory is top row first
            var hash: UInt64 = 0xcbf2_9ce4_8422_2325
            let start = row * bytesPerRow
            var same = true
            for i in start..<(start + bytesPerRow) {
                hash = (hash ^ UInt64(data[i])) &* 0x100_0000_01b3
                if same && data[i] != data[start + (i - start) % 4] { same = false }
            }
            hashes.append(hash)
            if same { uniform.insert(hash) }
        }
        return (hashes, uniform)
    }

    /// Builds the tall image from frames and a plan.
    public static func compose(_ frames: [CGImage], plan: [Slice]) -> CGImage? {
        guard let first = frames.first else { return nil }
        let width = first.width
        let height = plan.reduce(0) { $0 + $1.rows.count }
        guard height > 0, let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: first.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        context.interpolationQuality = .none
        var y = 0 // from the top
        for slice in plan {
            let frame = frames[slice.frame]
            guard let part = frame.cropping(to: CGRect(x: 0, y: slice.rows.lowerBound, width: width, height: slice.rows.count)) else { continue }
            // CG's origin is bottom-left.
            context.draw(part, in: CGRect(x: 0, y: height - y - slice.rows.count, width: width, height: slice.rows.count))
            y += slice.rows.count
        }
        return context.makeImage()
    }
}
