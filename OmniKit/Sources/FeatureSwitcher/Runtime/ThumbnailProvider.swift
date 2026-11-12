import CoreGraphics
import OmniCore
@preconcurrency import ScreenCaptureKit

/// Window thumbnails via ScreenCaptureKit (needs Screen Recording).
/// Captures only while the switcher is open; keeps the last image per
/// window so minimized or unreachable windows still show something.
@MainActor
final class ThumbnailProvider {
    static let maxPixels = 400
    static let maxWindows = 24

    private(set) var images: [CGWindowID: CGImage] = [:]
    private let log = Log.logger("switcher")

    /// Captures `ids` (in order, up to `maxWindows`), calling `onUpdate`
    /// after each image arrives.
    func capture(_ ids: [CGWindowID], onUpdate: @escaping @MainActor () -> Void) async {
        guard CGPreflightScreenCaptureAccess() else { return }
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        } catch {
            log.error("Window list for thumbnails failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        let windows = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
        for id in ids.prefix(Self.maxWindows) {
            guard !Task.isCancelled else { return }
            guard let window = windows[id], window.frame.width > 1, window.frame.height > 1 else { continue }
            let configuration = SCStreamConfiguration()
            let scale = min(1, CGFloat(Self.maxPixels) / max(window.frame.width, window.frame.height)) * 2
            configuration.width = max(1, Int(window.frame.width * scale))
            configuration.height = max(1, Int(window.frame.height * scale))
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true
            let filter = SCContentFilter(desktopIndependentWindow: window)
            if let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) {
                images[id] = image
                onUpdate()
            }
        }
    }

    func forget(keeping ids: Set<CGWindowID>) {
        images = images.filter { ids.contains($0.key) }
    }

    func clear() { images.removeAll() }
}
