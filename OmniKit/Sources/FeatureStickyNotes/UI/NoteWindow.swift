import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// One note on screen: a borderless, resizable panel that sits on the
/// desktop (above icons, behind app windows) or floats when "Keep on top"
/// is on. It takes typing without bringing Omni forward.
@MainActor
final class NoteWindow: NSObject, NSWindowDelegate {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    /// Desktop notes: just above the desktop icons.
    static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    let id: UUID
    let model: NoteModel
    private let panel: Panel
    private let onChange: (StickyNote) -> Void
    private var saveTask: Task<Void, Never>?

    init(note: StickyNote, allSpaces: Bool, actions: NoteActions, onChange: @escaping (StickyNote) -> Void) {
        id = note.id
        model = NoteModel(note: note)
        self.onChange = onChange
        panel = Panel(
            contentRect: note.frame,
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        super.init()
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { panel.standardWindowButton(button)?.isHidden = true }
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = StickyNote.minimumSize
        panel.delegate = self
        model.onTextChange = { [weak self] in self?.scheduleSave() }
        panel.contentView = NSHostingView(rootView: NoteView(model: model, actions: actions))
        apply(allSpaces: allSpaces)
        panel.setFrame(note.frame, display: false)
    }

    func show() { panel.orderFrontRegardless() }

    func focus() {
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func close() {
        flush()
        panel.delegate = nil
        panel.orderOut(nil)
        panel.contentView = nil
    }

    /// Level and Space behaviour from the note and settings.
    func apply(allSpaces: Bool, raised: Bool = false) {
        panel.level = model.note.keepOnTop || raised ? .floating : Self.desktopLevel
        var behavior: NSWindow.CollectionBehavior = [.ignoresCycle, .fullScreenAuxiliary]
        if allSpaces { behavior.insert(.canJoinAllSpaces) }
        // Desktop notes stay put during Mission Control and Show Desktop, like widgets.
        if !model.note.keepOnTop { behavior.insert(.stationary) }
        panel.collectionBehavior = behavior
    }

    // MARK: - Saving

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Writes the current text and frame now.
    func flush() {
        saveTask?.cancel()
        var note = model.note
        note.frame = panel.frame
        onChange(note)
    }

    func windowDidMove(_ notification: Notification) { flush() }
    func windowDidEndLiveResize(_ notification: Notification) { flush() }
    func windowDidResignKey(_ notification: Notification) { flush() }
}

/// What a note's buttons do; implemented by the feature.
@MainActor
struct NoteActions {
    var newNote: () -> Void
    var delete: (UUID) -> Void
    var setTint: (UUID, NoteTint) -> Void
    var setKeepOnTop: (UUID, Bool) -> Void
}

@MainActor
@Observable
final class NoteModel {
    var note: StickyNote
    @ObservationIgnored var onTextChange: () -> Void = {}

    init(note: StickyNote) { self.note = note }

    var text: String {
        get { note.text }
        set {
            note.text = newValue
            onTextChange()
        }
    }
}
