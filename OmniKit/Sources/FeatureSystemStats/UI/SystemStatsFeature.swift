import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// CPU, memory, disk, network, and battery in the menu bar, with a detail
/// popover. One timer, running only while the feature is on.
///
/// Temperatures and fan speeds are deliberately not shown: on Apple silicon
/// they're only reachable through undocumented, chip-specific SMC/HID keys.
@MainActor
@Observable
public final class SystemStatsFeature: Feature {
    static let itemsKey = SettingKey.feature("systemstats", "items", default: Set<StatItem>([.cpu, .memory, .network]))
    static let intervalKey = SettingKey.feature("systemstats", "interval", default: 2.0)

    public let id: FeatureID = "systemstats"
    public let displayName = "System Stats"
    public let summary = "CPU, memory, disk, network, and battery in the menu bar."
    public let symbolName = "gauge.with.dots.needle.33percent"
    public let requiredPermissions: Set<Permission> = []

    private(set) var snapshot = StatsSnapshot()
    @ObservationIgnored private let sampler = SystemSampler()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var statusItem: NSStatusItem?
    @ObservationIgnored private var popover: NSPopover?
    @ObservationIgnored private var settings: SettingsStore?
    @ObservationIgnored private var lastTitle = ""
    @ObservationIgnored private var lastItems: Set<StatItem> = []

    public init() {}

    public func enable(context: FeatureContext) throws {
        settings = context.settings
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StatsPopoverView(feature: self))
        self.popover = popover

        sampler.reset()
        tick()
        restartTimer()
        context.lifetime.add { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
            self?.popover?.close()
            if let item = self?.statusItem { NSStatusBar.system.removeStatusItem(item) }
            self?.statusItem = nil
        }
    }

    public func disable() {
        settings = nil
        popover = nil
        lastTitle = ""
        lastItems = []
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(SystemStatsSettingsView(feature: self, settings: settings))
    }

    /// One repeating timer at the chosen interval (with tolerance so macOS can coalesce wakeups).
    func restartTimer() {
        timer?.invalidate()
        let interval = settings?.value(Self.intervalKey) ?? 2
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = interval * 0.25
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refreshTitle() {
        let items = settings?.value(Self.itemsKey) ?? []
        var title = snapshot.menuBarText(items: items)
        if title.isEmpty { title = "" }
        guard title != lastTitle, let item = statusItem, let button = item.button else { return }
        let layoutChanged = title.isEmpty != lastTitle.isEmpty || items != lastItems
        lastTitle = title
        if layoutChanged {
            lastItems = items
            if title.isEmpty {
                item.length = NSStatusItem.squareLength
                button.title = ""
                button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: "System Stats")
            } else {
                button.image = nil
                // Fixed width from the widest possible text, so neighboring
                // menu bar icons don't jump around as the numbers change.
                let font = button.font ?? .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
                let widest = StatsSnapshot.widestMenuBarText(items: items) as NSString
                item.length = ceil(widest.size(withAttributes: [.font: font]).width) + 12
            }
        }
        if !title.isEmpty { button.title = title }
    }

    private func tick() {
        snapshot = sampler.sample()
        refreshTitle()
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
