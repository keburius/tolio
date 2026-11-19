import Foundation

public extension L10n {
    /// Drop Ring (feature id `dropring`).
    enum DropRing {
        public static var displayName: String { tr("dropring.displayName", "Drop Ring") }
        public static var summary: String {
            tr("dropring.summary.short", "Drop files on a ring of folders, apps and people that opens around your pointer.")
        }
        public static var tagline: String { tr("dropring.tagline", "Drop files on folders, apps and people.") }
        public static var hotkey: String { tr("dropring.hotkey", "Show Drop Ring") }

        // Circle names and what a drop does (shown in the middle of the ring).
        public static var cargo: String { tr("dropring.item.cargo", "Cargo") }
        public static var trash: String { tr("dropring.item.trash", "Trash") }
        public static var messages: String { tr("dropring.channel.messages", "Messages") }
        public static var mail: String { tr("dropring.channel.mail", "Mail") }
        public static func copyTo(_ folder: String) -> String { format("dropring.action.copyTo", "Copy to %@", folder) }
        public static func moveTo(_ folder: String) -> String { format("dropring.action.moveTo", "Move to %@", folder) }
        public static func shareWith(_ app: String) -> String { format("dropring.action.shareWith", "Share with %@", app) }
        public static func pasteInto(_ app: String) -> String {
            format("dropring.done.pasteInto", "Copied. Press ⌘V in a %@ chat to send.", app)
        }
        public static func sendWith(_ app: String) -> String { format("dropring.action.sendWith", "Send with %@", app) }
        public static func openWith(_ app: String) -> String { format("dropring.action.openWith", "Open with %@", app) }
        public static func sendTo(_ person: String, _ channel: String) -> String {
            format("dropring.action.sendTo", "Send to %@ with %@", person, channel)
        }
        public static func run(_ shortcut: String) -> String { format("dropring.action.run", "Run “%@”", shortcut) }
        public static var addToCargo: String { tr("dropring.action.addToCargo", "Add to Cargo") }
        public static var moveToTrash: String { tr("dropring.action.moveToTrash", "Move to Trash") }
        public static var hint: String { tr("dropring.hint", "Drop files on a circle, or click one. Esc closes.") }
        public static var empty: String { tr("dropring.empty", "No circles yet. Add some in Settings → Drop Ring.") }

        // Notices after a drop.
        public static func items(_ count: Int) -> String {
            plural("dropring.items", one: "%lld item", other: "%lld items", count)
        }
        public static func copied(_ items: String, _ folder: String) -> String { format("dropring.done.copied", "Copied %@ to %@", items, folder) }
        public static func moved(_ items: String, _ folder: String) -> String { format("dropring.done.moved", "Moved %@ to %@", items, folder) }
        public static func trashed(_ items: String) -> String { format("dropring.done.trashed", "Moved %@ to the Trash", items) }
        public static func addedToCargo(_ items: String) -> String { format("dropring.done.cargo", "Added %@ to Cargo", items) }
        public static func failed(_ items: String) -> String { format("dropring.done.failed", "%@ couldn't be moved", items) }
        public static var alreadyThere: String { tr("dropring.done.alreadyThere", "Already in that folder") }
        public static func missing(_ name: String) -> String { format("dropring.missing", "“%@” can't be found", name) }

        // Cargo shelf.
        public static var cargoEmpty: String { tr("dropring.cargo.empty", "Drop files on the Cargo circle to collect them here.") }
        public static var dragAllOut: String { tr("dropring.cargo.dragAll", "Drag all out") }
        public static var clearCargo: String { tr("dropring.cargo.clear", "Clear") }
        public static var clearCargoHelp: String { tr("dropring.cargo.clearHelp", "Empties the shelf. Your files stay where they are.") }

        // Settings.
        public static var circles: String { tr("dropring.settings.circles", "Circles") }
        public static var circlesHelp: String { tr("dropring.settings.circlesHelp", "Drag rows to change the order. The first circle sits at the top of the ring.") }
        public static var addCircle: String { tr("dropring.settings.add", "Add Circle") }
        public static var addFolder: String { tr("dropring.settings.addFolder", "Folder…") }
        public static var addApp: String { tr("dropring.settings.addApp", "App…") }
        public static var addPerson: String { tr("dropring.settings.addPerson", "Person…") }
        public static var addShortcut: String { tr("dropring.settings.addShortcut", "Shortcut") }
        public static var copy: String { tr("dropring.settings.copy", "Copy") }
        public static var move: String { tr("dropring.settings.move", "Move") }
        public static var shake: String { tr("dropring.settings.shake", "Shake the pointer to open the ring") }
        public static var shakeOnlyDragging: String { tr("dropring.settings.shakeDragging", "Only while dragging files") }
        public static var sensitivity: String { tr("dropring.settings.sensitivity", "Shake sensitivity") }
        public static var bigShake: String { tr("dropring.settings.bigShake", "Big shake") }
        public static var smallWiggle: String { tr("dropring.settings.smallWiggle", "Small wiggle") }
        public static var size: String { tr("dropring.settings.size", "Circle size") }
        public static var style: String { tr("dropring.settings.style", "Look") }
        public static var glass: String { tr("dropring.settings.glass", "Glass") }
        public static var solid: String { tr("dropring.settings.solid", "Solid") }
        public static var resetCircles: String { tr("dropring.settings.resetCircles", "Reset Circles") }
        public static var personTitle: String { tr("dropring.person.title", "Add a person") }
        public static var personName: String { tr("dropring.person.name", "Name") }
        public static var personHandle: String { tr("dropring.person.handle", "Phone number or email") }
        public static var sendWith: String { tr("dropring.person.sendWith", "Send with") }
        public static var personHelp: String {
            tr("dropring.person.help", "Dropped files open in a new message or email to this person. Nothing is sent until you press Send.")
        }
        public static var loadingShortcuts: String { tr("dropring.shortcuts.loading", "Loading your shortcuts…") }
        public static var noShortcuts: String { tr("dropring.shortcuts.none", "No shortcuts found. Make one in the Shortcuts app.") }
        public static var shortcutsHelp: String { tr("dropring.shortcuts.help", "Dropped files are passed to the shortcut as input.") }
        public static var missingTag: String { tr("dropring.settings.missing", "Not found") }
        public static var tabOpeningLook: String { tr("dropring.settings.tab.opening", "Opening and look") }
        public static var moveUp: String { tr("dropring.settings.moveUp", "Move Up") }
        public static var moveDown: String { tr("dropring.settings.moveDown", "Move Down") }
        public static func removeCircle(_ name: String) -> String { format("dropring.settings.remove", "Remove %@", name) }
        public static func copyOrMove(_ name: String) -> String { format("dropring.settings.copyOrMove", "%@: copy or move", name) }
        public static var heroDescription: String {
            tr("dropring.settings.hero.a11y", "Example: seven circles open around the pointer while a file is dragged, with Desktop highlighted")
        }
    }
}
