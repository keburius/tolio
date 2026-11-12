import AppKit
import OmniPlatform
import SwiftUI

/// A standard window hosting a SwiftUI view. Polls permission states only
/// while the window is open, so permission UI stays current without a
/// background timer.
@MainActor
final class HostingWindowController<Content: View>: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let permissions: PermissionsManager
    private var isMonitoring = false

    init(title: String, size: NSSize, permissions: PermissionsManager, content: Content) {
        self.permissions = permissions
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content)
        window.setContentSize(size)
        window.delegate = self
        window.center()
    }

    func show() {
        if !isMonitoring {
            permissions.startMonitoring()
            isMonitoring = true
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        if isMonitoring {
            permissions.stopMonitoring()
            isMonitoring = false
        }
    }
}
