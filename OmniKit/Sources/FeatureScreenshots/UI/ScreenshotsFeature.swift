import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// What happens to a screenshot right after it is taken.
public enum AfterCapture: String, Codable, CaseIterable, Sendable {
    case editor, copy, save, pin

    /// Sentence-case label for the settings picker.
    var label: String {
        switch self {
        case .editor: L10n.Screenshots.afterEditor
        case .copy: L10n.Screenshots.afterCopy
        case .save: L10n.Screenshots.afterSave
        case .pin: L10n.Screenshots.afterPin
        }
    }

    /// Title-case item for the "After Capturing" menu.
    var menuTitle: String {
        switch self {
        case .editor: L10n.Screenshots.afterEditorMenu
        case .copy: L10n.Screenshots.afterCopyMenu
        case .save: L10n.Screenshots.afterSaveMenu
        case .pin: L10n.Screenshots.afterPinMenu
        }
    }
}

/// Screenshots & Recording: captures, text recognition, pinning, an
/// annotation editor, and screen recording.
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
    static let lineBreakKey = SettingKey.feature("screenshots", "captureText.lineBreaks", default: LineBreakMode.keep)
    /// Empty = the user's macOS languages that Vision supports.
    static let languagesKey = SettingKey.feature("screenshots", "captureText.languages", default: [String]())
    static let autoLanguageKey = SettingKey.feature("screenshots", "captureText.autoLanguage", default: false)
    static let speakKey = SettingKey.feature("screenshots", "captureText.speak", default: false)

    static func combo(_ keyCode: UInt32) -> KeyCombo { KeyCombo(keyCode: keyCode, modifiers: [.control, .option, .command]) }
    public static let areaHotkey = HotkeyAction(id: "screenshots.area", title: L10n.Screenshots.hotkeyArea, defaultCombo: combo(21)) // ⌃⌥⌘4
    public static let screenHotkey = HotkeyAction(id: "screenshots.screen", title: L10n.Screenshots.hotkeyScreen, defaultCombo: combo(20)) // ⌃⌥⌘3
    /// Capture Text, ⌘⇧2 (macOS doesn't use it).
    public static let textHotkey = HotkeyAction(id: "screenshots.text", title: L10n.Screenshots.hotkeyText, defaultCombo: KeyCombo(keyCode: 19, modifiers: [.command, .shift]))
    public static let recordHotkey = HotkeyAction(id: "screenshots.record", title: L10n.Screenshots.hotkeyRecord, defaultCombo: combo(15)) // ⌃⌥⌘R
    public static let scrollingHotkey = HotkeyAction(id: "screenshots.scrolling", title: L10n.Screenshots.hotkeyScrolling, defaultCombo: nil)

    public let id: FeatureID = "screenshots"
    public var displayName: String { L10n.Screenshots.displayName }
    public var summary: String { L10n.Screenshots.summary }
    public let symbolName = "camera.viewfinder"
    public let requiredPermissions: Set<Permission> = [.screenRecording]
    /// Microphone for recording with mic; Accessibility for scrolling capture.
    public let optionalPermissions: Set<Permission> = [.microphone, .accessibility]

    public var declaredHotkeys: [HotkeyAction] {
        [Self.areaHotkey, Self.screenHotkey, Self.textHotkey, Self.recordHotkey, Self.scrollingHotkey]
    }

    typealias Action = @MainActor @Sendable () -> Void

    /// The actions behind the shortcuts, kept for the menu bar icons.
    struct Actions {
        let area, screen, text, record, scrolling: Action
    }

    @ObservationIgnored var settings: SettingsStore?
    @ObservationIgnored var actions: Actions?
    @ObservationIgnored private var windows: CaptureWindows?
    @ObservationIgnored let captureTextController = CaptureTextController()
    /// Observed, so the menu bar icons can follow the recording state.
    private(set) var recording: RecordingController?
    @ObservationIgnored private var busy = false
    private let log = Log.logger("screenshots")

    public init() {}

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        let windows = CaptureWindows(saveFolder: { Self.folder(settings) })
        let captureTextController = self.captureTextController
        windows.recognizeText = { image in Task { await captureTextController.recognize(image, settings: settings) } }
        let recording = RecordingController()
        self.windows = windows
        self.recording = recording
        context.lifetime.add { [weak self] in
            windows.closeAll()
            Task { await recording.stop() }
            self?.windows = nil
            self?.recording = nil
            self?.actions = nil
        }
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
        actions = Actions(area: area, screen: screen, text: text, record: record, scrolling: scrolling)

        context.registerHotkey(Self.areaHotkey, handler: area)
        context.registerHotkey(Self.screenHotkey, handler: screen)
        context.registerHotkey(Self.textHotkey, handler: text)
        context.registerHotkey(Self.recordHotkey, handler: record)
        context.registerHotkey(Self.scrollingHotkey) { if settings.value(Self.scrollingKey) { scrolling() } }

        let later = Self.afterUICloses
        context.registerCommand(Command(id: "screenshots.area", title: L10n.Screenshots.captureArea, keywords: ["screenshot", "snip", "capture"], symbolName: "viewfinder", action: later(area)))
        context.registerCommand(Command(id: "screenshots.screen", title: L10n.Screenshots.captureScreen, keywords: ["screenshot", "full screen"], symbolName: "display", action: later(screen)))
        context.registerCommand(Command(id: "screenshots.text", title: L10n.Screenshots.captureText, subtitle: L10n.Screenshots.captureTextSubtitle, keywords: ["ocr", "recognize", "text", "qr", "barcode", "copy text"], symbolName: "text.viewfinder", action: later(text)))
        context.registerCommand(Command(id: "screenshots.record", title: L10n.Screenshots.recordOrStop, keywords: ["video", "recording", "mp4"], symbolName: "record.circle", action: later(record)))
        context.registerCommand(Command(id: "screenshots.scrolling", title: L10n.Screenshots.scrollingCapture, keywords: ["long screenshot", "scroll"], symbolName: "arrow.up.and.down.text.horizontal") {
            if settings.value(Self.scrollingKey) { later(scrolling)() } else { HUD.show(L10n.Screenshots.turnOnScrolling, symbol: "flask") }
        })
    }

    public func disable() {
        settings = nil
    }

    /// Runs `action` once the palette, menu or control panel that triggered
    /// it has closed, so it doesn't end up in the capture.
    static func afterUICloses(_ action: @escaping Action) -> Action {
        { Task { @MainActor in try? await Task.sleep(for: .milliseconds(200)); action() } }
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
        guard let settings else { return }
        await captureTextController.run(settings: settings)
    }

    private func captureScrolling() async {
        guard case let .area(rect) = await SelectionOverlay.choose(.scrolling) else { return }
        HUD.show(L10n.Screenshots.scrolling, symbol: "arrow.down.doc")
        try? await Task.sleep(for: .milliseconds(900)) // let the HUD fade before the first page
        do {
            let outcome = try await ScrollingCapture.run(area: rect)
            if case let .finished(capture, pages, reason) = outcome {
                log.info("Scrolling capture: \(pages) pages, \(reason, privacy: .public)")
                HUD.show(L10n.Screenshots.joinedPages(pages, reason: reason), symbol: "arrow.down.doc")
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
            HUD.show(L10n.Screenshots.screenshotCopied, symbol: "doc.on.doc")
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
