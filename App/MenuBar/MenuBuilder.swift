import AppKit
import OmniCore

/// Turns a feature's `MenuEntry` list into an NSMenu.
@MainActor
enum MenuBuilder {
    static func menu(_ entries: [MenuEntry], shortcuts: ShortcutLookup) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for entry in entries { menu.addItem(item(entry, shortcuts: shortcuts)) }
        return menu
    }

    static func item(_ entry: MenuEntry, shortcuts: ShortcutLookup) -> NSMenuItem {
        switch entry {
        case .separator:
            return .separator()
        case let .header(text):
            let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            item.isEnabled = false
            return item
        case let .submenu(title, entries):
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = menu(entries, shortcuts: shortcuts)
            return item
        case let .action(action):
            let item = ActionMenuItem(action.title) {
                if let question = action.confirmation, !confirm(question) { return }
                action.perform()
            }
            item.state = action.isChecked ? .on : .off
            item.isEnabled = action.isEnabled
            ShortcutLookup.apply(shortcuts.combo(for: action.shortcutID), to: item)
            return item
        }
    }

    /// A blocking yes/no question for destructive menu actions.
    static func confirm(_ question: String) -> Bool {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = question
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.Common.continue)
        alert.addButton(withTitle: L10n.Common.cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }
}

/// An `NSMenuItem` that runs a closure.
@MainActor
final class ActionMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(_ title: String, key: String = "", handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("Not used") }

    @objc private func run() { handler() }
}
