import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Settings Search anchors of the Screenshots & Recording page.
enum ScreenshotsAnchor {
    static let afterCapture = "screenshots.afterCapture"
    static let folder = "screenshots.folder"
    static let shadow = "screenshots.windowShadow"
    static let autoCopy = "screenshots.autoCopy"
    static let fps = "screenshots.fps"
    static let codec = "screenshots.codec"
    static let pointer = "screenshots.recordCursor"
    static let systemAudio = "screenshots.systemAudio"
    static let microphone = "screenshots.microphone"
    static let scrolling = "screenshots.scrolling"
}

extension ScreenshotsFeature {
    public var settingsEntries: [SettingsEntry] {
        typealias S = L10n.Screenshots
        return [
            SettingsEntry(anchor: ScreenshotsAnchor.afterCapture, label: S.afterCapturing, keywords: ["editor", "copy", "save", "pin", "after"]),
            SettingsEntry(anchor: ScreenshotsAnchor.folder, label: S.saveTo, keywords: ["folder", "location", "directory", "save"]),
            SettingsEntry(anchor: ScreenshotsAnchor.shadow, label: S.windowShadow, keywords: ["shadow", "window"]),
            SettingsEntry(anchor: ScreenshotsAnchor.autoCopy, label: S.autoCopyToggle, keywords: ["timer", "countdown", "clipboard", "auto", "close"]),
            SettingsEntry(anchor: ScreenshotsAnchor.fps, label: S.frameRate, keywords: ["fps", "frames", "video", "recording"]),
            SettingsEntry(anchor: ScreenshotsAnchor.codec, label: S.videoFormat, keywords: ["video", "codec", "hevc", "h.264", "mp4"]),
            SettingsEntry(anchor: ScreenshotsAnchor.pointer, label: S.showPointer, keywords: ["cursor", "mouse", "pointer", "video"]),
            SettingsEntry(anchor: ScreenshotsAnchor.systemAudio, label: S.systemAudio, keywords: ["audio", "sound", "video"]),
            SettingsEntry(anchor: ScreenshotsAnchor.microphone, label: S.microphone, keywords: ["mic", "voice", "audio", "video"]),
            SettingsEntry(anchor: ScreenshotsAnchor.scrolling, label: S.scrollingToggle, keywords: ["long screenshot", "scroll", "experimental"]),
        ]
    }
}

struct ScreenshotsSettingsView: View {
    let settings: SettingsStore
    private typealias S = L10n.Screenshots

    /// Bumped when Tolio becomes active again (e.g. back from System Settings),
    /// so the macOS-shortcut warning is re-checked.
    @State private var activations = 0

    /// macOS's own ⇧⌘4 is on and equals Tolio's area shortcut.
    private var macShortcutConflict: Bool {
        _ = activations
        return MacScreenshotShortcut.conflicts(with: settings.value(HotkeyManager.bindingsKey).combo(for: ScreenshotsFeature.areaHotkey))
    }

    var body: some View {
        Section(S.sectionScreenshots) {
            if macShortcutConflict {
                VStack(alignment: .leading, spacing: OmniStyle.s2) {
                    Label(S.macShortcutConflict, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).symbolRenderingMode(.multicolor)
                    Button(S.openKeyboardShortcuts) {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!) // l10n-ignore
                    }
                }
            }
            Picker(S.afterCapturing, selection: settings.binding(ScreenshotsFeature.afterKey)) {
                ForEach(AfterCapture.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .settingsAnchor(ScreenshotsAnchor.afterCapture)
            LabeledContent(S.saveTo) {
                HStack {
                    Text(ScreenshotsFeature.folder(settings).path(percentEncoded: false)).lineLimit(1).truncationMode(.middle)
                    Button(S.choose) { chooseFolder() }
                    if !settings.value(ScreenshotsFeature.folderKey).isEmpty {
                        Button(S.useMacOSSetting) { settings.set("", for: ScreenshotsFeature.folderKey) }
                    }
                }
            }
            .settingsAnchor(ScreenshotsAnchor.folder)
            if settings.value(ScreenshotsFeature.afterKey) == .editor {
                Toggle(S.autoCopyToggle, isOn: settings.binding(ScreenshotsFeature.autoCopyKey))
                    .settingsAnchor(ScreenshotsAnchor.autoCopy)
            }
            Toggle(S.windowShadow, isOn: settings.binding(ScreenshotsFeature.shadowKey))
                .settingsAnchor(ScreenshotsAnchor.shadow)
            Text(S.resolutionNote)
                .font(.caption).foregroundStyle(.secondary)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in activations += 1 }
        Section(S.sectionRecording) {
            Picker(S.frameRate, selection: settings.binding(ScreenshotsFeature.fpsKey)) {
                Text(S.fps(30)).tag(30)
                Text(S.fps(60)).tag(60)
            }
            .settingsAnchor(ScreenshotsAnchor.fps)
            Picker(S.videoFormat, selection: settings.binding(ScreenshotsFeature.codecKey)) {
                ForEach(VideoCodec.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .settingsAnchor(ScreenshotsAnchor.codec)
            Toggle(S.showPointer, isOn: settings.binding(ScreenshotsFeature.recordCursorKey))
                .settingsAnchor(ScreenshotsAnchor.pointer)
            Toggle(S.systemAudio, isOn: settings.binding(ScreenshotsFeature.systemAudioKey))
                .settingsAnchor(ScreenshotsAnchor.systemAudio)
            Toggle(S.microphone, isOn: settings.binding(ScreenshotsFeature.microphoneKey))
                .settingsAnchor(ScreenshotsAnchor.microphone)
            Text(S.recordingNote)
                .font(.caption).foregroundStyle(.secondary)
        }
        Section(S.sectionExperimental) {
            Toggle(S.scrollingToggle, isOn: settings.binding(ScreenshotsFeature.scrollingKey))
                .settingsAnchor(ScreenshotsAnchor.scrolling)
            Text(S.scrollingNote)
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
