import AppKit
import OmniCore

/// What an action can do besides reading the selection. Implemented by the
/// popup controller; a fake in tests.
@MainActor
public protocol TextActionContext {
    /// Replaces the selection in the app (Accessibility if possible, else a
    /// ⌘V that restores the clipboard).
    func replaceSelection(with text: String)
    /// A normal copy: it's the user's choice, so clipboard history may record it.
    func copyToClipboard(_ text: String)
    /// ⌘V of the current clipboard into the app.
    func pasteClipboard()
    func open(_ url: URL)
    func showMessage(_ text: String, symbol: String)
    func translate(_ text: String, replaceable: Bool)
    var searchEngine: SearchEngine { get }
}

/// A button in the selection popup. To add one, implement this and add it to
/// `TextActionCatalog.builtIn` (or register it from another module).
@MainActor
public protocol TextAction {
    var id: String { get }
    var title: String { get }
    var symbolName: String { get }
    func isAvailable(for selection: TextSelection) -> Bool
    func perform(_ selection: TextSelection, context: any TextActionContext)
}

public extension TextAction {
    func isAvailable(for selection: TextSelection) -> Bool { !selection.trimmed.isEmpty }
}

@MainActor
public enum TextActionCatalog {
    public static let builtIn: [any TextAction] = [
        CopyAction(), PasteAction(), OpenURLAction(), SearchWebAction(), TranslateAction(),
        UppercaseAction(), LowercaseAction(), WordCountAction(),
    ]

    public static func available(for selection: TextSelection, enabled: Set<String>? = nil) -> [any TextAction] {
        builtIn.filter { (enabled?.contains($0.id) ?? true) && $0.isAvailable(for: selection) }
    }
}

struct CopyAction: TextAction {
    let id = "copy", symbolName = "doc.on.doc"
    var title: String { L10n.TextActions.copy }
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        context.copyToClipboard(selection.text)
        context.showMessage(L10n.TextActions.copied, symbol: "doc.on.doc")
    }
}

struct PasteAction: TextAction {
    let id = "paste", symbolName = "clipboard"
    var title: String { L10n.TextActions.paste }
    /// Only where the selection can be replaced (or might be).
    func isAvailable(for selection: TextSelection) -> Bool { selection.isEditable != false }
    func perform(_ selection: TextSelection, context: any TextActionContext) { context.pasteClipboard() }
}

struct OpenURLAction: TextAction {
    let id = "openURL", symbolName = "safari"
    var title: String { L10n.TextActions.openLink }
    func isAvailable(for selection: TextSelection) -> Bool { TextAnalysis.webURL(in: selection.text) != nil }
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        if let url = TextAnalysis.webURL(in: selection.text) { context.open(url) }
    }
}

struct SearchWebAction: TextAction {
    let id = "search", symbolName = "magnifyingglass"
    var title: String { L10n.TextActions.searchWeb }
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        if let url = context.searchEngine.url(for: selection.text) { context.open(url) }
    }
}

struct TranslateAction: TextAction {
    let id = "translate", symbolName = "translate"
    var title: String { L10n.TextActions.translate }
    func isAvailable(for selection: TextSelection) -> Bool {
        // Apple's translation panel needs macOS 14.4 and some letters to work on.
        guard #available(macOS 14.4, *) else { return false }
        return selection.trimmed.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    }
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        context.translate(selection.text, replaceable: selection.isEditable == true)
    }
}

struct UppercaseAction: TextAction {
    let id = "uppercase", symbolName = "textformat.size.larger"
    var title: String { L10n.TextActions.uppercase }
    func isAvailable(for selection: TextSelection) -> Bool {
        selection.isEditable != false && TextAnalysis.uppercased(selection.text) != selection.text
    }
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        context.replaceSelection(with: TextAnalysis.uppercased(selection.text))
    }
}

struct LowercaseAction: TextAction {
    let id = "lowercase", symbolName = "textformat.size.smaller"
    var title: String { L10n.TextActions.lowercase }
    func isAvailable(for selection: TextSelection) -> Bool {
        selection.isEditable != false && TextAnalysis.lowercased(selection.text) != selection.text
    }
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        context.replaceSelection(with: TextAnalysis.lowercased(selection.text))
    }
}

struct WordCountAction: TextAction {
    let id = "count", symbolName = "number"
    var title: String { L10n.TextActions.wordCount }
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        let c = TextAnalysis.counts(selection.text)
        let words = L10n.TextActions.words(c.words)
        let chars = L10n.TextActions.characters(c.characters)
        let message = c.lines > 1
            ? L10n.TextActions.countSummary(words, chars, L10n.TextActions.lines(c.lines))
            : L10n.TextActions.countSummary(words, chars)
        context.showMessage(message, symbol: "number")
    }
}

