import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

public enum AfterCapture: String, Codable, CaseIterable, Sendable {
    case editor, copy, save, pin

    var label: String {
        switch self {
        case .editor: "Open in the editor"
        case .copy: "Copy to the clipboard"
        case .save: "Save to the folder"
        case .pin: "Pin on screen"
        }
    }
}

/// Screenshots, OCR, pinning, an annotation editor, and screen recording.
@MainActor
@Observable
public final class ScreenshotsFeature: Feature {
    static let afterKey = SettingKey.feature("screenshots", "afterCapture", default: AfterCapture.editor)
    static let folderKey = SettingKey.feature("screenshots", "folder", default: "")
    static let shadowKey = SettingKey.feature("screenshots", "windowShadow", default: true)
    static let fpsKey = SettingKey.feature("screenshots", "fps", default: 30)
    static let codecKey = SettingKey.feature("screenshots", "codec", default: VideoCodec.h264)
    static let systemAudioKey = SettingKey.feature("screenshots", "systemAudio", default: false)
    static let microphoneKey = SettingKey.feature("screenshots", "microphone", default: false)
    static let recordCursorKey = SettingKey.feature("screenshots", "recordCursor", default: true)
    static let scrollingKey = SettingKey.feature("screenshots", "experimentalScrolling", default: false)

    static func combo(_ keyCode: UInt32) -> KeyCombo { KeyCombo(keyCode: keyCode, modifiers: [.control, .option, .command]) }
    public static let areaHotkey = HotkeyAction(id: "screenshots.area", title: "Capture area or window", defaultCombo: combo(21)) // ⌃⌥⌘4
    public static let screenHotkey = HotkeyAction(id: "screenshots.screen", title: "Capture screen", defaultCombo: combo(20)) // ⌃⌥⌘3
    public static let textHotkey = HotkeyAction(id: "screenshots.text", title: "Capture text (OCR)", defaultCombo: combo(31)) // ⌃⌥⌘O
    public static let recordHotkey = HotkeyAction(id: "screenshots.record", title: "Start or stop screen recording", defaultCombo: combo(15)) // ⌃⌥⌘R
    public static let scrollingHotkey = HotkeyAction(id: "screenshots.scrolling", title: "Scrolling capture (experimental)", defaultCombo: nil)

    public let id: FeatureID = "screenshots"
    public let displayName = "Screenshots"
    public let summary = "Capture areas, windows, or the screen; annotate, pin, copy text, and record video."
    public let symbolName = "camera.viewfinder"
    public let requiredPermissions: Set<Permission> = [.screenRecording]
    /// Microphone for recording with mic; Accessibility for scrolling capture.
    public let optionalPermissions: Set<Permission> = [.microphone, .accessibility]

    @ObservationIgnored private var settings: SettingsStore?
    @ObservationIgnored private var windows: CaptureWindows?
    @ObservationIgnored private var recording: RecordingController?
    @ObservationIgnored private var busy = false
    private let log = Log.logger("screenshots")

    public init() {}

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        let windows = CaptureWindows(saveFolder: { Self.folder(settings) })
        let recording = RecordingController()
        self.windows = windows
        self.recording = recording
        context.lifetime.add { [weak self] in
            windows.closeAll()
            Task { await recording.stop() }
            self?.windows = nil
            self?.recording = nil
        }
        typealias Action = @MainActor @Sendable () -> Void
        let run: (@escaping @MainActor @Sendable () async -> Void) -> Action = { [weak self] body in
            {
                guard let self, !self.busy else { return }
                self.busy = true
                Task { @MainActor in
                    await body()
                    self.busy = false
                }
            }
        }
        let area = run { [weak self] in await self?.captureArea() }
        let screen = run { [weak self] in await self?.captureScreen() }
        let text = run { [weak self] in await self?.captureText() }
        let record: Action = { [weak self] in
            guard let self else { return }
            if recording.isRecording { Task { await recording.stop() } } else { run { await self.startRecording() }() }
        }
        let scrolling = run { [weak self] in await self?.captureScrolling() }

        context.registerHotkey(Self.areaHotkey, handler: area)
        context.registerHotkey(Self.screenHotkey, handler: screen)
        context.registerHotkey(Self.textHotkey, handler: text)
        context.registerHotkey(Self.recordHotkey, handler: record)
        context.registerHotkey(Self.scrollingHotkey) { if settings.value(Self.scrollingKey) { scrolling() } }

