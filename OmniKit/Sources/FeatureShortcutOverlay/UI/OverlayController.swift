import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Key focus only in pinned mode (for the filter field); in hold mode the
/// panel never takes the keyboard from the frontmost app.
final class OverlayPanel: NSPanel {
    var acceptsKey = false
    override var canBecomeKey: Bool { acceptsKey }
    override var canBecomeMain: Bool { false }
}

/// Shows the frontmost app's menu shortcuts and runs a clicked item.
@MainActor
final class OverlayController: NSObject, NSWindowDelegate {
    private let cache = MenuCache()
    private let model = OverlayModel()
    private var gesture = HoldGesture()
    private var panel: OverlayPanel?
    private var snapshot: MenuSnapshot?
    private var targetPID: pid_t?
    private var keyMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private let includeDisabled: () -> Bool
    private let log = Log.logger("shortcuts")

    init(includeDisabled: @escaping () -> Bool) {
        self.includeDisabled = includeDisabled
        super.init()
        model.onChoose = { [weak self] entry in self?.choose(entry) }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated { self?.appActivated(pid) }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated { if let pid { self?.cache.forget(pid) } }
        })
    }

    var isVisible: Bool { panel?.isVisible == true }

    // MARK: - Input

    func handle(_ event: ModifierTap.Event) {
        switch event {
        case let .gesture(input):
            for effect in gesture.handle(input) { apply(effect) }
        case .mouseDown:
            // Clicks inside the open overlay must not close it.
            if !gesture.isShowing {
                for effect in gesture.handle(.other) { apply(effect) }
            }
        }
    }

    func togglePinned() {
        if isVisible { hide() } else { present(mode: .pinned) }
    }

    private func apply(_ effect: HoldGesture.Effect) {
        switch effect {
        case let .checkAfter(delay):
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                self?.handle(.gesture(.tick(ProcessInfo.processInfo.systemUptime)))
            }
        case .prepare:
            if let pid = frontmostPID() { cache.refresh(pid, maxAge: 2) }
        case .show:
            if !isVisible { present(mode: .hold) }
        case .hide:
            if model.mode == .hold { hide() }
        }
    }

    // MARK: - Showing

    private func frontmostPID() -> pid_t? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        return app.processIdentifier
    }

    private func present(mode: OverlayModel.Mode) {
        guard let pid = frontmostPID(), let app = NSRunningApplication(processIdentifier: pid) else {
            gesture.reset()
            HUD.show("No app to show shortcuts for", symbol: "command")
            return
        }
        targetPID = pid
        model.mode = mode
        model.query = ""
        model.appName = app.localizedName ?? "App"
        model.appIcon = app.icon
        if let cached = cache.cached(pid) {
            show(cached)
        } else {
            snapshot = nil
            model.sections = []
            model.truncated = false
            model.status = .loading
        }
        cache.refresh(pid, maxAge: 2) { [weak self] fresh in
            guard let self, self.targetPID == pid, self.isVisible else { return }
            if let fresh {
                self.show(fresh)
            } else if self.model.sections.isEmpty {
                self.model.status = .unavailable
            }
        }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.acceptsKey = mode == .pinned
        layout(panel)
        if mode == .pinned {
            installKeyMonitor()
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func show(_ snapshot: MenuSnapshot) {
        self.snapshot = snapshot
        model.sections = ShortcutCatalog.sections(from: snapshot.menuBar, includeDisabled: includeDisabled())
        model.truncated = snapshot.truncated
        model.status = .ready
        log.debug("Read \(snapshot.itemCount) menu items in \(Int(snapshot.duration * 1000)) ms")
        if let panel, panel.isVisible { layout(panel) }
    }

    func hide() {
        gesture.reset()
        removeKeyMonitor()
        panel?.orderOut(nil)
        targetPID = nil
    }

    /// Releases everything; called on disable.
    func close() {
        hide()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
        panel?.delegate = nil
        panel?.contentView = nil
        panel = nil
        snapshot = nil
        cache.clear()
    }

    private func appActivated(_ pid: pid_t?) {
        guard isVisible, let pid, pid != targetPID, pid != ProcessInfo.processInfo.processIdentifier else { return }
        hide()
    }

    // MARK: - Running an item

    private func choose(_ entry: ShortcutEntry) {
        guard entry.isEnabled else {
            HUD.show("“\(entry.title)” isn't available right now", symbol: "nosign")
            return
        }
        guard let ref = entry.ref, let snapshot else { return }
        hide()
        let title = entry.title
        Task.detached(priority: .userInitiated) {
            let result = snapshot.press(ref)
            // A press that opens a sheet or dialog often reports
            // `cannotComplete` even though it worked.
            if result != .success && result != .cannotComplete {
                await MainActor.run { HUD.show("Couldn't run “\(title)”", symbol: "exclamationmark.triangle") }
            }
        }
    }

    // MARK: - Panel

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.delegate = self
        let host = NSHostingView(rootView: OverlayView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        return panel
    }

    /// Sizes the panel to its columns and centers it on the screen with the mouse.
    private func layout(_ panel: OverlayPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let padding = OverlayModel.padding
        let chrome = OverlayModel.titleBarHeight + padding * 2
        let maxWidth = visible.width - 80
        let maxContentHeight = visible.height - 80 - chrome
        let columnStride = OverlayModel.columnWidth + OverlayModel.columnSpacing
        model.maxColumns = max(1, Int((maxWidth - padding * 2 + OverlayModel.columnSpacing) / columnStride))
        model.rowsPerColumn = max(8, Int(maxContentHeight / OverlayModel.rowHeight))

        // Size for all sections (not the filtered ones) so filtering doesn't resize.
        let savedQuery = model.query
        model.query = ""
        let columns = model.columns
        model.query = savedQuery
        let tallest = columns.map { $0.map(OverlayModel.height(of:)).reduce(0, +) }.max() ?? 0
        let contentHeight = min(maxContentHeight, max(CGFloat(tallest), 140))
        let columnCount = CGFloat(max(columns.count, 2))
        let width = max(560, columnCount * OverlayModel.columnWidth + (columnCount - 1) * OverlayModel.columnSpacing + padding * 2)
        let height = contentHeight + chrome
        let frame = NSRect(x: visible.midX - width / 2, y: visible.midY - height / 2, width: width, height: height).integral
        panel.setFrame(frame, display: panel.isVisible)
    }

    func windowDidResignKey(_ notification: Notification) {
        if model.mode == .pinned { hide() }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            switch Int(event.keyCode) {
            case 53: // Escape
                self.hide()
                return nil
            case 36, 76: // Return, keypad Enter: run the only / first match
                if let first = self.model.visibleSections.first?.entries.first, !self.model.query.isEmpty {
                    self.choose(first)
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
