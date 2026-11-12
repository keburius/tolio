import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Settings Search anchors of the Screenshots & Recording page.
enum ScreenshotsAnchor {
    static let afterCapture = "screenshots.afterCapture"
    static let folder = "screenshots.folder"
    static let shadow = "screenshots.windowShadow"
    static let fps = "screenshots.fps"
    static let codec = "screenshots.codec"
    static let pointer = "screenshots.recordCursor"
    static let systemAudio = "screenshots.systemAudio"
    static let microphone = "screenshots.microphone"
    static let scrolling = "screenshots.scrolling"
    static let lineBreaks = "screenshots.captureText.lineBreaks"
    static let languages = "screenshots.captureText.languages"
    static let autoLanguage = "screenshots.captureText.autoLanguage"
    static let speak = "screenshots.captureText.speak"
}

extension ScreenshotsFeature {
    public var settingsEntries: [SettingsEntry] {
        typealias S = L10n.Screenshots
        return [
            SettingsEntry(anchor: ScreenshotsAnchor.afterCapture, label: S.afterCapturing, keywords: ["editor", "copy", "save", "pin", "after"]),
            SettingsEntry(anchor: ScreenshotsAnchor.folder, label: S.saveTo, keywords: ["folder", "location", "directory", "save"]),
            SettingsEntry(anchor: ScreenshotsAnchor.shadow, label: S.windowShadow, keywords: ["shadow", "window"]),
            SettingsEntry(anchor: ScreenshotsAnchor.fps, label: S.frameRate, keywords: ["fps", "frames", "video", "recording"]),
            SettingsEntry(anchor: ScreenshotsAnchor.codec, label: S.videoFormat, keywords: ["video", "codec", "hevc", "h.264", "mp4"]),
            SettingsEntry(anchor: ScreenshotsAnchor.pointer, label: S.showPointer, keywords: ["cursor", "mouse", "pointer", "video"]),
            SettingsEntry(anchor: ScreenshotsAnchor.systemAudio, label: S.systemAudio, keywords: ["audio", "sound", "video"]),
            SettingsEntry(anchor: ScreenshotsAnchor.microphone, label: S.microphone, keywords: ["mic", "voice", "audio", "video"]),
            SettingsEntry(anchor: ScreenshotsAnchor.scrolling, label: S.scrollingToggle, keywords: ["long screenshot", "scroll", "experimental"]),
            SettingsEntry(anchor: ScreenshotsAnchor.lineBreaks, label: S.lineBreaks, keywords: ["ocr", "capture text", "paragraph"]),
            SettingsEntry(anchor: ScreenshotsAnchor.languages, label: S.recognitionLanguages, keywords: ["ocr", "language", "capture text"]),
            SettingsEntry(anchor: ScreenshotsAnchor.autoLanguage, label: S.autoLanguage, keywords: ["ocr", "detect", "language"]),
            SettingsEntry(anchor: ScreenshotsAnchor.speak, label: S.speakAloud, keywords: ["read aloud", "speech", "voice"]),
        ]
    }
}

struct ScreenshotsSettingsView: View {
    let settings: SettingsStore
    private typealias S = L10n.Screenshots

    var body: some View {
        Section(S.sectionScreenshots) {
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
            Toggle(S.windowShadow, isOn: settings.binding(ScreenshotsFeature.shadowKey))
                .settingsAnchor(ScreenshotsAnchor.shadow)
            Text(S.resolutionNote)
                .font(.caption).foregroundStyle(.secondary)
        }
        CaptureTextSettings(settings: settings)
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

/// Capture Text options.
private struct CaptureTextSettings: View {
    let settings: SettingsStore
    private typealias S = L10n.Screenshots
    @State private var supported: [String] = []

    var body: some View {
        Section(S.sectionCaptureText) {
            Picker(S.lineBreaks, selection: settings.binding(ScreenshotsFeature.lineBreakKey)) {
                Text(S.lineBreaksKeep).tag(LineBreakMode.keep)
                Text(S.lineBreaksJoin).tag(LineBreakMode.join)
            }
            .settingsAnchor(ScreenshotsAnchor.lineBreaks)
            LabeledContent(S.recognitionLanguages) {
                Menu(summary) {
                    Button(S.languagesMatchMac) { settings.set([], for: ScreenshotsFeature.languagesKey) }
                    Divider()
                    ForEach(supported, id: \.self) { code in
                        Toggle(Self.name(code), isOn: Binding(
                            get: { chosen.contains(code) },
                            set: { on in
                                var list = chosen
                                if on { if !list.contains(code) { list.append(code) } } else { list.removeAll { $0 == code } }
                                settings.set(list, for: ScreenshotsFeature.languagesKey)
                            }
                        ))
                    }
                }
                .fixedSize()
            }
            .settingsAnchor(ScreenshotsAnchor.languages)
            Toggle(S.autoLanguage, isOn: settings.binding(ScreenshotsFeature.autoLanguageKey))
                .settingsAnchor(ScreenshotsAnchor.autoLanguage)
            Text(S.autoLanguageNote).font(.caption).foregroundStyle(.secondary)
            Toggle(S.speakAloud, isOn: settings.binding(ScreenshotsFeature.speakKey))
                .settingsAnchor(ScreenshotsAnchor.speak)
            Text(S.captureTextNote).font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { if supported.isEmpty { supported = TextRecognizer.supportedLanguages() } }
    }

    private var chosen: [String] { settings.value(ScreenshotsFeature.languagesKey) }

    private var summary: String {
        let list = chosen
        if list.isEmpty { return S.languagesMatchMacSummary(CaptureTextController.languages(settings).map(Self.name).joined(separator: ", ")) }
        return list.map(Self.name).joined(separator: ", ")
    }

    static func name(_ code: String) -> String {
        Locale.current.localizedString(forIdentifier: code) ?? code
    }
}
