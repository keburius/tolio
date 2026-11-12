import AppKit
import OmniCore
import OmniPlatform

/// Puts a history entry back on the pasteboard and optionally pastes it.
@MainActor
enum ClipboardPaster {
    /// Writes the record's content to the pasteboard. Returns false if the
    /// content is gone (e.g. image file deleted).
    @discardableResult
    static func copy(_ record: ClipRecord, store: ClipboardStore, to pasteboard: NSPasteboard = .general) -> Bool {
        switch record.kind {
        case .text:
            guard let text = record.text else { return false }
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        case .image:
            guard let url = store.imageURL(for: record), let data = try? Data(contentsOf: url) else { return false }
            pasteboard.clearContents()
            pasteboard.setData(data, forType: .png)
        case .files:
            let existing = record.fileURLs.filter { FileManager.default.fileExists(atPath: $0.path) }
            guard !existing.isEmpty else { return false }
            pasteboard.clearContents()
            pasteboard.writeObjects(existing as [NSURL])
        }
        return true
    }

    /// Copies, then sends ⌘V to the frontmost app if Accessibility allows.
    /// The palette has just closed, so wait a moment for focus to settle.
    static func paste(_ record: ClipRecord, store: ClipboardStore, canPostKeys: Bool) {
        guard copy(record, store: store) else {
            HUD.show(L10n.Clipboard.itemGone, symbol: "exclamationmark.triangle")
            return
        }
        guard canPostKeys else {
            HUD.show(L10n.Clipboard.copiedPressToPaste, symbol: "doc.on.clipboard")
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            KeySender.paste()
        }
    }
}
