import CoreGraphics
import Foundation
import Testing
@testable import FeatureScreenshots

/// Synthetic images with known pixels.
enum Synthetic {
    /// A BGRA sRGB image where pixel (x, y) (top-left origin) = (x % 256, y % 256, (x*y) % 256).
    static func gradient(width: Int, height: Int) -> CGImage {
        var data = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                data[i] = UInt8((x * y) % 256) // B
                data[i + 1] = UInt8(y % 256) // G
                data[i + 2] = UInt8(x % 256) // R
                data[i + 3] = 255
            }
        }
        let provider = CGDataProvider(data: Data(data) as CFData)!
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }

    /// BGRA bytes of `image`, top row first.
    static func pixels(_ image: CGImage) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(
            data: &data, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return data
    }

    static func pixel(_ data: [UInt8], width: Int, x: Int, y: Int) -> [UInt8] {
        let i = (y * width + x) * 4
        return Array(data[i..<(i + 4)])
    }
}

@MainActor
struct RendererTests {
    let base = Synthetic.gradient(width: 300, height: 200)

    @Test func noMarksIsBitExact() throws {
        let doc = AnnotationDocument(pixelWidth: 300, pixelHeight: 200, scale: 2)
        let out = try #require(AnnotationRenderer.render(doc, base: base))
        #expect(out.width == 300 && out.height == 200)
        #expect(Synthetic.pixels(out) == Synthetic.pixels(base))
    }

    @Test func cropKeepsExactPixels() throws {
        var doc = AnnotationDocument(pixelWidth: 300, pixelHeight: 200, scale: 2)
        doc.setCrop(CGRect(x: 10.4, y: 20, width: 100.2, height: 50))
        #expect(doc.crop == CGRect(x: 10, y: 20, width: 101, height: 50))
        let out = try #require(AnnotationRenderer.render(doc, base: base))
        #expect(out.width == 101 && out.height == 50)
        let px = Synthetic.pixels(out)
        // Output (0,0) is source (10,20): R = 10, G = 20, B = 200.
        #expect(Synthetic.pixel(px, width: 101, x: 0, y: 0) == [200, 20, 10, 255])
        #expect(Synthetic.pixel(px, width: 101, x: 100, y: 49) == [UInt8((110 * 69) % 256), 69, 110, 255])
    }

    @Test func marksOnlyChangeTheirArea() throws {
        var doc = AnnotationDocument(pixelWidth: 300, pixelHeight: 200, scale: 1)
        doc.add(Annotation(kind: .box(CGRect(x: 20, y: 20, width: 60, height: 40)), color: .red, lineWidth: 4))
        doc.add(Annotation(kind: .blur(CGRect(x: 200, y: 100, width: 80, height: 80))))
        let out = try #require(AnnotationRenderer.render(doc, base: base))
        #expect(out.width == 300 && out.height == 200)
        let a = Synthetic.pixels(out), b = Synthetic.pixels(base)
        // Box outline is red.
        #expect(Synthetic.pixel(a, width: 300, x: 21, y: 40) == [48, 59, 242, 255])
        // Inside the box and far from marks: untouched.
        #expect(Synthetic.pixel(a, width: 300, x: 50, y: 40) == Synthetic.pixel(b, width: 300, x: 50, y: 40))
        #expect(Synthetic.pixel(a, width: 300, x: 150, y: 10) == Synthetic.pixel(b, width: 300, x: 150, y: 10))
        // The blurred region differs from the original.
        var changed = 0
        for y in 100..<180 { for x in 200..<280 where Synthetic.pixel(a, width: 300, x: x, y: y) != Synthetic.pixel(b, width: 300, x: x, y: y) { changed += 1 } }
        #expect(changed > 80 * 80 / 2)
    }

