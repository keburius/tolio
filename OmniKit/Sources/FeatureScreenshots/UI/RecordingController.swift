import AppKit
import AVFoundation
import OmniCore
import OmniPlatform
@preconcurrency import ScreenCaptureKit

/// Runs one recording at a time and shows a stop button in the menu bar.
@MainActor
final class RecordingController: NSObject {
    private var recorder: ScreenRecorder?
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var startDate = Date()
    private let log = Log.logger("recorder")

    var isRecording: Bool { recorder != nil }

    func start(area: CGRect, options: RecordingOptions, folder: URL) async {
        guard !isRecording else { return }
        var options = options
        if options.microphone {
            if #unavailable(macOS 15.0) {
                options.microphone = false
                HUD.show("Microphone recording needs macOS 15", symbol: "mic.slash")
            } else if !(await Self.microphoneAllowed()) {
                options.microphone = false
                HUD.show("Recording without microphone (no permission)", symbol: "mic.slash")
            }
        }
        do {
            guard let display = CaptureGeometry.primaryDisplay(for: area, displays: ScreenCapturer.displays()),
                  let rect = CaptureGeometry.recordingRect(area: area, display: display) else { throw CaptureError.nothingToCapture }
            let content = try await ScreenCapturer.shareableContent()
            guard let scDisplay = content.displays.first(where: { $0.displayID == display.id }) else { throw CaptureError.nothingToCapture }
            // Omni's own windows (HUD, stop button) stay out of the video.
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
            startDate = Date()
            showStatusItem()
            log.info("Recording \(rect.pixelWidth)×\(rect.pixelHeight) at \(options.framesPerSecond) fps")
        } catch {
            log.error("Recording failed to start: \(String(describing: error), privacy: .public)")
            HUD.show("Couldn't start recording: \(error)", symbol: "exclamationmark.triangle")
        }
    }

    func stop() async {
        guard let recorder else { return }
        self.recorder = nil
        hideStatusItem()
        do {
            let url = try await recorder.stop()
            HUD.show("Recording saved", symbol: "film")
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            log.error("Recording failed: \(String(describing: error), privacy: .public)")
            HUD.show("Recording failed: \(error)", symbol: "exclamationmark.triangle")
        }
    }

    private static func microphoneAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    // MARK: - Status item

    private func showStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(stopClicked)
        item.button?.toolTip = "Stop recording"
        statusItem = item
        updateTitle()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateTitle() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func updateTitle() {
        let seconds = Int(Date().timeIntervalSince(startDate))
        let title = NSMutableAttributedString(string: "● ", attributes: [.foregroundColor: NSColor.systemRed])
        title.append(NSAttributedString(
            string: String(format: "%d:%02d", seconds / 60, seconds % 60),
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)]
        ))
        statusItem?.button?.attributedTitle = title
    }

    private func hideStatusItem() {
        timer?.invalidate()
        timer = nil
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
    }

    @objc private func stopClicked() {
        Task { await stop() }
    }
}
