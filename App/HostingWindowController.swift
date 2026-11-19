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
    private let onClose: (() -> Void)?

    /// - Parameter fullSizeContent: let SwiftUI lay out under the title bar
    ///   and manage the toolbar and safe areas itself. Required for
    ///   `NavigationSplitView`; without it SwiftUI's toolbar inset and scroll
    ///   edge effect are applied on top of AppKit's title bar, hiding the
    ///   first rows of the detail pane.
    init(
        title: String, size: NSSize, permissions: PermissionsManager, fullSizeContent: Bool = false,
        allSetChrome: Bool = false, resizable: Bool = true, content: Content, onClose: (() -> Void)? = nil
    ) {
        self.permissions = permissions
        self.onClose = onClose
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if resizable { style.insert(.resizable) }
        if fullSizeContent || allSetChrome { style.insert(.fullSizeContentView) }
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        super.init()
        if fullSizeContent { window.toolbarStyle = .unified }
        window.title = title
        if allSetChrome {
            // The All Set look: dark, no title bar, content under the traffic lights.
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(srgbRed: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255, alpha: 1)
            window.isMovableByWindowBackground = true
            let toolbar = NSToolbar(identifier: "allset.chrome")
            toolbar.showsBaselineSeparator = false
            window.toolbar = toolbar
            window.toolbarStyle = .unifiedCompact
        }
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
        onClose?()
        if isMonitoring {
            permissions.stopMonitoring()
            isMonitoring = false
        }
    }
}
