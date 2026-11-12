import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// The outline around the recorded area and the floating bar under it.
/// Both are Omni windows, which recordings leave out, so they never appear
/// in the video.
@MainActor
final class RecordingOverlay {
    private final class BarPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    let area: CGRect
    private let outline: NSPanel
    private let bar: BarPanel
    private let model: RecordingBarModel
    var onRecord: () -> Void = {}
    var onCancel: () -> Void = {}
    private var keyMonitor: Any?

    init(area: CGRect, controller: RecordingController, settings: SettingsStore) {
        self.area = area
        model = RecordingBarModel(controller: controller, settings: settings)
        outline = NSPanel(contentRect: area.insetBy(dx: -3, dy: -3), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        outline.isOpaque = false
        outline.backgroundColor = .clear
        outline.ignoresMouseEvents = true
        outline.level = .statusBar
        outline.hasShadow = false
        outline.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        outline.contentView = NSHostingView(rootView: AreaOutline(model: model))

        bar = BarPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        bar.isOpaque = false
        bar.backgroundColor = .clear
        bar.hasShadow = true
        bar.level = .statusBar
        bar.isMovableByWindowBackground = true
        bar.hidesOnDeactivate = false
        bar.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        model.record = { [weak self] in self?.onRecord() }
        model.cancel = { [weak self] in self?.onCancel() }
        bar.contentView = NSHostingView(rootView: RecordingBarView(model: model))
    }

    func showSetup() {
        model.phase = .setup
        outline.orderFrontRegardless()
        place()
        bar.makeKeyAndOrderFront(nil)
        // ↩ records, Esc cancels while setting up.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.model.phase == .setup, self.bar.isKeyWindow else { return event }
            switch event.keyCode {
            case 36, 76: self.onRecord(); return nil
            case 53: self.onCancel(); return nil
            default: return event
            }
        }
    }

    func showRecording() {
        model.phase = .recording
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        place()
    }

    func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        model.stopTicking()
        outline.orderOut(nil)
        bar.orderOut(nil)
    }

    /// Centered under the area; above it if there's no room; inside its
    /// bottom edge for a full-screen recording.
    private func place() {
        guard let host = bar.contentView else { return }
        let size = host.fittingSize
        let screen = NSScreen.screens.first { $0.frame.intersects(area) } ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        var origin = CGPoint(x: area.midX - size.width / 2, y: area.minY - size.height - 12)
        if origin.y < visible.minY + 8 { origin.y = area.maxY + 12 }
        if origin.y + size.height > visible.maxY - 8 { origin.y = max(area.minY, visible.minY) + 24 }
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        bar.setFrame(CGRect(origin: origin, size: size), display: true)
        bar.orderFrontRegardless()
    }
}

@MainActor
@Observable
final class RecordingBarModel {
    enum Phase { case setup, recording }
    var phase: Phase = .setup
    var now = Date()
    let controller: RecordingController
    let settings: SettingsStore
    @ObservationIgnored var record: () -> Void = {}
    @ObservationIgnored var cancel: () -> Void = {}
    @ObservationIgnored private var ticker: Timer?

    init(controller: RecordingController, settings: SettingsStore) {
        self.controller = controller
        self.settings = settings
        let ticker = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.now = Date() }
        }
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    var elapsedText: String {
        let seconds = Int(controller.timer?.elapsed(at: now) ?? 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60) // l10n-ignore
    }
}

/// Dashed white while setting up, red while recording.
private struct AreaOutline: View {
    @Bindable var model: RecordingBarModel

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(
                model.phase == .recording ? Color.red.opacity(model.controller.isPaused ? 0.5 : 0.9) : Color.white,
                style: StrokeStyle(lineWidth: 2, dash: model.phase == .setup ? [6, 4] : [])
            )
            .shadow(color: .black.opacity(0.4), radius: 1)
    }
}

private struct RecordingBarView: View {
    @Bindable var model: RecordingBarModel
    private typealias S = L10n.Screenshots

    var body: some View {
        HStack(spacing: OmniStyle.s2) {
            switch model.phase {
            case .setup: setup
            case .recording: recording
            }
        }
        .padding(.horizontal, OmniStyle.s3)
        .padding(.vertical, OmniStyle.s2)
        .controlSize(.large)
        .omniPanelBackground(radius: 14, material: .regularMaterial)
    }

    // MARK: Before recording

    @ViewBuilder private var setup: some View {
        toggle(ScreenshotsFeature.microphoneKey, on: "mic.fill", off: "mic.slash", title: S.barMicrophone)
        toggle(ScreenshotsFeature.systemAudioKey, on: "speaker.wave.2.fill", off: "speaker.slash", title: S.barSystemAudio)
        toggle(ScreenshotsFeature.recordCursorKey, on: "cursorarrow", off: "cursorarrow.slash", title: S.barPointer)
        Menu {
            Picker(S.frameRate, selection: model.settings.binding(ScreenshotsFeature.fpsKey)) {
                Text(S.fps30).tag(30)
                Text(S.fps60).tag(60)
            }
            .pickerStyle(.inline)
        } label: {
            Text(model.settings.value(ScreenshotsFeature.fpsKey) == 60 ? S.fps60 : S.fps30)
        }
        .fixedSize()
        .help(S.frameRate)
        Divider().frame(height: 24)
        Button(L10n.Common.cancel, action: model.cancel)
            .keyboardShortcut(.cancelAction)
        Button(action: model.record) {
            Label(S.barRecord, systemImage: "record.circle.fill")
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .keyboardShortcut(.defaultAction)
    }

    private func toggle(_ key: SettingKey<Bool>, on: String, off: String, title: String) -> some View {
        let isOn = model.settings.value(key)
        return Button { model.settings.set(!isOn, for: key) } label: {
            Label(title, systemImage: isOn ? on : off)
        }
        .buttonStyle(.bordered)
        .tint(isOn ? .accentColor : .secondary)
        .help(title)
    }

    // MARK: While recording

    @ViewBuilder private var recording: some View {
        let controller = model.controller
        Circle().fill(controller.isPaused ? Color.orange : Color.red).frame(width: 10, height: 10)
        Text(model.elapsedText).font(.body.monospacedDigit().weight(.medium)).frame(minWidth: 44, alignment: .leading)
        Button { controller.togglePause() } label: {
            Label(controller.isPaused ? S.barResume : S.barPause, systemImage: controller.isPaused ? "play.fill" : "pause.fill")
        }
        .buttonStyle(.bordered)
        Button { controller.toggleMic() } label: {
            Label(controller.micMuted ? S.barUnmute : S.barMute, systemImage: controller.micMuted ? "mic.slash.fill" : "mic.fill")
        }
        .buttonStyle(.bordered)
        .disabled(!controller.hasMicrophone)
        .help(controller.hasMicrophone ? S.barMicHelp : S.barMicOffHelp)
        Button { Task { await controller.stop() } } label: {
            Label(S.barStop, systemImage: "stop.fill")
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        Button { Task { await controller.discard() } } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.bordered)
        .help(S.barDiscard)
        .accessibilityLabel(S.barDiscard)
    }
}
