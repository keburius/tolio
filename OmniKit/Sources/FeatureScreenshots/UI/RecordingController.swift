import AppKit
import AVFoundation
import Observation
import OmniCore
import OmniPlatform
@preconcurrency import ScreenCaptureKit

/// Runs one recording at a time. Its state is observable so the app can show
/// a timer on the Screen Recording icon (or the main icon) while it runs.
@MainActor
@Observable
final class RecordingController {
    @ObservationIgnored private var recorder: ScreenRecorder?
    /// True from the moment a recording has started until `stop()` is called.
    private(set) var isRecording = false
    /// When the running recording started, or nil while not recording.
    private(set) var startDate: Date?
    @ObservationIgnored private let log = Log.logger("recorder")

    func start(area: CGRect, options: RecordingOptions, folder: URL) async {
        guard !isRecording else { return }
        var options = options
        if options.microphone {
            if #unavailable(macOS 15.0) {
                options.microphone = false
                HUD.show(L10n.Screenshots.micNeedsMacOS15, symbol: "mic.slash")
            } else if !(await Self.microphoneAllowed()) {
                options.microphone = false
                HUD.show(L10n.Screenshots.micNoPermission, symbol: "mic.slash")
            }
        }
        do {
            guard let display = CaptureGeometry.primaryDisplay(for: area, displays: ScreenCapturer.displays()),
                  let rect = CaptureGeometry.recordingRect(area: area, display: display) else { throw CaptureError.nothingToCapture }
            let content = try await ScreenCapturer.shareableContent()
            guard let scDisplay = content.displays.first(where: { $0.displayID == display.id }) else { throw CaptureError.nothingToCapture }
            // Omni's own windows (notices, menus) stay out of the video.
            let own = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
            let filter = SCContentFilter(display: scDisplay, excludingApplications: own, exceptingWindows: [])
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = FileNaming.uniqueURL(in: folder, kind: .recording, date: Date())
            let recorder = try ScreenRecorder(url: url, pixelWidth: rect.pixelWidth, pixelHeight: rect.pixelHeight, options: options)
            recorder.onUnexpectedStop = { [weak self] _ in
                Task { await self?.stop() }
            }
            let fullDisplay = area.contains(display.frame)
            try await recorder.start(
                filter: filter, sourceRect: fullDisplay ? nil : rect.source,
                pixelWidth: rect.pixelWidth, pixelHeight: rect.pixelHeight, options: options
            )
            self.recorder = recorder
            isRecording = true
            startDate = Date()
            log.info("Recording \(rect.pixelWidth)×\(rect.pixelHeight) at \(options.framesPerSecond) fps")
        } catch {
            log.error("Recording failed to start: \(String(describing: error), privacy: .public)")
            HUD.show(L10n.Screenshots.couldntStartRecording("\(error)"), symbol: "exclamationmark.triangle")
        }
    }

    func stop() async {
        guard let recorder else { return }
        self.recorder = nil
        isRecording = false
        startDate = nil
        do {
            let url = try await recorder.stop()
            HUD.show(L10n.Screenshots.recordingSaved, symbol: "film")
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            log.error("Recording failed: \(String(describing: error), privacy: .public)")
            HUD.show(L10n.Screenshots.recordingFailed("\(error)"), symbol: "exclamationmark.triangle")
        }
    }

    private static func microphoneAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }
}
