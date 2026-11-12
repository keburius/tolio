import AppKit
import OmniCore
import OmniPlatform

/// Polls the pasteboard's change count and hands storable changes to
/// `onCapture`. Runs a timer only between `start()` and `stop()`.
///
/// Privacy: the policy runs on the type list before any content is read,
/// so concealed items are never read, stored, or logged.
@MainActor
final class ClipboardMonitor {
    struct Source {
        let bundleID: String?
        let name: String?
    }

    private let pasteboard: NSPasteboard
    private let interval: TimeInterval
    private let excludedApps: () -> Set<String>
    private let frontmostApp: @MainActor () -> Source?
    private let onCapture: (CapturedClip) -> Void
    private let log = Log.logger("clipboard")
    private var timer: Timer?
    private var lastChangeCount: Int

    init(
        pasteboard: NSPasteboard = .general,
        interval: TimeInterval = 0.5,
        excludedApps: @escaping () -> Set<String>,
        frontmostApp: @escaping @MainActor () -> Source? = ClipboardMonitor.currentFrontmostApp,
        onCapture: @escaping (CapturedClip) -> Void
    ) {
        self.pasteboard = pasteboard
        self.interval = interval
        self.excludedApps = excludedApps
        self.frontmostApp = frontmostApp
        self.onCapture = onCapture
        // Don't record whatever was on the pasteboard before monitoring began.
        lastChangeCount = pasteboard.changeCount
    }

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        lastChangeCount = pasteboard.changeCount
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = interval * 0.4
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Checks for a change once. Internal so tests can drive it.
    func poll() {
        // Omni is borrowing the pasteboard; look again after it's put back.
        guard !PasteboardLease.isActive else { return }
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        let types = Set((pasteboard.pasteboardItems ?? []).flatMap(\.types).map(\.rawValue))
        guard !types.isEmpty else { return }
        let source = frontmostApp()
        if let reason = ClipCapturePolicy.skipReason(
            types: types, sourceBundleID: source?.bundleID, userExcludedApps: excludedApps()
        ) {
            log.debug("Skipped pasteboard change: \(String(describing: reason), privacy: .public)")
            return
        }
        guard let clip = read(source: source) else {
            log.debug("Skipped pasteboard change: unsupported content")
            return
        }
        guard !clip.exceedsLimits else {
            log.info("Skipped pasteboard change: too large (\(clip.byteSize) bytes)")
            return
        }
        onCapture(clip)
    }

    /// Files first (Finder also puts names as text), then images, then text.
    private func read(source: Source?) -> CapturedClip? {
        let app = source?.bundleID, name = source?.name
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return .files(urls, app: app, appName: name)
        }
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pasteboard.data(forType: type) { return .image(data, app: app, appName: name) }
        }
        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(text, app: app, appName: name)
        }
        return nil
    }

    static func currentFrontmostApp() -> Source? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return Source(bundleID: app.bundleIdentifier, name: app.localizedName)
    }
}