    @Test func stepsRenumberAfterDelete() {
        var doc = AnnotationDocument(pixelWidth: 100, pixelHeight: 100, scale: 1)
        let ids = (0..<3).map { _ in UUID() }
        for (i, id) in ids.enumerated() {
            doc.add(Annotation(id: id, kind: .step(center: CGPoint(x: 10 + i * 20, y: 10), diameter: 16)))
        }
        doc.add(Annotation(kind: .box(CGRect(x: 0, y: 50, width: 20, height: 20))))
        #expect(ids.map { doc.stepNumber(of: $0) } == [1, 2, 3])
        doc.remove(ids[0])
        #expect(doc.stepNumber(of: ids[1]) == 1)
        #expect(doc.stepNumber(of: ids[2]) == 2)
    }

    @Test func degenerateMarksAreDropped() {
        var doc = AnnotationDocument(pixelWidth: 100, pixelHeight: 100, scale: 1)
        doc.add(Annotation(kind: .box(CGRect(x: 5, y: 5, width: 1, height: 30))))
        doc.add(Annotation(kind: .arrow(from: .zero, to: CGPoint(x: 1, y: 1))))
        doc.add(Annotation(kind: .text(origin: .zero, string: "  ", fontSize: 12)))
        #expect(doc.annotations.isEmpty)
    }

    @Test func cropEdgeCases() {
        var doc = AnnotationDocument(pixelWidth: 100, pixelHeight: 80, scale: 2)
        doc.setCrop(CGRect(x: -20, y: -20, width: 500, height: 500))
        #expect(doc.crop == nil) // covers everything
        doc.setCrop(CGRect(x: 90, y: 70, width: 50, height: 50))
        #expect(doc.crop == CGRect(x: 90, y: 70, width: 10, height: 10))
        doc.setCrop(CGRect(x: 5, y: 5, width: 0.5, height: 0.5))
        #expect(doc.crop == nil)
    }

    @Test func hitTestingAndMoving() throws {
        var doc = AnnotationDocument(pixelWidth: 200, pixelHeight: 200, scale: 1)
        let arrow = Annotation(kind: .arrow(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 110, y: 10)), lineWidth: 4)
        let box = Annotation(kind: .box(CGRect(x: 50, y: 50, width: 100, height: 100)), lineWidth: 4)
        doc.add(arrow)
        doc.add(box)
        let size: (String, CGFloat) -> CGSize = { _, _ in CGSize(width: 10, height: 10) }
        #expect(doc.hitTest(CGPoint(x: 60, y: 12), tolerance: 3, textSize: size) == arrow.id)
        #expect(doc.hitTest(CGPoint(x: 50, y: 100), tolerance: 3, textSize: size) == box.id)
        #expect(doc.hitTest(CGPoint(x: 100, y: 100), tolerance: 3, textSize: size) == nil) // hollow middle
        doc.move(box.id, by: CGVector(dx: 10, dy: -5))
        #expect(doc.annotations.last?.kind == .box(CGRect(x: 60, y: 45, width: 100, height: 100)))
    }

    @Test func arrowHeadPointsBack() {
        let (left, tip, right) = ArrowGeometry.head(from: .zero, to: CGPoint(x: 100, y: 0), lineWidth: 5)
        #expect(tip == CGPoint(x: 100, y: 0))
        #expect(left.x < 100 && right.x < 100)
        #expect(abs(left.y + right.y) < 0.0001) // symmetric
        #expect(abs(100 - left.x - 20 * cos(.pi / 7)) < 0.001)
    }
}

struct AlphaBoundsTests {
    @Test func findsVisiblePixels() throws {
        let context = try #require(CGContext(
            data: nil, width: 120, height: 80, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ))
        context.clear(CGRect(x: 0, y: 0, width: 120, height: 80))
        context.setFillColor(CGColor(gray: 0, alpha: 0.02)) // faint shadow edge still counts
        context.fill(CGRect(x: 10, y: 5, width: 90, height: 60)) // CG origin bottom-left
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 30, y: 20, width: 40, height: 30))
        let image = try #require(context.makeImage())
        // Top-left: y = 80 - (5 + 60) = 15.
        #expect(AlphaBounds.visibleRect(of: image) == CGRect(x: 10, y: 15, width: 90, height: 60))
    }

    @Test func emptyImage() throws {
        let context = try #require(CGContext(
            data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ))
        context.clear(CGRect(x: 0, y: 0, width: 10, height: 10))
        #expect(AlphaBounds.visibleRect(of: try #require(context.makeImage())) == nil)
    }
}

