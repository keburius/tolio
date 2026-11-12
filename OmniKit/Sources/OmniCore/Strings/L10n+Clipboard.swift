import Foundation

public extension L10n {
    /// Clipboard History: feature text, settings, menus and messages.
    enum Clipboard {
        public static var displayName: String { tr("clipboard.displayName", "Clipboard History") }
        public static var summary: String {
            tr("clipboard.summary", "Remembers what you copy so you can paste it again later.")
        }
        public static var showHotkey: String { tr("clipboard.hotkey.show", "Show clipboard history") }
        public static var commandShow: String { tr("clipboard.command.show", "Clipboard History") }
        public static var commandClear: String { tr("clipboard.command.clear", "Clear Clipboard History") }
        public static var commandClearSubtitle: String { tr("clipboard.command.clear.subtitle", "Keeps pinned items") }
        /// Section title in the Launcher.
        public static var searchTitle: String { tr("clipboard.search.title", "Clipboard") }
        public static var emptyHistory: String {
            tr("clipboard.empty", "Nothing copied yet. Copy something to see it here.")
        }
        public static func pinnedSubtitle(_ rest: String) -> String {
            format("clipboard.search.pinnedSubtitle", "Pinned · %@", rest)
        }

        // MARK: Items

        public static var whitespaceItem: String { tr("clipboard.item.whitespace", "(whitespace)") }
        public static var imageItem: String { tr("clipboard.item.image", "Image") }
        public static func imageItem(width: Int, height: Int) -> String {
            format("clipboard.item.imageSize", "Image %lld × %lld", width, height)
        }
        public static func moreFiles(_ names: String, _ more: Int) -> String {
            format("clipboard.item.moreFiles", "%@ +%lld", names, more)
        }

        // MARK: Messages

        public static var copied: String { tr("clipboard.hud.copied", "Copied") }
        public static var copiedPressToPaste: String { tr("clipboard.hud.copiedPressToPaste", "Copied. Press ⌘V to paste") }
        public static var itemGone: String { tr("clipboard.hud.itemGone", "That item is no longer available") }
        public static var clearedKeepingPinned: String {
            tr("clipboard.hud.clearedKeepingPinned", "Clipboard history cleared. Pinned items were kept.")
        }
        public static var cleared: String { tr("clipboard.hud.cleared", "Clipboard history cleared") }

        // MARK: Quick access

        public static var quickTitle: String { tr("clipboard.quick.title", "Clipboard") }
        public static var quickClickHint: String { tr("clipboard.quick.clickHint", "show history") }
        public static var menuShowHistory: String { tr("clipboard.menu.showHistory", "Show Clipboard History") }
        public static var menuSearchHistory: String { tr("clipboard.menu.searchHistory", "Search History…") }
        public static var pinnedHeader: String { tr("clipboard.menu.pinned", "Pinned") }
        public static var menuClearHistory: String { tr("clipboard.menu.clearHistory", "Clear History…") }
        public static func menuRecentItem(_ title: String, age: String) -> String {
            format("clipboard.menu.recentItem", "%1$@   %2$@", title, age)
        }
        public static var ageNow: String { tr("clipboard.age.now", "now") }
        public static func clearConfirmation(_ count: Int) -> String {
            plural(
                "clipboard.menu.clearConfirmation",
                one: "Delete %lld item from your clipboard history? Pinned items are kept.",
                other: "Delete %lld items from your clipboard history? Pinned items are kept.",
                count
            )
        }
        public static func eraseDescription(_ count: Int) -> String {
            plural(
                "clipboard.erase.description",
                one: "%lld clipboard item",
                other: "all %lld clipboard items, including pinned ones",
                count
            )
        }

        // MARK: Settings

