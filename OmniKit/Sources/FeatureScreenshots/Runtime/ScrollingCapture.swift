import AppKit
import OmniCore
import OmniPlatform

/// Experimental: scrolls the content under an area and joins the pages.
/// Needs Accessibility (it posts scroll events) and Screen Recording.
@MainActor
enum ScrollingCapture {
    static let maxPages = 30
    static let maxPixelHeight = 30_000
    static let settleTime: Duration = .milliseconds(450)

    enum Outcome {
        case finished(Capture, pages: Int, reason: String)
    }

    static func run(area: CGRect) async throws -> Outcome {
        guard AXIsProcessTrusted() else { throw CaptureError.failed(L10n.Screenshots.errorNeedsAccessibility) }
        let first = try await ScreenCapturer.capture(area: area)
        var frames = [first.image]
        var hashes: [[UInt64]] = []
        var uniform = Set<UInt64>()
        guard let firstHashes = ScrollStitcher.rowHashes(of: first.image) else { throw CaptureError.failed(L10n.Screenshots.errorReadPixels) }
        hashes.append(firstHashes.hashes)
        uniform.formUnion(firstHashes.uniform)

        // Scroll events go to the window under the pointer.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let center = CGPoint(x: area.midX, y: primaryHeight - area.midY)
        let savedPointer = CGEvent(source: nil)?.location
        CGWarpMouseCursorPosition(center)
        defer { if let savedPointer { CGWarpMouseCursorPosition(savedPointer) } }

        var reason = L10n.Screenshots.reasonPageLimit
        var total = first.image.height
        for _ in 1..<maxPages {
            if escapePressed() { reason = L10n.Screenshots.reasonStopped; break }
            scroll(by: Int32(-(area.height * 0.7)), at: center)
            try await Task.sleep(for: settleTime)
            let next = try await ScreenCapturer.capture(area: area)
            guard let nextHashes = ScrollStitcher.rowHashes(of: next.image), let previous = hashes.last else { break }
            uniform.formUnion(nextHashes.uniform)
            guard let step = ScrollStitcher.analyze(previous: previous, next: nextHashes.hashes, uniform: { uniform.contains($0) }) else {
                reason = L10n.Screenshots.reasonUnmatched
                break
            }
            if step.newRows == 0 { reason = L10n.Screenshots.reasonEnd; break }
            frames.append(next.image)
            hashes.append(nextHashes.hashes)
            total += step.newRows
            if total >= maxPixelHeight { reason = L10n.Screenshots.reasonSizeLimit; break }
        }
        let plan = ScrollStitcher.plan(frames: hashes) { uniform.contains($0) }
        guard let image = ScrollStitcher.compose(frames, plan: plan) else { throw CaptureError.failed(L10n.Screenshots.errorJoinPages) }
        return .finished(Capture(image: image, scale: first.scale, date: first.date), pages: Set(plan.map(\.frame)).count, reason: reason)
    }

    private static func scroll(by pixels: Int32, at point: CGPoint) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: pixels, wheel2: 0, wheel3: 0) else { return }
        event.location = point
        event.setIntegerValueField(.eventSourceUserData, value: KeySender.eventMarker)
        event.post(tap: .cghidEventTap)
    }

    private static func escapePressed() -> Bool {
        CGEventSource.keyState(.combinedSessionState, key: 53)
    }
}
