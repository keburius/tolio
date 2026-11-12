import AppKit
import OmniCore
@preconcurrency import ScreenCaptureKit

/// A finished capture: pixels plus the scale to show it at its real size.
public struct Capture: @unchecked Sendable {
    public let image: CGImage
    /// Pixels per point.
    public let scale: CGFloat
    public let date: Date

    public var pointSize: CGSize { CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale) }
}

public enum CaptureError: Error, CustomStringConvertible {
    case noPermission, nothingToCapture, failed(String)

    public var description: String {
        switch self {
        case .noPermission: L10n.Screenshots.errorNoPermission
        case .nothingToCapture: L10n.Screenshots.errorNothingToCapture
        case let .failed(message): L10n.Screenshots.errorFailed(message)
        }
    }
}

/// Screen captures through ScreenCaptureKit at each display's native scale.
@MainActor
enum ScreenCapturer {
    static func displays() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return DisplayInfo(id: CGDirectDisplayID(number.uint32Value), frame: screen.frame, scale: screen.backingScaleFactor)
        }
    }

    /// Captures an area (AppKit global points). Pieces on different displays
    /// are composited at the highest scale (see `CaptureGeometry.plan`).
    static func capture(area: CGRect, showsCursor: Bool = false) async throws -> Capture {
        guard CGPreflightScreenCaptureAccess() else { throw CaptureError.noPermission }
        guard let plan = CaptureGeometry.plan(area: area, displays: displays()) else { throw CaptureError.nothingToCapture }
        let content = try await shareableContent()
        var images: [(CapturePlan.Piece, CGImage)] = []
        for piece in plan.pieces {
            guard let display = content.displays.first(where: { $0.displayID == piece.displayID }) else { continue }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = piece.sourceRect
            configuration.width = piece.pixelWidth
            configuration.height = piece.pixelHeight
            configuration.captureResolution = .best
            configuration.scalesToFit = false
            configuration.showsCursor = showsCursor
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            images.append((piece, image))
        }
        guard !images.isEmpty else { throw CaptureError.nothingToCapture }
        if images.count == 1, let (piece, image) = images.first,
           image.width == plan.pixelWidth, image.height == plan.pixelHeight, piece.scale == plan.scale {
            return Capture(image: image, scale: plan.scale, date: Date())
        }
        return Capture(image: try composite(images, plan: plan), scale: plan.scale, date: Date())
    }

    /// Room around a window for its shadow (macOS shadows reach about 60–75 pt).
    static let shadowPadding: CGFloat = 150

    /// Captures one window at the scale macOS reports for it, 1:1. With
    /// `shadow`, the window is rendered unscaled on a larger transparent
    /// canvas and trimmed to the shadow's extent (asking for the window's own
    /// size would shrink the window to make room for the shadow).
    static func capture(windowID: CGWindowID, shadow: Bool) async throws -> Capture {
        guard CGPreflightScreenCaptureAccess() else { throw CaptureError.noPermission }
        let content = try await shareableContent()
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else { throw CaptureError.nothingToCapture }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = CGFloat(filter.pointPixelScale)
        let pad = shadow ? shadowPadding : 0
        let configuration = SCStreamConfiguration()
        configuration.width = Int(((filter.contentRect.width + pad * 2) * scale).rounded())
        configuration.height = Int(((filter.contentRect.height + pad * 2) * scale).rounded())
        configuration.scalesToFit = false
        configuration.captureResolution = .best
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = !shadow
        configuration.shouldBeOpaque = !shadow
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        guard shadow else { return Capture(image: image, scale: scale, date: Date()) }
        guard let bounds = AlphaBounds.visibleRect(of: image), let trimmed = image.cropping(to: bounds) else {
            throw CaptureError.failed(L10n.Screenshots.errorEmptyWindow)
        }
        return Capture(image: trimmed, scale: scale, date: Date())
    }

    static func shareableContent() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw CaptureError.failed(error.localizedDescription)
        }
    }

    private static func composite(_ pieces: [(CapturePlan.Piece, CGImage)], plan: CapturePlan) throws -> CGImage {
        guard let context = CGContext(
            data: nil, width: plan.pixelWidth, height: plan.pixelHeight, bitsPerComponent: 8, bytesPerRow: 0,
            // The display's own color space, so the main part keeps its exact pixel values.
            space: pieces.first?.1.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { throw CaptureError.failed(L10n.Screenshots.errorOutOfMemory) }
        context.setFillColor(CGColor(gray: 0, alpha: 1)) // areas between displays
        context.fill(CGRect(x: 0, y: 0, width: plan.pixelWidth, height: plan.pixelHeight))
        context.interpolationQuality = .none // enlarge 1x parts without blurring
        for (piece, image) in pieces {
            let d = piece.destination
            context.draw(image, in: CGRect(x: d.minX, y: CGFloat(plan.pixelHeight) - d.maxY, width: d.width, height: d.height))
        }
        guard let image = context.makeImage() else { throw CaptureError.failed(L10n.Screenshots.errorCompositing) }
        return image
    }
}

/// Saving and copying captures.
@MainActor
enum CaptureOutput {
    /// PNG data with the DPI set so apps show it at its real size (144 dpi on Retina).
    static func pngData(_ image: CGImage, scale: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        let dpi = 72 * scale
        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi,
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    static func save(_ image: CGImage, scale: CGFloat, to folder: URL, date: Date) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = FileNaming.uniqueURL(in: folder, kind: .screenshot, date: date)
        guard let data = pngData(image, scale: scale) else { throw CaptureError.failed(L10n.Screenshots.errorEncoding) }
        try data.write(to: url, options: .withoutOverwriting)
        return url
    }

    /// A normal copy (the user asked for it), so clipboard history may record it.
    static func copy(_ image: CGImage, scale: CGFloat) {
        guard let data = pngData(image, scale: scale) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setData(data, forType: .png)
        pasteboard.writeObjects([item])
    }

    /// The folder macOS saves screenshots to (Screenshot app setting), else the Desktop.
    static var systemScreenshotFolder: URL {
        if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue { return url }
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }
}

/// On-screen windows front to back, for picking a window to capture.
struct PickableWindow: Equatable {
    let id: CGWindowID
    /// AppKit global points.
    let frame: CGRect
    let ownerName: String
}

@MainActor
enum WindowPicker {
    static func windows() -> [PickableWindow] {
        let own = ProcessInfo.processInfo.processIdentifier
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != own,
                  let number = info[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width >= 40, bounds.height >= 40,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { return nil }
            let frame = CGRect(x: bounds.minX, y: primaryHeight - bounds.maxY, width: bounds.width, height: bounds.height)
            return PickableWindow(id: number, frame: frame, ownerName: info[kCGWindowOwnerName as String] as? String ?? "")
        }
    }
}