        public static var keepUpTo: String { tr("clipboard.settings.keepUpTo", "Keep up to") }
        public static func itemCount(_ count: Int) -> String {
            plural("clipboard.settings.itemCount", one: "%lld item", other: "%lld items", count)
        }
        public static var deleteOlderThan: String { tr("clipboard.settings.deleteOlderThan", "Delete items older than") }
        public static var oneDay: String { tr("clipboard.settings.age.day", "1 day") }
        public static var oneWeek: String { tr("clipboard.settings.age.week", "1 week") }
        public static var oneMonth: String { tr("clipboard.settings.age.month", "1 month") }
        public static var threeMonths: String { tr("clipboard.settings.age.threeMonths", "3 months") }
        public static var oneYear: String { tr("clipboard.settings.age.year", "1 year") }
        public static var never: String { tr("clipboard.settings.age.never", "Never") }
        public static var retentionNote: String {
            tr("clipboard.settings.retentionNote", "Pinned items are never deleted automatically. Items marked secret by password managers are never stored.")
        }
        public static var history: String { tr("clipboard.settings.history", "History") }
        public static var searchHistory: String { tr("clipboard.settings.searchHistory", "Search history") }
        public static var clearHistory: String { tr("clipboard.settings.clearHistory", "Clear History…") }
        public static var clearQuestion: String { tr("clipboard.settings.clearQuestion", "Clear clipboard history?") }
        public static var clearKeepPinned: String { tr("clipboard.settings.clearKeepPinned", "Clear, Keep Pinned") }
        public static var clearEverything: String { tr("clipboard.settings.clearEverything", "Clear Everything") }
        public static var pin: String { tr("clipboard.settings.pin", "Pin") }
        public static var unpin: String { tr("clipboard.settings.unpin", "Unpin") }
        public static var copy: String { tr("clipboard.settings.copy", "Copy") }
        public static var delete: String { tr("clipboard.settings.delete", "Delete") }
        public static var neverRecordFrom: String { tr("clipboard.settings.neverRecordFrom", "Never record copies from") }
        public static var passwordManagerNote: String {
            tr("clipboard.settings.passwordManagerNote", "Password manager, always excluded")
        }
    }

    /// Text Snippets: feature text, settings, editor and errors.
    enum Snippets {
        public static var displayName: String { tr("snippets.displayName", "Text Snippets") }
        public static var summary: String {
            tr("snippets.summary", "Type a short code like ;sig in any app to insert text you use often.")
        }
        public static var commandInsert: String { tr("snippets.command.insert", "Insert Snippet") }
        /// Section title in the Launcher.
        public static var searchTitle: String { tr("snippets.search.title", "Snippet") }
        public static var gestureTitle: String { tr("snippets.gesture.title", "Insert a snippet") }
        public static var gestureHow: String { tr("snippets.gesture.how", "Type its code, like ;sig") }
        public static var defaultDateTitle: String { tr("snippets.default.date", "Today's date") }
        public static var defaultSignOffTitle: String { tr("snippets.default.signOff", "Email sign-off") }
        public static func eraseDescription(_ count: Int) -> String {
            plural("snippets.erase.description", one: "%lld snippet", other: "all %lld snippets", count)
        }

        // MARK: Settings

        public static var list: String { tr("snippets.settings.list", "Snippets") }
        public static var empty: String {
            tr("snippets.settings.empty", "No snippets yet. Add one, then type its code (like ;sig) in any app.")
        }
        public static var addSnippet: String { tr("snippets.settings.add", "Add Snippet") }
        public static var edit: String { tr("snippets.settings.edit", "Edit") }
        public static var delete: String { tr("snippets.settings.delete", "Delete") }
        public static func enabledToggle(_ title: String) -> String {
            format("snippets.settings.enabledToggle", "Use “%@”", title)
        }
        public static var placeholders: String { tr("snippets.settings.placeholders", "Placeholders") }
        public static var placeholdersHelp: String {
            tr("snippets.settings.placeholdersHelp", "Placeholders: {date}, {date:yyyy-MM-dd}, {time}, {time:HH:mm}, {clipboard}, {cursor}. Use {{ and }} for literal braces. Snippets never expand in password fields.")
        }

        // MARK: Editor

