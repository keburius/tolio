import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// What the overlay shows.
@MainActor
@Observable
final class SwitcherModel {
    var records: [WindowRecord] = []
    var selection = 0
    /// Bumped when a thumbnail arrives.
    var thumbnailRevision = 0
    @ObservationIgnored var thumbnail: (CGWindowID) -> CGImage? = { _ in nil }
    @ObservationIgnored var onClick: (Int) -> Void = { _ in }
}

/// Runs the switcher: builds the list, drives the state machine, shows the
/// overlay, and performs focus / close / quit.
@MainActor
final class SwitcherController {
    /// Quick ⌥Tab taps switch without flashing the overlay.
    static let showDelay: Duration = .milliseconds(120)

    private let catalog = WindowCatalog()
    private let tracker: FocusTracker
    private let thumbnails = ThumbnailProvider()
    private let options: () -> WindowListOptions
    private let wantsThumbnails: () -> Bool
    private var machine = SwitcherStateMachine()
    private let model = SwitcherModel()
    private var panel: NSPanel?
    private var thumbnailTask: Task<Void, Never>?
    private let log = Log.logger("switcher")

    init(tracker: FocusTracker, options: @escaping () -> WindowListOptions, wantsThumbnails: @escaping () -> Bool) {
        self.tracker = tracker
        self.options = options
        self.wantsThumbnails = wantsThumbnails
        model.thumbnail = { [weak self] id in self?.thumbnails.images[id] }
        model.onClick = { [weak self] index in self?.handle(.click(index)) }
    }

    var isOpen: Bool { machine.isActive }

    func begin(backward: Bool) {
        tracker.touchFocusedWindow()
        catalog.reload(options: options(), recency: tracker.recency.order)
        guard machine.begin(count: catalog.records.count, backward: backward) else {
            HUD.show(L10n.Switcher.noWindows, symbol: "macwindow")
            return
        }
        model.records = catalog.records
        model.selection = machine.selection
        thumbnails.forget(keeping: Set(catalog.records.map(\.id)))
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.showDelay)
            guard let self, self.machine.isActive else { return }
            self.showPanel()
        }
        if wantsThumbnails() {
            let ids = catalog.records.map(\.id)
            thumbnailTask = Task { @MainActor [weak self] in
                await self?.thumbnails.capture(ids) { self?.model.thumbnailRevision += 1 }
            }
        }
    }

    func handle(_ input: SwitcherStateMachine.Input) {
        for effect in machine.handle(input) { apply(effect) }
    }

    /// Windows for the palette ("win …"), ordered like the switcher.
    func currentWindows() -> [WindowRecord] {
        tracker.touchFocusedWindow()
        catalog.reload(options: options(), recency: tracker.recency.order)
        return catalog.records
    }

    func focus(_ record: WindowRecord) {
        let app = NSRunningApplication(processIdentifier: record.pid)
        if record.state == .hidden { app?.unhide() }
        if let window = catalog.handle(for: record.id), record.state != .otherSpace {
            window.focus()
        } else {
            // Not reachable via Accessibility (another Space): activate the app.
            app?.activate()
        }
        tracker.touch(record.id)
    }

    func close() {
        thumbnailTask?.cancel()
        hidePanel()
        panel = nil
        thumbnails.clear()
    }

    // MARK: - Effects

    private func apply(_ effect: SwitcherStateMachine.Effect) {
        switch effect {
        case let .select(index):
            model.selection = index
        case let .activate(index):
            finish()
            if catalog.records.indices.contains(index) { focus(catalog.records[index]) }
        case .cancel:
            finish()
        case let .quitApp(index):
            guard catalog.records.indices.contains(index) else { return }
            NSRunningApplication(processIdentifier: catalog.records[index].pid)?.terminate()
            reloadSoon(after: .milliseconds(600))
        case let .closeWindow(index):
            guard catalog.records.indices.contains(index) else { return }
            if catalog.handle(for: catalog.records[index].id)?.close() != true {
                HUD.show(L10n.Switcher.cantClose, symbol: "xmark.circle")
            }
            reloadSoon(after: .milliseconds(300))
        }
    }

    private func finish() {
        thumbnailTask?.cancel()
        thumbnailTask = nil
        hidePanel()
    }

    /// After quitting or closing, the list changes once the app reacts.
    private func reloadSoon(after delay: Duration) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, self.machine.isActive else { return }
            self.catalog.reload(options: self.options(), recency: self.tracker.recency.order)
            self.model.records = self.catalog.records
            self.handle(.listChanged(count: self.catalog.records.count))
            if self.machine.isActive { self.layoutPanel() }
        }
    }

    // MARK: - Panel

    private func showPanel() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        layoutPanel()
        panel.orderFrontRegardless()
    }

    private func hidePanel() {
        panel?.orderOut(nil)
    }

    private func layoutPanel() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        guard let screen = (NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main) else { return }
        let size = SwitcherView.size(for: model.records.count, maxSize: CGSize(
            width: screen.visibleFrame.width * 0.92, height: screen.visibleFrame.height * 0.85
        ))
        panel.setFrame(NSRect(
            x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.midY - size.height / 2,
            width: size.width, height: size.height
        ), display: true)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = NSHostingView(rootView: SwitcherView(model: model))
        return panel
    }
}
