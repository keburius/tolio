import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Opens editors and pinned images and keeps them alive while shown.
@MainActor
final class CaptureWindows: NSObject, NSWindowDelegate {
    private var windows: [NSWindow] = []
    private let saveFolder: () -> URL
    private let log = Log.logger("screenshots")

    init(saveFolder: @escaping () -> URL) {
        self.saveFolder = saveFolder
    }

    // MARK: - Editor

    func openEditor(_ capture: Capture) {
        let model = EditorModel(capture: capture)
        let window = NSWindow(
            contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
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
            copyText: { [weak self] in
                guard let image = model.export() else { return }
                self?.copyText(from: image)
            }
        )
        window.contentView = NSHostingView(rootView: EditorView(model: model, actions: actions))
        window.contentMinSize = CGSize(width: 640, height: 300)
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let size = CGSize(
            width: min(max(capture.pointSize.width + 40, 760), visible.width * 0.9),
            height: min(max(capture.pointSize.height + 90, 360), visible.height * 0.9)
        )
        window.setContentSize(size)
        window.center()
        windows.append(window)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
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
        // Release the SwiftUI tree (and the image) now.
        DispatchQueue.main.async { window.contentView = nil }
    }

    func closeAll() {
        for window in windows { window.delegate = nil; window.close() }
        windows.removeAll()
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
