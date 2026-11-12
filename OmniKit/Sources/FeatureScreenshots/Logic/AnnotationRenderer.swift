import AppKit
import CoreGraphics
import CoreImage

/// Draws annotations with CoreGraphics. The editor's preview and the
/// exported image use this same code, so what you see is what you get.
@MainActor
public enum AnnotationRenderer {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private static var blurCache: [String: CGImage] = [:]

    /// The final image: crop applied, marks drawn, at the capture's exact pixel size.
    /// With no marks and no crop it returns `base` itself (bit-exact).
    public static func render(_ document: AnnotationDocument, base: CGImage) -> CGImage? {
        let output = document.outputRect
        if document.annotations.isEmpty {
            return document.crop == nil ? base : base.cropping(to: output)
        }
        let width = Int(output.width), height = Int(output.height)
        let colorSpace = base.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        // Pixel space, y down, origin at the crop's corner.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: -output.minX, y: -output.minY)
        context.interpolationQuality = .none
        drawImage(base, in: document.bounds, context: context)
        drawAnnotations(document, base: base, in: context)
        return context.makeImage()
    }

    /// Draws all marks. `context` must be in image pixel space with y down.
    public static func drawAnnotations(_ document: AnnotationDocument, base: CGImage, in context: CGContext) {
        for annotation in document.annotations {
            context.saveGState()
            draw(annotation, document: document, base: base, in: context)
            context.restoreGState()
        }
    }

    private static func draw(_ annotation: Annotation, document: AnnotationDocument, base: CGImage, in context: CGContext) {
        let color = annotation.color.cgColor
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(annotation.lineWidth)
        context.setLineJoin(.round)
        switch annotation.kind {
        case let .arrow(from, to):
            context.setLineCap(.round)
            let end = ArrowGeometry.shaftEnd(from: from, to: to, lineWidth: annotation.lineWidth)
            context.move(to: from)
            context.addLine(to: end)
            context.strokePath()
            let (left, tip, right) = ArrowGeometry.head(from: from, to: to, lineWidth: annotation.lineWidth)
            context.move(to: left)
            context.addLine(to: tip)
            context.addLine(to: right)
            context.closePath()
            context.fillPath()
        case let .box(rect):
            context.stroke(rect.insetBy(dx: annotation.lineWidth / 2, dy: annotation.lineWidth / 2))
        case let .highlight(rect):
            // Translucent, so it shows on dark backgrounds too (multiply wouldn't).
            context.setFillColor(annotation.color.cgColor.copy(alpha: 0.38) ?? color)
            context.fill(rect)
        case let .blur(rect):
            let clipped = rect.integral.intersection(document.bounds)
            guard !clipped.isNull, clipped.width >= 1, clipped.height >= 1,
                  let patch = obscured(base, rect: clipped) else { return }
            drawImage(patch, in: clipped, context: context)
        case let .text(origin, string, fontSize):
            drawText(string, at: origin, fontSize: fontSize, color: annotation.color, in: context)
        case let .step(center, diameter):
            let circle = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
            context.fillEllipse(in: circle)
            context.setStrokeColor(CGColor(gray: 1, alpha: 1))
            context.setLineWidth(max(1, diameter / 14))
            context.strokeEllipse(in: circle.insetBy(dx: diameter / 28, dy: diameter / 28))
            let number = "\(document.stepNumber(of: annotation.id) ?? 0)"
            let fontSize = diameter * 0.58
            let size = textSize(number, fontSize: fontSize)
            let textColor: RGBAColor = annotation.color == .white || annotation.color == .yellow ? .black : .white
            drawText(number, at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), fontSize: fontSize, color: textColor, in: context)
        }
    }

    // MARK: - Text

    static func attributes(fontSize: CGFloat, color: RGBAColor) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor(cgColor: color.cgColor) ?? .red,
        ]
    }

    public static func textSize(_ string: String, fontSize: CGFloat) -> CGSize {
        let size = NSAttributedString(string: string, attributes: attributes(fontSize: fontSize, color: .black)).size()
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    private static func drawText(_ string: String, at origin: CGPoint, fontSize: CGFloat, color: RGBAColor, in context: CGContext) {
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        NSAttributedString(string: string, attributes: attributes(fontSize: fontSize, color: color)).draw(at: origin)
        NSGraphicsContext.current = previous
    }

    // MARK: - Images

    /// Draws a CGImage into a y-down context without flipping it.
    static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }

    /// Pixelated then blurred, so the text underneath can't be read back.
    static func obscured(_ base: CGImage, rect: CGRect) -> CGImage? {
        let key = "\(ObjectIdentifier(base).hashValue)-\(rect.minX)-\(rect.minY)-\(rect.width)-\(rect.height)"
        if let cached = blurCache[key] { return cached }
        let height = CGFloat(base.height)
        let ciRect = CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
        let block = max(8, min(rect.width, rect.height) / 8)
        let image = CIImage(cgImage: base)
            .cropped(to: ciRect)
            .clampedToExtent()
            .applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: block, kCIInputCenterKey: CIVector(x: ciRect.minX, y: ciRect.minY)])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: block / 2])
            .cropped(to: ciRect)
        guard let result = ciContext.createCGImage(image, from: ciRect, format: .BGRA8, colorSpace: base.colorSpace) else { return nil }
        if blurCache.count > 64 { blurCache.removeAll() }
        blurCache[key] = result
        return result
    }
}
