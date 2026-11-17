import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Opens editors and pinned images and keeps them alive while shown.
@MainActor
final class CaptureWindows: NSObject, NSWindowDelegate {
    private var windows: [NSWindow] = []
    /// Auto-copy countdowns of open editors.
    private var countdowns: [ObjectIdentifier: Timer] = [:]
    /// Seconds an untouched editor waits before copying and closing.
    static let autoCopyDelay: TimeInterval = 3
    private let saveFolder: () -> URL
    private let log = Log.logger("screenshots")

    init(saveFolder: @escaping () -> URL) {
        self.saveFolder = saveFolder
    }

    // MARK: - Editor

    /// Opens the editor in front and ready for keys. With `autoCopy`, a
    /// visible countdown copies the screenshot and closes the editor unless
    /// the user clicks or presses a key in it first.
    func openEditor(_ capture: Capture, autoCopy: Bool = false) {
        let model = EditorModel(capture: capture)
        // A non-activating panel takes keyboard focus right away, even when
        // macOS doesn't let Tolio become the active app.
        let window = EditorPanel(
            contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = false
        window.title = L10n.Screenshots.editorWindowTitle
        window.isReleasedWhenClosed = false
        window.delegate = self
        let actions = EditorActions(
            copy: { [weak self, weak window] in
                guard let image = model.export() else { return }
                CaptureOutput.copy(image, scale: capture.scale)
                HUD.show(L10n.Screenshots.copied, symbol: "doc.on.doc")
                self?.close(window)
            },
            save: { [weak self, weak window] in
                guard let self, let image = model.export() else { return }
                if self.save(image, scale: capture.scale, date: capture.date) { self.close(window) }
            },
            pin: { [weak self, weak window] in
                guard let self, let image = model.export() else { return }
                self.pin(Capture(image: image, scale: capture.scale, date: capture.date))
                self.close(window)
            },
            close: { [weak self, weak window] in self?.close(window) },
            discard: { [weak self, weak window] in
                self?.close(window)
                HUD.show(L10n.Screenshots.screenshotDeleted, symbol: "trash")
            },
            copyText: { [weak self] in
                guard let image = model.export() else { return }
                self?.copyText(from: image)
            }
        )
        window.contentView = NSHostingView(rootView: EditorView(model: model, actions: actions))
        // Never narrower than the toolbar, so no button loses its label.
        let toolbarWidth = ceil(NSHostingView(rootView: EditorView(model: model, actions: actions, toolbarOnly: true)).fittingSize.width)
        window.contentMinSize = CGSize(width: max(640, toolbarWidth), height: 300)
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let size = CGSize(
            width: min(max(capture.pointSize.width + 40, 760, toolbarWidth), max(visible.width * 0.9, toolbarWidth)),
            height: min(max(capture.pointSize.height + 90, 360), visible.height * 0.9)
        )
        window.setContentSize(size)
        window.center()
        // Opens on the current Space (also over full-screen apps) and stays
        // above other apps' windows until it's closed.
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        windows.append(window)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if autoCopy { startCountdown(window: window, model: model, copy: actions.copy) }
    }

    // MARK: - Auto-copy countdown

    private func startCountdown(window: EditorPanel, model: EditorModel, copy: @escaping () -> Void) {
        let id = ObjectIdentifier(window)
        let deadline = Date().addingTimeInterval(Self.autoCopyDelay)
        model.autoCopyRemaining = Self.autoCopyDelay
        window.onCountdownEnd = copy
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self, weak model, weak window] _ in
            MainActor.assumeIsolated {
                guard let self, let model, model.autoCopyRemaining != nil else { self?.stopCountdown(id); return }
                let left = deadline.timeIntervalSinceNow
                if left <= 0 {
                    self.stopCountdown(id)
                    model.autoCopyRemaining = nil
                    window?.onCountdownEnd?()
                } else {
                    model.autoCopyRemaining = left
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdowns[id] = timer
        // Any click, key press or scroll in the editor means "I'm editing".
        window.onInteraction = { [weak self, weak model] in
            model?.autoCopyRemaining = nil
            self?.stopCountdown(id)
        }
    }

    private func stopCountdown(_ id: ObjectIdentifier) {
        countdowns.removeValue(forKey: id)?.invalidate()
    }

    @discardableResult
    func save(_ image: CGImage, scale: CGFloat, date: Date) -> Bool {
        do {
            let url = try CaptureOutput.save(image, scale: scale, to: saveFolder(), date: date)
            HUD.show(L10n.Screenshots.savedTo(url.deletingLastPathComponent().lastPathComponent), symbol: "square.and.arrow.down")
            return true
        } catch {
            log.error("Save failed: \(error.localizedDescription, privacy: .public)")
            HUD.show(L10n.Screenshots.couldntSave(error.localizedDescription), symbol: "exclamationmark.triangle")
            return false
        }
    }

    /// The editor's Copy Text: the same recognition and settings as Capture Text.
    var recognizeText: ((CGImage) -> Void)?

    func copyText(from image: CGImage) {
        recognizeText?(image)
    }

    private func close(_ window: NSWindow?) {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windows.removeAll { $0 === window }
        stopCountdown(ObjectIdentifier(window))
        // Release the SwiftUI tree (and the image) now.
        DispatchQueue.main.async { window.contentView = nil }
    }

    func closeAll() {
        for window in windows { window.delegate = nil; window.close() }
        windows.removeAll()
        countdowns.values.forEach { $0.invalidate() }
        countdowns.removeAll()
    }

    // MARK: - Pin

    func pin(_ capture: Capture) {
        let visible = (NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        var size = capture.pointSize
        let fit = min(1, visible.width * 0.8 / size.width, visible.height * 0.8 / size.height)
        size = CGSize(width: (size.width * fit).rounded(), height: (size.height * fit).rounded())
        let panel = PinPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.contentAspectRatio = size
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        let view = PinView(
            capture: capture,
            onClose: { [weak panel] in panel?.close() },
            onCopy: { CaptureOutput.copy(capture.image, scale: capture.scale); HUD.show(L10n.Screenshots.copied, symbol: "doc.on.doc") },
            onSave: { [weak self] in self?.save(capture.image, scale: capture.scale, date: capture.date) },
            onEdit: { [weak self, weak panel] in panel?.close(); self?.openEditor(capture) }
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.setFrameOrigin(CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
        windows.append(panel)
        panel.orderFrontRegardless()
    }
}

final class PinPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { close() }
}

private struct PinView: View {
    let capture: Capture
    let onClose: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void
    let onEdit: () -> Void
    @State private var hovering = false
    @State private var opacity = 1.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(decorative: capture.image, scale: capture.scale)
                .resizable()
                .interpolation(.high)
                .opacity(opacity)
            if hovering {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 18)).symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(OmniStyle.s2)
                .help(L10n.Screenshots.closePinHelp)
                .accessibilityLabel(L10n.Common.close)
            }
        }
        .overlay(Rectangle().strokeBorder(.white.opacity(hovering ? 0.5 : 0)))
        .onHover { hovering = $0 }
        .contextMenu {
            Button(L10n.Screenshots.copy, action: onCopy)
            Button(L10n.Screenshots.save, action: onSave)
            Button(L10n.Screenshots.edit, action: onEdit)
            Menu(L10n.Screenshots.opacity) {
                ForEach([1.0, 0.75, 0.5, 0.25], id: \.self) { value in
                    Button(L10n.Screenshots.percent(Int(value * 100))) { opacity = value }
                }
            }
            Divider()
            Button(L10n.Common.close, action: onClose)
        }
    }
}

/// The editor window: a non-activating panel that still becomes key, and
/// reports the first sign of editing (click, key press, scroll).
final class EditorPanel: NSPanel {
    var onInteraction: (() -> Void)?
    /// What the countdown does when it reaches zero (copy and close).
    var onCountdownEnd: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel:
            if let onInteraction {
                self.onInteraction = nil
                onInteraction()
            }
        default: break
        }
        super.sendEvent(event)
    }
}
