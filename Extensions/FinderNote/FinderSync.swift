import AppKit
import FinderSync
import OmniCore

/// Omni's Finder extension: adds "New Sticky Note" to the right-click menu
/// of the desktop (and of Finder windows showing the Desktop folder). It's
/// sandboxed and only asks Omni, through `omni://note/new`, to create a note
/// where you clicked. It reads no files.
final class FinderSync: FIFinderSync {
    /// Where the right-click happened (AppKit global), captured when the menu opens.
    private var clickPoint = CGPoint.zero

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [Self.desktopURL]
    }

    /// The real ~/Desktop (inside the sandbox, the home folder is the container).
    static var desktopURL: URL {
        let home = getpwuid(getuid()).flatMap { String(validatingCString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home, isDirectory: true).appendingPathComponent("Desktop", isDirectory: true)
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer,
              let target = FIFinderSyncController.default().targetedURL(),
              target.standardizedFileURL.path == Self.desktopURL.standardizedFileURL.path else { return nil }
        clickPoint = NSEvent.mouseLocation
        let menu = NSMenu(title: "")
        let item = NSMenuItem(title: L10n.StickyNotes.finderMenuItem, action: #selector(newNote(_:)), keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: nil)
        menu.addItem(item)
        return menu
    }

    @objc private func newNote(_ sender: AnyObject?) {
        NSWorkspace.shared.open(NoteURL.make(at: clickPoint))
    }
}

/// `omni://note/new?x=…&y=…` (same format Omni's `NoteURL` parses).
private enum NoteURL {
    static func make(at point: CGPoint) -> URL {
        URL(string: "omni://note/new?x=\(Int(point.x))&y=\(Int(point.y))")! // l10n-ignore
    }
}
