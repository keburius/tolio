import CoreGraphics

/// The smallest rectangle containing every pixel that isn't fully transparent.
public enum AlphaBounds {
    /// Pixel rect, top-left origin; nil if the image is fully transparent.
    public static func visibleRect(of image: CGImage) -> CGRect? {
        let width = image.width, height = image.height
        // Alpha only: 1 byte per pixel.
        var alpha = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &alpha, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * width
            var rowMin = -1, rowMax = -1
            for x in 0..<width where alpha[row + x] != 0 {
                rowMin = x
                break
            }
            guard rowMin >= 0 else { continue }
            for x in stride(from: width - 1, through: rowMin, by: -1) where alpha[row + x] != 0 {
                rowMax = x
                break
            }
            minX = min(minX, rowMin)
            maxX = max(maxX, rowMax)
            minY = min(minY, y)
            maxY = y
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
