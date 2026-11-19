import AppKit
import Carbon.HIToolbox
import OmniCore
import OmniPlatform
import SwiftUI

/// The popup panel: never key in normal use, so the app keeps the keyboard.
final class PopupPanel: NSPanel {
    var acceptsKey = false
    override var canBecomeKey: Bool { acceptsKey }
    override var canBecomeMain: Bool { false }
}

struct PopupOptions {
    var mouseTrigger = true
    var keyboardTrigger = true
    var copyFallback = true
    var excludedApps: Set<String> = []
    var enabledActions: Set<String>
    var searchEngine: SearchEngine = .google
}

/// Detects selections, reads them, shows the action bar, runs actions.
@MainActor
final class PopupController: NSObject {
    private var trigger = SelectionTrigger()
    private let model = PopupModel()
    private var panel: PopupPanel?
    private var selection: TextSelection?
    private var element: FocusedElement?
    private var targetPID: pid_t?
    private var checkGeneration = 0
    private var hideTask: Task<Void, Never>?
    private var observer: NSObjectProtocol?
    private let options: () -> PopupOptions
    private let log = Log.logger("textactions")
    /// Seconds the popup stays without interaction.
    static let lifetime: Duration = .seconds(8)

    init(options: @escaping () -> PopupOptions) {
        self.options = options
        super.init()
        model.onPerform = { [weak self] id in self?.perform(id) }
        model.onReplace = { [weak self] text in self?.replaceSelection(with: text) }
        model.onTranslationClosed = { [weak self] in self?.hide() }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated {
                guard let self, pid != ProcessInfo.processInfo.processIdentifier, pid != self.targetPID else { return }
                self.hide()
            }
        }
    }

    var isVisible: Bool { panel?.isVisible == true }

    // MARK: - Events

    func handle(_ event: SelectionTap.Event) {
        switch event {
        case let .mouseDown(point):
            if Self.isOmniWindow(at: point) { return }
            checkGeneration += 1 // a new click cancels a pending check
            if isVisible { hide() }
        case let .trigger(input):
            for effect in trigger.handle(input) { apply(effect) }
        }
    }

    private func apply(_ effect: SelectionTrigger.Effect) {
        switch effect {
        case .dismiss:
            checkGeneration += 1 // typing cancels a pending check
            if isVisible && model.translationText == nil { hide() }
        case let .check(kind, delay):
            let opts = options()
            switch kind {
            case let .mouse(_, up):
                // Clicks on the popup itself aren't selections.
                guard opts.mouseTrigger, !Self.isOmniWindow(at: up) else { return }
            case .keyboard: guard opts.keyboardTrigger else { return }
            }
            checkGeneration += 1
            let generation = checkGeneration
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self, generation == self.checkGeneration else { return }
                await self.check(kind, generation: generation)
            }
        }
    }

    // MARK: - Reading the selection

    private func check(_ kind: SelectionTrigger.Kind, generation: Int) async {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let opts = options()
        var context = SelectionGuard.Context(bundleID: app.bundleIdentifier)
        context.isOwnApp = app.processIdentifier == ProcessInfo.processInfo.processIdentifier
        context.secureInputEnabled = IsSecureEventInputEnabled()
        context.userExcluded = opts.excludedApps
        context.copyFallbackEnabled = opts.copyFallback
        // Cheap checks first (secure input, excluded apps) before any AX call.
        guard !isSkip(SelectionGuard.decide(context)) else { return }

        let pid = app.processIdentifier
        let result = await Task.detached(priority: .userInitiated) { SelectionReader.read(pid: pid) }.value
        guard generation == checkGeneration, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
        context.role = result.role
        context.subrole = result.subrole
        let decision = SelectionGuard.decide(context)
        if isSkip(decision) { return }

        switch result.kind {
        case .secure, .empty, .tooLong:
            return
        case let .text(text, editable, bounds):
            let selection = TextSelection(
                text: text, source: .accessibility, isEditable: editable,
                bounds: bounds.map(SelectionTap.appKitRect), appBundleID: app.bundleIdentifier
            )
            show(selection, element: result.element, pid: pid, kind: kind)
        case .unsupported:
            guard decision == .accessibilityThenCopy else { return }
            if case let .mouse(down, up) = kind {
                // Only gestures inside a window's content: not title-bar drags or resizes.
                guard let frame = result.windowFrame,
                      SelectionTrigger.isContentGesture(down: down, up: up, window: SelectionTap.appKitRect(frame)) else { return }
            }
            await copyFallback(pid: pid, bundleID: app.bundleIdentifier, kind: kind, generation: generation)
        }
    }

    private func isSkip(_ decision: SelectionGuard.Decision) -> Bool {
        if case .skip = decision { return true }
        return false
    }

    private func copyFallback(pid: pid_t, bundleID: String?, kind: SelectionTrigger.Kind, generation: Int) async {
        // Last checks right before posting ⌘C: no password entry started, no
        // mouse button or modifier held (⌘C would mix with the user's input).
        guard !IsSecureEventInputEnabled(),
              !CGEventSource.buttonState(.combinedSessionState, button: .left),
              CGEventSource.flagsState(.combinedSessionState).isDisjoint(with: [.maskCommand, .maskShift, .maskAlternate, .maskControl])
        else { return }
        PasteboardLease.begin()
        defer { PasteboardLease.end() }
        let outcome = await CopyFallback.read(
            from: SystemPasteboard(),
            sendCopy: { KeySender.copy() },
            wait: { try? await Task.sleep(for: $0) }
        )
        log.debug("Copy fallback: \(Self.describe(outcome), privacy: .public)")
        guard case let .text(text) = outcome, text.count <= SelectionReader.maxLength,
              generation == checkGeneration, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
        let selection = TextSelection(text: text, source: .copyFallback, isEditable: nil, bounds: nil, appBundleID: bundleID)
        show(selection, element: nil, pid: pid, kind: kind)
    }

    /// For logs: the outcome kind only, never the text.
    private static func describe(_ outcome: CopyFallback.Outcome) -> String {
        switch outcome {
        case let .text(text): "text (\(text.count) characters)"
        case .nothingCopied: "nothing copied"
        case let .discarded(reason): "discarded (\(reason))"
        }
    }

    // MARK: - Showing

    private func show(_ selection: TextSelection, element: FocusedElement?, pid: pid_t, kind: SelectionTrigger.Kind) {
        let opts = options()
        let actions = TextActionCatalog.available(for: selection, enabled: opts.enabledActions)
        guard !actions.isEmpty else { return }
        self.selection = selection
        self.element = element
        targetPID = pid
        model.translationText = nil
        model.actions = actions.map { PopupModel.ActionItem(id: $0.id, title: $0.title, symbolName: $0.symbolName) }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        // Some apps report bounds off screen; then use where the gesture ended.
        let fallback: CGRect = switch kind {
        case let .mouse(_, up): CGRect(origin: up, size: .zero)
        case .keyboard: CGRect(origin: NSEvent.mouseLocation, size: .zero)
        }
        let anchor = selection.bounds.flatMap { rect in
            NSScreen.screens.contains { $0.frame.intersects(rect.insetBy(dx: -1, dy: -1)) } ? rect : nil
        } ?? fallback
        place(panel, near: anchor, count: actions.count)
        panel.orderFrontRegardless()
        scheduleHide()
    }

    private func place(_ panel: PopupPanel, near anchor: CGRect, count: Int) {
        let size = CGSize(width: PopupView.width(for: count), height: PopupView.height)
        let point = CGPoint(x: anchor.midX, y: anchor.maxY)
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var origin = CGPoint(x: anchor.midX - size.width / 2, y: anchor.maxY + 8)
        if origin.y + size.height > visible.maxY { origin.y = anchor.minY - size.height - 8 }
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        panel.setFrame(CGRect(origin: origin, size: size).integral, display: false)
    }

    /// Hides after a while, unless the pointer is on it or translation is open.
    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            while true {
                try? await Task.sleep(for: Self.lifetime)
                guard let self, !Task.isCancelled else { return }
                if self.model.hovering || self.model.translationText != nil { continue }
                self.hide()
                return
            }
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        model.translationText = nil
        panel?.acceptsKey = false
        panel?.orderOut(nil)
        selection = nil
        element = nil
        targetPID = nil
    }

    func close() {
        hide()
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
        panel?.contentView = nil
        panel = nil
    }

    private func makePanel() -> PopupPanel {
        let panel = PopupPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        let host = NSHostingView(rootView: PopupView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        return panel
    }

    /// True if the point is over one of Omni's windows (popup, translation panel).
    private static func isOmniWindow(at point: CGPoint) -> Bool {
        let number = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
        return NSApp.windows.contains { $0.windowNumber == number && $0.isVisible }
    }

    // MARK: - Actions

    private func perform(_ id: String) {
        guard let selection, let action = TextActionCatalog.builtIn.first(where: { $0.id == id }) else { return }
        action.perform(selection, context: self)
        if model.translationText == nil { hide() }
    }
}

extension PopupController: TextActionContext {
    func replaceSelection(with text: String) {
        let element = self.element
        let source = selection?.source
        hide()
        if source == .accessibility, let element, element.replaceSelection(with: text) { return }
        // ⌘V of a temporary, history-ignored pasteboard; the old one comes back after.
        TemporaryPasteboard.paste(text)
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func pasteClipboard() {
        hide()
        KeySender.paste()
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func showMessage(_ text: String, symbol: String) {
        HUD.show(text, symbol: symbol)
    }

    func translate(_ text: String, replaceable: Bool) {
        hideTask?.cancel()
        model.translationReplaceable = replaceable
        model.translationText = text
        // The translation panel has controls; allow key focus while it's open.
        panel?.acceptsKey = true
    }

    var searchEngine: SearchEngine { options().searchEngine }
}
