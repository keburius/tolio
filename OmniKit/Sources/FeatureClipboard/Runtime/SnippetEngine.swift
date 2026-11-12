import AppKit
import Carbon.HIToolbox
import OmniCore
import OmniPlatform

/// Watches typing with a listen-only event tap and expands snippets.
///
/// - The tap is listen-only: it can never block or delay keystrokes.
/// - The typed-character buffer is in memory only and never logged.
/// - Nothing is buffered while secure input (password fields) is on.
@MainActor
final class SnippetEngine {
    private let snippets: () -> [Snippet]
    private let log = Log.logger("snippets")
    private var buffer = KeystrokeBuffer()
    private var tap: EventTap?
    private var appObserver: NSObjectProtocol?
    private var isExpanding = false

    init(snippets: @escaping () -> [Snippet]) {
        self.snippets = snippets
    }

    func start() throws {
        let tap = EventTap(
            mask: EventTap.mask(.keyDown, .leftMouseDown, .rightMouseDown),
            mode: .listenOnly
        ) { [weak self] type, event in
            self?.observe(type: type, event: event)
            return false
        }
        try tap.start()
        self.tap = tap
        // Typing in a different app starts a fresh word.
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.buffer.reset() }
        }
    }

    func stop() {
        tap?.stop()
        tap = nil
        if let appObserver { NSWorkspace.shared.notificationCenter.removeObserver(appObserver) }
        appObserver = nil
        buffer.reset()
    }

    /// Inserts a snippet at the caret (used from the palette).
    func insert(_ snippet: Snippet) {
        let expansion = PlaceholderExpander.expand(
            snippet.body, now: Date(), clipboard: NSPasteboard.general.string(forType: .string)
        )
        TemporaryPasteboard.paste(expansion.text) {
            if let offset = expansion.cursorOffsetFromEnd, offset > 0 { KeySender.left(times: offset) }
        }
    }

    private func observe(type: CGEventType, event: CGEvent) {
        guard type == .keyDown else {
            buffer.reset() // A click may move the caret.
            return
        }
        guard !KeySender.isOwnEvent(event), !isExpanding else { return }
        if IsSecureEventInputEnabled() {
            buffer.reset()
            return
        }
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            buffer.reset()
            return
        }
        switch Int(event.getIntegerValueField(.keyboardEventKeycode)) {
        case kVK_Delete:
            buffer.backspace()
            return
        case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Tab, kVK_Escape, kVK_ForwardDelete,
             kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow,
             kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown:
            buffer.reset()
            return
        default:
            break
        }
        var length = 0
        var chars = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return }
        buffer.append(String(utf16CodeUnits: chars, count: length))

        if let snippet = buffer.match(in: snippets()) {
            buffer.reset()
            // Leave the tap callback right away; expand on the next run loop turn,
            // after the triggering keystroke has reached the app.
            Task { @MainActor [weak self] in self?.expand(snippet) }
        }
    }

    private func expand(_ snippet: Snippet) {
        guard !IsSecureEventInputEnabled() else { return }
        isExpanding = true
        KeySender.backspace(times: snippet.abbreviation.count)
        let expansion = PlaceholderExpander.expand(
            snippet.body, now: Date(), clipboard: NSPasteboard.general.string(forType: .string)
        )
        TemporaryPasteboard.paste(expansion.text) { [weak self] in
            if let offset = expansion.cursorOffsetFromEnd, offset > 0 { KeySender.left(times: offset) }
            self?.isExpanding = false
        }
        log.debug("Expanded a snippet (\(expansion.text.count) characters)")
    }
}