@MainActor
struct BrushTests {
    @Test func strokeMovesHitsAndDrops() {
        var doc = AnnotationDocument(pixelWidth: 200, pixelHeight: 200, scale: 1)
        let stroke = Annotation(kind: .stroke([CGPoint(x: 10, y: 10), CGPoint(x: 60, y: 10), CGPoint(x: 60, y: 60)]), lineWidth: 4)
        doc.add(stroke)
        doc.add(Annotation(kind: .stroke([])))
        #expect(doc.annotations.count == 1) // an empty stroke isn't kept
        let size: (String, CGFloat) -> CGSize = { _, _ in .zero }
        #expect(doc.hitTest(CGPoint(x: 35, y: 12), tolerance: 2, textSize: size) == stroke.id)
        #expect(doc.hitTest(CGPoint(x: 35, y: 35), tolerance: 2, textSize: size) == nil)
        doc.move(stroke.id, by: CGVector(dx: 5, dy: 5))
        #expect(doc.annotations[0].kind == .stroke([CGPoint(x: 15, y: 15), CGPoint(x: 65, y: 15), CGPoint(x: 65, y: 65)]))
    }

    @Test func strokeIsDrawnAlongItsPath() throws {
        let base = Synthetic.gradient(width: 100, height: 100)
        var doc = AnnotationDocument(pixelWidth: 100, pixelHeight: 100, scale: 1)
        doc.add(Annotation(kind: .stroke([CGPoint(x: 10, y: 50), CGPoint(x: 50, y: 50), CGPoint(x: 90, y: 50)]), color: .blue, lineWidth: 6))
        let out = try #require(AnnotationRenderer.render(doc, base: base))
        let a = Synthetic.pixels(out), b = Synthetic.pixels(base)
        #expect(Synthetic.pixel(a, width: 100, x: 50, y: 50) != Synthetic.pixel(b, width: 100, x: 50, y: 50))
        #expect(Synthetic.pixel(a, width: 100, x: 50, y: 10) == Synthetic.pixel(b, width: 100, x: 50, y: 10))
    }

    @Test func brushIsTheDefaultAndDeleteRemovesSelection() throws {
        let model = EditorModel(capture: Capture(image: Synthetic.gradient(width: 100, height: 100), scale: 1, date: Date()))
        #expect(model.tool == .brush)
        model.pointerDown(CGPoint(x: 10, y: 10))
        model.pointerDragged(CGPoint(x: 30, y: 20))
        model.pointerDragged(CGPoint(x: 30.3, y: 20)) // under a pixel: skipped
        model.pointerUp(CGPoint(x: 50, y: 40))
        let stroke = try #require(model.document.annotations.first)
        guard case let .stroke(points) = stroke.kind else { Issue.record("not a stroke"); return }
        #expect(points.count == 3)
        #expect(model.selection == nil) // drawing doesn't select
        model.tool = .box
        model.pointerDown(CGPoint(x: 60, y: 60))
        model.pointerUp(CGPoint(x: 90, y: 90))
        #expect(model.selection != nil)
        model.deleteSelection()
        #expect(model.document.annotations.count == 1)
        model.undo()
        #expect(model.document.annotations.count == 2)
        // With nothing selected, Delete removes the newest mark (the box), then the stroke.
        model.selection = nil
        #expect(model.canDelete)
        model.deleteSelection()
        #expect(model.document.annotations.map(\.isStroke) == [true])
        model.deleteSelection()
        #expect(model.document.annotations.isEmpty)
        #expect(!model.canDelete)
    }
}
