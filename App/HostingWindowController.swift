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

    /// - Parameter fullSizeContent: let SwiftUI lay out under the title bar
    ///   and manage the toolbar and safe areas itself. Required for
    ///   `NavigationSplitView`; without it SwiftUI's toolbar inset and scroll
    ///   edge effect are applied on top of AppKit's title bar, hiding the
    ///   first rows of the detail pane.
    init(title: String, size: NSSize, permissions: PermissionsManager, fullSizeContent: Bool = false, content: Content) {
        self.permissions = permissions
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        if fullSizeContent { style.insert(.fullSizeContentView) }
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        super.init()
        if fullSizeContent { window.toolbarStyle = .unified }
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
