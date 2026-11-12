import AppKit
import Testing
@testable import FeatureScreenshots

struct OCRTests {
    @Test func recognizesRenderedText() async throws {
        let width = 900, height = 260
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 56), .foregroundColor: NSColor.black]
        NSAttributedString(string: "Hello Omni 2026", attributes: attributes).draw(at: CGPoint(x: 30, y: 150))
        NSAttributedString(string: "Second line here", attributes: attributes).draw(at: CGPoint(x: 30, y: 40))
        NSGraphicsContext.current = nil
        let image = try #require(context.makeImage())
        let lines = try await TextRecognizer.lines(in: image)
        #expect(lines == ["Hello Omni 2026", "Second line here"])
    }
}