        public static var code: String { tr("snippets.editor.code", "Code") }
        public static var codePrompt: String { tr("snippets.editor.codePrompt", ";sig") }
        public static var title: String { tr("snippets.editor.title", "Title") }
        public static var save: String { tr("snippets.editor.save", "Save") }
        public static var tooShort: String { tr("snippets.problem.tooShort", "Use at least 2 characters.") }
        public static var noSpaces: String { tr("snippets.problem.noSpaces", "Codes can't contain spaces.") }
        public static func alreadyUsed(_ code: String) -> String {
            format("snippets.problem.alreadyUsed", "Another snippet already uses “%@”.", code)
        }
    }

    /// Text Actions: feature text, action titles, settings and messages.
    enum TextActions {
        public static var displayName: String { tr("textactions.displayName", "Text Actions") }
        public static var summary: String {
            tr("textactions.summary", "Select text in any app to copy, search, translate or change its case.")
        }

        // MARK: Actions

        public static var copy: String { tr("textactions.action.copy", "Copy") }
        public static var paste: String { tr("textactions.action.paste", "Paste") }
        public static var openLink: String { tr("textactions.action.openLink", "Open Link") }
        public static var searchWeb: String { tr("textactions.action.search", "Search the Web") }
        public static var translate: String { tr("textactions.action.translate", "Translate") }
        public static var uppercase: String { tr("textactions.action.uppercase", "UPPERCASE") }
        public static var lowercase: String { tr("textactions.action.lowercase", "lowercase") }
        public static var wordCount: String { tr("textactions.action.wordCount", "Word Count") }
        public static var sendToLauncher: String { tr("textactions.action.sendToLauncher", "Send to Launcher") }
        public static var copied: String { tr("textactions.message.copied", "Copied") }

        public static func words(_ count: Int) -> String {
            plural("textactions.count.words", one: "%lld word", other: "%lld words", count)
        }
        public static func characters(_ count: Int) -> String {
            plural("textactions.count.characters", one: "%lld character", other: "%lld characters", count)
        }
        public static func lines(_ count: Int) -> String {
            plural("textactions.count.lines", one: "%lld line", other: "%lld lines", count)
        }
        public static func countSummary(_ words: String, _ characters: String) -> String {
            format("textactions.count.summary", "%1$@, %2$@", words, characters)
        }
        public static func countSummary(_ words: String, _ characters: String, _ lines: String) -> String {
            format("textactions.count.summaryWithLines", "%1$@, %2$@, %3$@", words, characters, lines)
        }
        public static func eraseDescription(_ count: Int) -> String {
            plural(
                "textactions.erase.description",
                one: "%lld app from the “Never show in” list",
                other: "all %lld apps from the “Never show in” list",
                count
            )
        }

        // MARK: Settings

        public static var showAfter: String { tr("textactions.settings.showAfter", "Show the bar after") }
        public static var mouseTrigger: String {
            tr("textactions.settings.mouseTrigger", "Selecting with the mouse (drag, double-click, ⇧-click)")
        }
        public static var keyboardTrigger: String {
            tr("textactions.settings.keyboardTrigger", "Selecting with ⇧ and arrow keys")
        }
        public static var actions: String { tr("textactions.settings.actions", "Actions") }
        public static var searchWith: String { tr("textactions.settings.searchWith", "Search with") }
        public static var actionsNote: String {
            tr("textactions.settings.actionsNote", "Search, Open Link and Translate act only when you click them. Search and Open Link hand the text to your browser; Translate uses Apple's translation panel (the same as Translate in context menus).")
        }
        public static var readingSelection: String { tr("textactions.settings.readingSelection", "Reading the selection") }
        public static var copyBriefly: String {
            tr("textactions.settings.copyBriefly", "When an app doesn't share its selection, copy it briefly (⌘C) and put your clipboard back")
        }
        public static var copyBrieflyNote: String {
            tr("textactions.settings.copyBrieflyNote", "Needed for many apps, such as Slack, Discord and Chrome. Omni puts your previous clipboard back right away, and Clipboard History doesn't keep it. Never used in password fields, while macOS protects password entry, in password managers, or in Finder.")
        }
        public static var neverShowIn: String { tr("textactions.settings.neverShowIn", "Never show in") }
    }
}
