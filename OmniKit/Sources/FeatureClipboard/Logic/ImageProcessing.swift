import Foundation
import ImageIO
import UniformTypeIdentifiers

/// PNG conversion and thumbnails with ImageIO (thread-safe, no AppKit).
enum ImageProcessing {
    struct Output {
        let png: Data
        let thumbnail: Data
        let width: Int
        let height: Int
    }

    static let thumbnailMaxPixels = 96

    /// Converts any ImageIO-readable data (PNG, TIFF, JPEG…) to PNG plus a thumbnail.
    static func process(_ data: Data) -> Output? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixels,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary),
              let png = encodePNG(image), let thumbnail = encodePNG(thumb) else { return nil }
        return Output(png: png, thumbnail: thumbnail, width: image.width, height: image.height)
    }

    private static func encodePNG(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
