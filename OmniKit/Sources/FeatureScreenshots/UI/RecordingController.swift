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
    /// Elapsed time that stops while paused.
    private(set) var timer: RecordingTimer?
    var isPaused: Bool { timer?.isPaused ?? false }
    /// Whether the running recording has a microphone track, and whether it's muted.
    private(set) var hasMicrophone = false
    private(set) var micMuted = false
    /// The bar and the area outline (set-up and while recording).
    @ObservationIgnored private var overlay: RecordingOverlay?
    @ObservationIgnored private var discardOnStop = false
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
            timer = RecordingTimer(start: Date())
            LiveActivityCenter.shared.post(LiveActivity(
                id: "screenshots.recording", leading: .symbol("record.circle.fill"), trailing: .elapsed(Date()),
                title: L10n.Island.recording, tint: "red", priority: .high
            ))
            hasMicrophone = options.microphone
            micMuted = false
            overlay?.showRecording()
            log.info("Recording \(rect.pixelWidth)×\(rect.pixelHeight) at \(options.framesPerSecond) fps")
        } catch {
            overlay?.close()
            overlay = nil
            log.error("Recording failed to start: \(String(describing: error), privacy: .public)")
            HUD.show(L10n.Screenshots.couldntStartRecording("\(error)"), symbol: "exclamationmark.triangle")
        }
    }

    /// Shows the outline and the set-up bar for `area`; recording starts
    /// when Record is clicked (or ↩), nothing happens on Cancel (or Esc).
    func prepare(area: CGRect, settings: SettingsStore, options: @escaping () -> RecordingOptions, folder: URL) {
        guard !isRecording, overlay == nil else { return }
        let overlay = RecordingOverlay(area: area, controller: self, settings: settings)
        overlay.onRecord = { [weak self] in
            guard let self else { return }
            Task { await self.start(area: area, options: options(), folder: folder) }
        }
        overlay.onCancel = { [weak self] in
            self?.overlay?.close()
            self?.overlay = nil
        }
        self.overlay = overlay
        overlay.showSetup()
    }

    func togglePause() {
        guard let recorder, var timer else { return }
        if timer.isPaused {
            timer.resume(at: Date())
            recorder.resume()
        } else {
            timer.pause(at: Date())
            recorder.pause()
        }
        self.timer = timer
    }

    func toggleMic() {
        guard let recorder, hasMicrophone else { return }
        micMuted.toggle()
        recorder.setMicMuted(micMuted)
    }

    /// Stops and moves the file to the Trash instead of keeping it.
    func discard() async {
        discardOnStop = true
        await stop()
    }

    func stop() async {
        overlay?.close()
        overlay = nil
        guard let recorder else { return }
        self.recorder = nil
        isRecording = false
        startDate = nil
        timer = nil
        LiveActivityCenter.shared.remove("screenshots.recording")
        hasMicrophone = false
        let discard = discardOnStop
        discardOnStop = false
        do {
            let url = try await recorder.stop()
            if discard {
                // Destructive file operations go to the Trash and are logged.
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                log.notice("Discarded a recording (moved to the Trash)")
                HUD.show(L10n.Screenshots.recordingDiscarded, symbol: "trash")
                return
            }
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