        // From the palette: wait until it has closed so it isn't captured.
        func later(_ action: @escaping Action) -> Action {
            { Task { @MainActor in try? await Task.sleep(for: .milliseconds(200)); action() } }
        }
        context.registerCommand(Command(id: "screenshots.area", title: "Capture Area or Window", keywords: ["screenshot", "snip", "capture"], symbolName: "viewfinder", action: later(area)))
        context.registerCommand(Command(id: "screenshots.screen", title: "Capture Screen", keywords: ["screenshot", "full screen"], symbolName: "display", action: later(screen)))
        context.registerCommand(Command(id: "screenshots.text", title: "Capture Text", subtitle: "Copy text from part of the screen (OCR)", keywords: ["ocr", "recognize", "text"], symbolName: "text.viewfinder", action: later(text)))
        context.registerCommand(Command(id: "screenshots.record", title: "Record Screen / Stop Recording", keywords: ["video", "recording", "mp4"], symbolName: "record.circle", action: later(record)))
        context.registerCommand(Command(id: "screenshots.scrolling", title: "Scrolling Capture (Experimental)", keywords: ["long screenshot", "scroll"], symbolName: "arrow.up.and.down.text.horizontal") {
            if settings.value(Self.scrollingKey) { later(scrolling)() } else { HUD.show("Turn on scrolling capture in Settings → Screenshots", symbol: "flask") }
        })
    }

    public func disable() {
        settings = nil
    }

    static func folder(_ settings: SettingsStore) -> URL {
        let path = settings.value(folderKey)
        return path.isEmpty ? CaptureOutput.systemScreenshotFolder : URL(fileURLWithPath: path, isDirectory: true)
    }

    // MARK: - Flows

    private func captureArea() async {
        switch await SelectionOverlay.choose(.screenshot) {
        case .cancelled: return
        case let .area(rect): await finish { try await ScreenCapturer.capture(area: rect) }
        case let .window(window):
            let shadow = settings?.value(Self.shadowKey) ?? true
            await finish { try await ScreenCapturer.capture(windowID: window.id, shadow: shadow) }
        }
    }

    private func captureScreen() async {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        await finish { try await ScreenCapturer.capture(area: screen.frame) }
    }

    private func captureText() async {
        let capture: Capture
        do {
            switch await SelectionOverlay.choose(.text) {
            case .cancelled: return
            case let .area(rect): capture = try await ScreenCapturer.capture(area: rect)
            case let .window(window): capture = try await ScreenCapturer.capture(windowID: window.id, shadow: false)
            }
        } catch {
            report(error)
            return
        }
        windows?.copyText(from: capture.image)
    }

    private func captureScrolling() async {
        guard case let .area(rect) = await SelectionOverlay.choose(.scrolling) else { return }
        HUD.show("Scrolling… hold Esc to stop", symbol: "arrow.down.doc")
        try? await Task.sleep(for: .milliseconds(900)) // let the HUD fade before the first page
        do {
            let outcome = try await ScrollingCapture.run(area: rect)
            if case let .finished(capture, pages, reason) = outcome {
                log.info("Scrolling capture: \(pages) pages, \(reason, privacy: .public)")
                HUD.show("Joined \(pages) page\(pages == 1 ? "" : "s"): \(reason)", symbol: "arrow.down.doc")
                deliver(capture)
            }
        } catch {
            report(error)
        }
    }

    private func startRecording() async {
        guard let settings, let recording else { return }
        guard case let .area(rect) = await SelectionOverlay.choose(.record) else { return }
        let options = RecordingOptions(
            framesPerSecond: settings.value(Self.fpsKey), codec: settings.value(Self.codecKey),
            systemAudio: settings.value(Self.systemAudioKey), microphone: settings.value(Self.microphoneKey),
            showsCursor: settings.value(Self.recordCursorKey)
        )
        await recording.start(area: rect, options: options, folder: Self.folder(settings))
    }

    private func finish(_ capture: () async throws -> Capture) async {
        do {
            deliver(try await capture())
        } catch {
            report(error)
        }
    }

    private func deliver(_ capture: Capture) {
        guard let windows else { return }
        log.info("Captured \(capture.image.width)×\(capture.image.height) px at \(capture.scale)x")
        switch settings?.value(Self.afterKey) ?? .editor {
        case .editor: windows.openEditor(capture)
        case .copy:
            CaptureOutput.copy(capture.image, scale: capture.scale)
            HUD.show("Screenshot copied", symbol: "doc.on.doc")
        case .save: windows.save(capture.image, scale: capture.scale, date: capture.date)
        case .pin: windows.pin(capture)
        }
    }

    private func report(_ error: Error) {
        log.error("Capture failed: \(String(describing: error), privacy: .public)")
        HUD.show("\(error)", symbol: "exclamationmark.triangle")
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(ScreenshotsSettingsView(settings: settings))
    }
}

struct ScreenshotsSettingsView: View {
    let settings: SettingsStore

    var body: some View {
        Section("Screenshots") {
            Picker("After capturing", selection: settings.binding(ScreenshotsFeature.afterKey)) {
                ForEach(AfterCapture.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            LabeledContent("Save to") {
                HStack {
                    Text(ScreenshotsFeature.folder(settings).path(percentEncoded: false)).lineLimit(1).truncationMode(.middle)
                    Button("Choose…") { chooseFolder() }
                    if !settings.value(ScreenshotsFeature.folderKey).isEmpty {
                        Button("Use macOS Setting") { settings.set("", for: ScreenshotsFeature.folderKey) }
                    }
                }
            }
            Toggle("Include the shadow when capturing a window", isOn: settings.binding(ScreenshotsFeature.shadowKey))
            Text("Captures keep each display's native resolution: a Retina screenshot has twice the points in pixels and is saved at 144 dpi so it shows at its real size. An area across displays with different resolutions is saved at the higher one.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Screen recording (MP4)") {
            Picker("Frame rate", selection: settings.binding(ScreenshotsFeature.fpsKey)) {
                Text("30 fps").tag(30)
                Text("60 fps").tag(60)
            }
            Picker("Format", selection: settings.binding(ScreenshotsFeature.codecKey)) {
                ForEach(VideoCodec.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Toggle("Show the pointer", isOn: settings.binding(ScreenshotsFeature.recordCursorKey))
            Toggle("Record system audio", isOn: settings.binding(ScreenshotsFeature.systemAudioKey))
            Toggle("Record the microphone (macOS 15 or later)", isOn: settings.binding(ScreenshotsFeature.microphoneKey))
            Text("System audio and the microphone are saved as two audio tracks. Press the recording shortcut again or click ● in the menu bar to stop.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Experimental") {
            Toggle("Scrolling capture", isOn: settings.binding(ScreenshotsFeature.scrollingKey))
            Text("Select the part of a window that scrolls; Omni scrolls it and joins the pages into one tall image. Needs Accessibility. Works best on plain documents and web pages; animated content or content that changes while scrolling can't be joined.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = ScreenshotsFeature.folder(settings)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.set(url.path, for: ScreenshotsFeature.folderKey)
    }
}
