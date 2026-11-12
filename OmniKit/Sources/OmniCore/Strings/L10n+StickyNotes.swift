import Foundation

public extension L10n {
    /// Sticky Notes: feature text, note window, menus, settings.
    enum StickyNotes {
        public static var displayName: String { tr("stickynotes.displayName", "Sticky Notes") }
        public static var summary: String { tr("stickynotes.summary", "Glass notes on your desktop. Right-click the desktop or press ⌃⌥⌘N to add one.") }
        public static var hotkeyNew: String { tr("stickynotes.hotkey.new", "New sticky note") }
        public static var newNote: String { tr("stickynotes.new", "New Sticky Note") }
        public static var bringToFront: String { tr("stickynotes.bringToFront", "Bring Notes to Front") }
        public static var clickHint: String { tr("stickynotes.clickHint", "new note") }
        public static var untitled: String { tr("stickynotes.untitled", "Empty note") }
        public static var restoreDeleted: String { tr("stickynotes.restoreDeleted", "Restore Deleted Note") }
        public static var enableRightClick: String { tr("stickynotes.enableRightClick", "Add “New Sticky Note” to the Desktop’s Right-Click Menu…") }
        public static var placeholder: String { tr("stickynotes.placeholder", "Write a note…") }
        public static var keepOnTop: String { tr("stickynotes.keepOnTop", "Keep on Top") }
        public static var colorAndOptions: String { tr("stickynotes.colorAndOptions", "Color and options") }
        public static var deleteNote: String { tr("stickynotes.delete", "Delete note") }
        public static var deleted: String { tr("stickynotes.deleted", "Note deleted") }
        public static var undo: String { tr("stickynotes.undo", "Undo") }
        public static var tintYellow: String { tr("stickynotes.tint.yellow", "Yellow") }
        public static var tintOrange: String { tr("stickynotes.tint.orange", "Orange") }
        public static var tintPink: String { tr("stickynotes.tint.pink", "Pink") }
        public static var tintPurple: String { tr("stickynotes.tint.purple", "Purple") }
        public static var tintBlue: String { tr("stickynotes.tint.blue", "Blue") }
        public static var tintGreen: String { tr("stickynotes.tint.green", "Green") }
        public static var tintGray: String { tr("stickynotes.tint.gray", "Gray") }
        public static var defaultColor: String { tr("stickynotes.defaultColor", "Color of new notes") }
        public static var allSpaces: String { tr("stickynotes.allSpaces", "Show notes on every desktop (Space)") }
        public static var rightClickTitle: String { tr("stickynotes.rightClick", "“New Sticky Note” in the desktop’s right-click menu") }
        public static var rightClickOn: String { tr("stickynotes.rightClick.on", "On. Right-click an empty spot on the desktop.") }
        public static var rightClickOff: String {
            tr("stickynotes.rightClick.off", "Off. Turn on “Omni” under Finder in System Settings → General → Login Items & Extensions.")
        }
        public static var settingsNote: String {
            tr("stickynotes.settingsNote", "Notes sit on the desktop, behind your windows; use “Keep on Top” on a note to float it. Drag a note by its top edge and resize it from any edge. Notes are saved on this Mac only.")
        }
        public static func eraseDescription(_ count: Int) -> String {
            plural("stickynotes.erase", one: "%lld sticky note and the recently deleted ones", other: "all %lld sticky notes and the recently deleted ones", count)
        }
        /// Finder extension menu item.
        public static var finderMenuItem: String { tr("stickynotes.finderMenuItem", "New Sticky Note") }
    }
}
