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

    /// Anchors on the Recording tab (the rest are on the Screenshots tab).
    static let recordingTab: Set<String> = [fps, codec, pointer, systemAudio, microphone]
    static let screenshotsTab: Set<String> = [afterCapture, folder, shadow, autoCopy, scrolling]
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

    public var tagline: String { L10n.Screenshots.tagline }

    public func makeSettingsHero() -> AnyView? { AnyView(ScreenshotsHero()) }
}

/// The example under the header: an area selected on a window, with its size.
struct ScreenshotsHero: View {
    private let red = Color(hex: 0xFF5E55)

    var body: some View {
        ASStage(tint: red) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0x15161B))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1.2))
                    .heroPlace(1, 1, 298, 138)
                ForEach([18.0, 27, 36], id: \.self) { x in
                    Circle().fill(.white.opacity(0.4)).heroPlace(x - 2.5, 13.5, 5, 5)
                }
                RoundedRectangle(cornerRadius: 3).fill(red.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(red, style: StrokeStyle(lineWidth: 2, dash: [7, 5])))
                    .heroPlace(62, 30, 176, 74)
                ForEach(0 ..< 4, id: \.self) { corner in
                    Circle().fill(.white).heroPlace(corner % 2 == 0 ? 58 : 234, corner < 2 ? 26 : 100, 8, 8)
                }
                Text(verbatim: "640 × 360")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color(hex: 0x3A0A08))
                    .frame(width: 76, height: 22)
                    .background(Capsule().fill(red))
                    .heroPlace(112, 111, 76, 22)
            }
            .frame(width: 300, height: 140)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Screenshots.heroLabel)
        .accessibilityAddTraits(.isImage)
    }
}

extension View {
    /// Places a view like an SVG element: top-left corner and size, in the
    /// coordinate space of the enclosing fixed-size `ZStack(alignment: .topLeading)`.
    func heroPlace(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> some View {
        frame(width: width, height: height).offset(x: x, y: y)
    }
}

struct ScreenshotsSettingsView: View {
    let settings: SettingsStore
    private typealias S = L10n.Screenshots

    private enum Tab: Hashable { case screenshots, recording }

    @State private var tab = Tab.screenshots
    /// Bumped when All Set becomes active again (e.g. back from System Settings),
    /// so the macOS-shortcut warning is re-checked.
    @State private var activations = 0
    @State private var confirmingSwitch = false
    @State private var needsLogout = false
    @Environment(\.settingsHighlight) private var highlight

    /// macOS's own ⇧⌘4 is on and equals All Set's area shortcut.
    private var macShortcutConflict: Bool {
        _ = activations
        return MacScreenshotShortcut.conflicts(with: settings.value(HotkeyManager.bindingsKey).combo(for: ScreenshotsFeature.areaHotkey))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ASSegmented(S.settingsTabs, selection: $tab, options: [
                (Tab.screenshots, S.sectionScreenshots),
                (Tab.recording, S.tabRecording),
            ], size: .wide)
            switch tab {
            case .screenshots: screenshotsTab
            case .recording: recordingTab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in activations += 1 }
        .onChange(of: highlight, initial: true) { _, anchor in
            // Settings search: show the tab that holds the setting.
            guard let anchor else { return }
            if ScreenshotsAnchor.recordingTab.contains(anchor) { tab = .recording }
            if ScreenshotsAnchor.screenshotsTab.contains(anchor) { tab = .screenshots }
        }
    }

    // MARK: Screenshots

    private var screenshotsTab: some View {
        ASSection(footer: S.resolutionNote) {
            macShortcutRow
            ASRow(S.afterCapturing) {
                ASPopUp(S.afterCapturing, selection: settings.binding(ScreenshotsFeature.afterKey),
                        options: AfterCapture.allCases.map { ($0, $0.label) })
            }
            .settingsAnchor(ScreenshotsAnchor.afterCapture)
            ASRow(S.saveTo) {
                HStack(spacing: 10) {
                    Text(folderText)
                        .font(AS.body).foregroundStyle(AS.textSecondary)
                        .lineLimit(1).truncationMode(.middle)
                        .help(ScreenshotsFeature.folder(settings).path(percentEncoded: false))
                    if !settings.value(ScreenshotsFeature.folderKey).isEmpty {
                        Button(S.useMacOSSetting) { settings.set("", for: ScreenshotsFeature.folderKey) }
                            .buttonStyle(.asSecondary)
                    }
                    Button(S.choose) { chooseFolder() }
                        .buttonStyle(.asSecondary)
                }
            }
            .settingsAnchor(ScreenshotsAnchor.folder)
            if settings.value(ScreenshotsFeature.afterKey) == .editor {
                ASToggleRow(S.autoCopyToggle, isOn: settings.binding(ScreenshotsFeature.autoCopyKey))
                    .settingsAnchor(ScreenshotsAnchor.autoCopy)
            }
            ASToggleRow(S.windowShadow, isOn: settings.binding(ScreenshotsFeature.shadowKey))
                .settingsAnchor(ScreenshotsAnchor.shadow)
            ASToggleRow(S.scrollingToggle, subtitle: S.scrollingNote, isOn: settings.binding(ScreenshotsFeature.scrollingKey))
                .settingsAnchor(ScreenshotsAnchor.scrolling)
        }
    }

