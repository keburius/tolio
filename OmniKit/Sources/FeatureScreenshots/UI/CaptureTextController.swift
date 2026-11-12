import AppKit
import AVFoundation
import OmniCore
import OmniPlatform

/// Capture Text: select an area → recognize text and codes → copy.
@MainActor
final class CaptureTextController {
    private var composer = CaptureTextComposer()
    private let speech = AVSpeechSynthesizer()
    private let log = Log.logger("capturetext")

    /// Runs one capture with the current settings.
    func run(settings: SettingsStore) async {
        speech.stopSpeaking(at: .immediate)
        let choice = await SelectionOverlay.choose(.text)
        let append = SelectionOverlay.lastFinishedWithShift
        let capture: Capture
        do {
            switch choice {
            case .cancelled: return
            case let .area(rect): capture = try await ScreenCapturer.capture(area: rect)
            case let .window(window): capture = try await ScreenCapturer.capture(windowID: window.id, shadow: false)
            }
        } catch {
            HUD.show("\(error)", symbol: "exclamationmark.triangle")
            return
        }
        await recognize(capture.image, settings: settings, append: append)
    }

    /// Recognizes `image` and copies the result (also used by the editor's Copy Text).
    func recognize(_ image: CGImage, settings: SettingsStore, append: Bool = false) async {
        HUD.show(L10n.Screenshots.recognizingText, symbol: "text.viewfinder", duration: .seconds(10))
        let options = TextRecognizer.Options(
            languages: Self.languages(settings),
            automaticLanguageDetection: settings.value(ScreenshotsFeature.autoLanguageKey)
        )
        let result: TextRecognizer.Result
        do {
            result = try await TextRecognizer.recognize(in: image, options: options)
        } catch {
            HUD.show(L10n.Screenshots.textRecognitionFailed, symbol: "exclamationmark.triangle")
            return
        }
        let outcome = composer.compose(
            lines: result.lines, codes: result.codes,
            mode: settings.value(ScreenshotsFeature.lineBreakKey), append: append
        )
        // Counts only; never the text.
        log.info("Capture Text: \(result.lines.count) lines, \(result.codes.count) codes")
        switch outcome {
        case .empty:
            HUD.show(L10n.Screenshots.noTextFound, symbol: "text.viewfinder")
        case let .text(text, added, appended):
            Self.copy(text)
            HUD.show(appended ? L10n.Screenshots.appendedCharacters(added.count, text.count) : L10n.Screenshots.copiedCharacters(text.count), symbol: "text.viewfinder")
            speakIfWanted(added, settings: settings)
        case let .code(text, link):
            Self.copy(text)
            if let link {
                ActionToast.show(L10n.Screenshots.copiedLink(link.host ?? link.absoluteString), symbol: "qrcode", actionTitle: L10n.Screenshots.open) {
                    NSWorkspace.shared.open(link)
                }
            } else {
                HUD.show(L10n.Screenshots.copiedCode(text.count), symbol: "qrcode")
            }
            speakIfWanted(text, settings: settings)
        }
    }

    /// The chosen languages, or the user's macOS languages Vision supports.
    static func languages(_ settings: SettingsStore) -> [String] {
        let chosen = settings.value(ScreenshotsFeature.languagesKey)
        if !chosen.isEmpty { return chosen }
        let supported = TextRecognizer.supportedLanguages()
        let preferred = Locale.preferredLanguages.compactMap { language in
            supported.first { $0 == language } ?? supported.first { $0.hasPrefix(String(language.prefix(2))) }
        }
        return preferred.isEmpty ? ["en-US"] : Array(NSOrderedSet(array: preferred)) as? [String] ?? preferred
    }

    /// A normal copy, marked so clipboard history shows "Captured text".
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType(PasteboardTypes.capturedText))
        pasteboard.writeObjects([item])
    }

    private func speakIfWanted(_ text: String, settings: SettingsStore) {
        guard settings.value(ScreenshotsFeature.speakKey) else { return }
        speech.speak(AVSpeechUtterance(string: String(text.prefix(4000))))
    }
}
