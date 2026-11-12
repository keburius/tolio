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
    func openPalette(query: String)
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
        UppercaseAction(), LowercaseAction(), WordCountAction(), SendToPaletteAction(),
    ]

    public static func available(for selection: TextSelection, enabled: Set<String>? = nil) -> [any TextAction] {
        builtIn.filter { (enabled?.contains($0.id) ?? true) && $0.isAvailable(for: selection) }
    }
}

struct CopyAction: TextAction {
    let id = "copy", title = "Copy", symbolName = "doc.on.doc"
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        context.copyToClipboard(selection.text)
        context.showMessage("Copied", symbol: "doc.on.doc")
    }
}

struct PasteAction: TextAction {
    let id = "paste", title = "Paste", symbolName = "clipboard"
    /// Only where the selection can be replaced (or might be).
    func isAvailable(for selection: TextSelection) -> Bool { selection.isEditable != false }
    func perform(_ selection: TextSelection, context: any TextActionContext) { context.pasteClipboard() }
}

struct OpenURLAction: TextAction {
    let id = "openURL", title = "Open Link", symbolName = "safari"
    func isAvailable(for selection: TextSelection) -> Bool { TextAnalysis.webURL(in: selection.text) != nil }
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        if let url = TextAnalysis.webURL(in: selection.text) { context.open(url) }
    }
}

struct SearchWebAction: TextAction {
    let id = "search", title = "Search the Web", symbolName = "magnifyingglass"
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        if let url = context.searchEngine.url(for: selection.text) { context.open(url) }
    }
}

struct TranslateAction: TextAction {
    let id = "translate", title = "Translate", symbolName = "translate"
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
    let id = "uppercase", title = "UPPERCASE", symbolName = "textformat.size.larger"
    func isAvailable(for selection: TextSelection) -> Bool {
        selection.isEditable != false && TextAnalysis.uppercased(selection.text) != selection.text
    }
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        context.replaceSelection(with: TextAnalysis.uppercased(selection.text))
    }
}

struct LowercaseAction: TextAction {
    let id = "lowercase", title = "lowercase", symbolName = "textformat.size.smaller"
    func isAvailable(for selection: TextSelection) -> Bool {
        selection.isEditable != false && TextAnalysis.lowercased(selection.text) != selection.text
    }
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        context.replaceSelection(with: TextAnalysis.lowercased(selection.text))
    }
}

struct WordCountAction: TextAction {
    let id = "count", title = "Word Count", symbolName = "number"
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        let c = TextAnalysis.counts(selection.text)
        let words = c.words == 1 ? "1 word" : "\(c.words) words"
        let chars = c.characters == 1 ? "1 character" : "\(c.characters) characters"
        let lines = c.lines > 1 ? ", \(c.lines) lines" : ""
        context.showMessage("\(words), \(chars)\(lines)", symbol: "number")
    }
}

struct SendToPaletteAction: TextAction {
    let id = "palette", title = "Send to Palette", symbolName = "command"
    /// The palette is a one-line field.
    func isAvailable(for selection: TextSelection) -> Bool {
        !selection.trimmed.isEmpty && selection.trimmed.count <= 500
    }
    func perform(_ selection: TextSelection, context: any TextActionContext) {
        let oneLine = selection.trimmed.components(separatedBy: .newlines).joined(separator: " ")
        context.openPalette(query: oneLine)
    }
}
