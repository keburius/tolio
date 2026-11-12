import AppKit

/// The menu bar icon and its menu.
@MainActor
final class StatusItemController {
    private let item: NSStatusItem

    init(onSettings: @escaping @MainActor () -> Void, onOnboarding: @escaping @MainActor () -> Void) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.grid.3x3.square", accessibilityDescription: "Omni")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(ActionMenuItem("Settings…", key: ",", handler: onSettings))
        menu.addItem(ActionMenuItem("Setup Guide…", handler: onOnboarding))
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("About Omni") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        menu.addItem(ActionMenuItem("Quit Omni", key: "q") { NSApp.terminate(nil) })
        item.menu = menu
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