    /// macOS's own ⇧⌘4: a warning while it takes the key press first, or
    /// a way back once All Set has switched it off.
    @ViewBuilder private var macShortcutRow: some View {
        if macShortcutConflict {
            HStack(alignment: .top, spacing: 10) {
                LineIcon(ASIcon.warning, size: 14, lineWidth: 2, color: AS.orange).padding(.top, 1)
                VStack(alignment: .leading, spacing: 8) {
                    Text(S.macShortcutConflict)
                        .font(AS.body).foregroundStyle(AS.text)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button(S.useShortcutForAllSet) { confirmingSwitch = true }
                            .buttonStyle(.asPrimary)
                        Button(S.openKeyboardShortcuts) {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!) // l10n-ignore
                        }
                        .buttonStyle(.asSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .confirmationDialog(S.useShortcutConfirmTitle, isPresented: $confirmingSwitch) {
                Button(S.useShortcutConfirmButton) { switchMacShortcut(enabled: false) }
            } message: {
                Text(S.useShortcutConfirmMessage)
            }
        } else if settings.value(ScreenshotsFeature.turnedOffMacShortcutKey) {
            HStack(spacing: 12) {
                Group {
                    if needsLogout {
                        Text(S.macShortcutNeedsLogout)
                    } else {
                        macShortcutIsOffText
                    }
                }
                .font(AS.body).foregroundStyle(AS.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(S.restoreMacShortcut) { switchMacShortcut(enabled: true) }
                    .buttonStyle(.asSecondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
        }
    }

    /// "macOS's own ⇧ ⌘ 4 is off, …" with the shortcut drawn as key caps.
    private var macShortcutIsOffText: some View {
        let marker = "\u{1}"
        let parts = S.macShortcutIsOff(marker).components(separatedBy: marker)
        return HStack(spacing: 4) {
            if let first = parts.first, !first.isEmpty { Text(first.trimmingCharacters(in: .whitespaces)) }
            KeyCaps("⇧⌘4", spacing: 2) // l10n-ignore
            if parts.count > 1, !parts[1].isEmpty { Text(parts[1].trimmingCharacters(in: .whitespaces)).lineLimit(1) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(S.macShortcutIsOff("⇧⌘4")) // l10n-ignore
    }

    /// The folder as the design shows it: "Desktop › Screenshots".
    private var folderText: String {
        let url = ScreenshotsFeature.folder(settings).standardizedFileURL
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.pathComponents
        var parts = url.pathComponents
        if parts.starts(with: home), parts.count > home.count { parts.removeFirst(home.count) } else { parts.removeAll { $0 == "/" } }
        return parts.joined(separator: " › ")
    }

    // MARK: Recording

    private var recordingTab: some View {
        ASSection(footer: S.recordingNote) {
            ASRow(S.frameRate) {
                ASPopUp(S.frameRate, selection: settings.binding(ScreenshotsFeature.fpsKey), options: [(30, S.fps(30)), (60, S.fps(60))])
            }
            .settingsAnchor(ScreenshotsAnchor.fps)
            ASRow(S.videoFormat) {
                ASPopUp(S.videoFormat, selection: settings.binding(ScreenshotsFeature.codecKey),
                        options: VideoCodec.allCases.map { ($0, $0.label) })
            }
            .settingsAnchor(ScreenshotsAnchor.codec)
            ASToggleRow(S.showPointer, isOn: settings.binding(ScreenshotsFeature.recordCursorKey))
                .settingsAnchor(ScreenshotsAnchor.pointer)
            ASToggleRow(S.systemAudio, isOn: settings.binding(ScreenshotsFeature.systemAudioKey))
                .settingsAnchor(ScreenshotsAnchor.systemAudio)
            ASToggleRow(S.microphone, subtitle: S.microphoneNote, isOn: settings.binding(ScreenshotsFeature.microphoneKey))
                .settingsAnchor(ScreenshotsAnchor.microphone)
        }
    }

    // MARK: Actions

    private func switchMacShortcut(enabled: Bool) {
        let applied = MacScreenshotShortcut.setMacShortcutEnabled(enabled)
        settings.set(!enabled, for: ScreenshotsFeature.turnedOffMacShortcutKey)
        needsLogout = !applied
        activations += 1
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
