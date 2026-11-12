import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Capture Text: select part of the screen and copy the text, QR code or
/// barcode in it. A feature of its own (separate from Screenshots &
/// Recording) that shares the selection overlay and Vision recognition.
@MainActor
@Observable
public final class CaptureTextFeature: Feature {
    static let lineBreakKey = SettingKey.feature("capturetext", "lineBreaks", default: LineBreakMode.keep)
    /// Empty = the user's macOS languages that Vision supports.
    static let languagesKey = SettingKey.feature("capturetext", "languages", default: [String]())
    static let autoLanguageKey = SettingKey.feature("capturetext", "autoLanguage", default: false)
    static let speakKey = SettingKey.feature("capturetext", "speak", default: false)

    /// ⌘⇧2 (macOS doesn't use it).
    public static let captureHotkey = HotkeyAction(
        id: "capturetext.capture", title: L10n.Screenshots.hotkeyText,
        defaultCombo: KeyCombo(keyCode: 19, modifiers: [.command, .shift])
    )

    enum Anchor {
        static let lineBreaks = "capturetext.lineBreaks"
        static let languages = "capturetext.languages"
        static let autoLanguage = "capturetext.autoLanguage"
        static let speak = "capturetext.speak"
    }

    public let id: FeatureID = "capturetext"
    public var displayName: String { L10n.Screenshots.captureText }
    public var summary: String { L10n.Screenshots.captureTextSummary }
    public let symbolName = "text.viewfinder"
    public let requiredPermissions: Set<Permission> = [.screenRecording]

    @ObservationIgnored private var settings: SettingsStore?
    @ObservationIgnored private let controller = CaptureTextController()
    @ObservationIgnored private var busy = false

    public init() {}

    public var declaredHotkeys: [HotkeyAction] { [Self.captureHotkey] }

    public var settingsEntries: [SettingsEntry] {
        typealias S = L10n.Screenshots
        return [
            SettingsEntry(anchor: Anchor.lineBreaks, label: S.lineBreaks, keywords: ["ocr", "paragraph", "lines"]),
            SettingsEntry(anchor: Anchor.languages, label: S.recognitionLanguages, keywords: ["ocr", "language"]),
            SettingsEntry(anchor: Anchor.autoLanguage, label: S.autoLanguage, keywords: ["ocr", "detect", "language"]),
            SettingsEntry(anchor: Anchor.speak, label: S.speakAloud, keywords: ["read aloud", "speech", "voice"]),
        ]
    }

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        context.registerHotkey(Self.captureHotkey) { [weak self] in self?.capture() }
        context.registerCommand(Command(
            id: "capturetext.capture", title: L10n.Screenshots.captureText, subtitle: L10n.Screenshots.captureTextSubtitle,
            keywords: ["ocr", "recognize", "text", "qr", "barcode", "copy text"], symbolName: symbolName
        ) { [weak self] in self?.captureAfterUICloses() })
    }

    public func disable() {
        settings = nil
    }

    /// One capture at a time.
    func capture() {
        guard let settings, !busy else { return }
        busy = true
        Task { @MainActor in
            await controller.run(settings: settings)
            busy = false
        }
    }

    /// From the Launcher or a menu: wait until it has closed so it isn't in the selection.
    private func captureAfterUICloses() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            capture()
        }
    }

    // MARK: Menu bar icon

    public var quickAccessItems: [QuickAccessItem] {
        [QuickAccessItem(
            id: .captureText, title: L10n.Screenshots.captureText, symbolName: symbolName,
            clickHint: L10n.Screenshots.captureTextClickHint, shortcutID: Self.captureHotkey.id,
            primary: { [weak self] in self?.captureAfterUICloses() },
            menu: { [weak self] in self?.optionsMenu() ?? [] }
        )]
    }

    func optionsMenu() -> [MenuEntry] {
        guard let settings else { return [] }
        typealias S = L10n.Screenshots
        let mode = settings.value(Self.lineBreakKey)
        return [
            .action(MenuAction(S.captureText, shortcutID: Self.captureHotkey.id) { [weak self] in self?.captureAfterUICloses() }),
            .header(S.appendHint),
            .separator,
            .submenu(title: S.lineBreaks, entries: [
                .action(MenuAction(S.lineBreaksKeep, isChecked: mode == .keep) { settings.set(LineBreakMode.keep, for: Self.lineBreakKey) }),
                .action(MenuAction(S.lineBreaksJoin, isChecked: mode == .join) { settings.set(LineBreakMode.join, for: Self.lineBreakKey) }),
            ]),
            .action(MenuAction(S.autoLanguage, isChecked: settings.value(Self.autoLanguageKey)) {
                settings.set(!settings.value(Self.autoLanguageKey), for: Self.autoLanguageKey)
            }),
            .action(MenuAction(S.speakAloud, isChecked: settings.value(Self.speakKey)) {
                settings.set(!settings.value(Self.speakKey), for: Self.speakKey)
            }),
        ]
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(CaptureTextSettings(settings: settings))
    }
}

/// Capture Text options.
struct CaptureTextSettings: View {
    let settings: SettingsStore
    private typealias S = L10n.Screenshots
    @State private var supported: [String] = []

    var body: some View {
        Section(S.sectionCaptureText) {
            Picker(S.lineBreaks, selection: settings.binding(CaptureTextFeature.lineBreakKey)) {
                Text(S.lineBreaksKeep).tag(LineBreakMode.keep)
                Text(S.lineBreaksJoin).tag(LineBreakMode.join)
            }
            .settingsAnchor(CaptureTextFeature.Anchor.lineBreaks)
            LabeledContent(S.recognitionLanguages) {
                Menu(summary) {
                    Button(S.languagesMatchMac) { settings.set([], for: CaptureTextFeature.languagesKey) }
                    Divider()
                    ForEach(supported, id: \.self) { code in
                        Toggle(Self.name(code), isOn: Binding(
                            get: { chosen.contains(code) },
                            set: { on in
                                var list = chosen
                                if on { if !list.contains(code) { list.append(code) } } else { list.removeAll { $0 == code } }
                                settings.set(list, for: CaptureTextFeature.languagesKey)
                            }
                        ))
                    }
                }
                .fixedSize()
            }
            .settingsAnchor(CaptureTextFeature.Anchor.languages)
            Toggle(S.autoLanguage, isOn: settings.binding(CaptureTextFeature.autoLanguageKey))
                .settingsAnchor(CaptureTextFeature.Anchor.autoLanguage)
            Text(S.autoLanguageNote).font(.caption).foregroundStyle(.secondary)
            Toggle(S.speakAloud, isOn: settings.binding(CaptureTextFeature.speakKey))
                .settingsAnchor(CaptureTextFeature.Anchor.speak)
            Text(S.captureTextNote).font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { if supported.isEmpty { supported = TextRecognizer.supportedLanguages() } }
    }

    private var chosen: [String] { settings.value(CaptureTextFeature.languagesKey) }

    private var summary: String {
        let list = chosen
        if list.isEmpty { return S.languagesMatchMacSummary(CaptureTextController.languages(settings).map(Self.name).joined(separator: ", ")) }
        return list.map(Self.name).joined(separator: ", ")
    }

    static func name(_ code: String) -> String {
        Locale.current.localizedString(forIdentifier: code) ?? code
    }
}
