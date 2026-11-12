import AppKit
import Observation
import OmniCore
import OmniPlatform
import os
import SwiftUI

/// Clipboard history: records text, images, and file references; searchable
/// in the Launcher ("clip …" or ⌃⌥V); pin, delete, retention, exclusions.
/// UI metadata (menu, erase, settings search) is in `+UI.swift`.
@MainActor
@Observable
public final class ClipboardHistoryFeature: Feature {
    public static let showHotkey = HotkeyAction(
        id: "clipboard.show", title: L10n.Clipboard.showHotkey,
        defaultCombo: KeyCombo(keyCode: 9, modifiers: [.control, .option]) // ⌃⌥V
    )
    /// Every shortcut `enable` registers.
    public static let hotkeys = [showHotkey]

    static let maxItemsKey = SettingKey.feature("clipboard", "maxItems", default: 500)
    /// Days; 0 means keep forever.
    static let maxAgeDaysKey = SettingKey.feature("clipboard", "maxAgeDays", default: 30)
    static let excludedAppsKey = SettingKey.feature("clipboard", "excludedApps", default: Set<String>())

    public let id: FeatureID = "clipboard"
    public var displayName: String { L10n.Clipboard.displayName }
    public var summary: String { L10n.Clipboard.summary }
    public let symbolName = "doc.on.clipboard"
    public let requiredPermissions: Set<Permission> = []
    /// Only needed to paste directly; without it, items are copied.
    public let optionalPermissions: Set<Permission> = [.accessibility]
    public let isEnabledByDefault = true

    /// Bumped whenever the history changes, so views refresh.
    private(set) var revision = 0
    @ObservationIgnored private(set) var store: ClipboardStore?
    @ObservationIgnored private(set) var context: FeatureContext?
    @ObservationIgnored private var monitor: ClipboardMonitor?

    public init() {}

    public func enable(context: FeatureContext) throws {
        let store = try ClipboardStore(directory: AppPaths.applicationSupport().appendingPathComponent("clipboard"))
        self.store = store
        self.context = context
        let settings = context.settings

        let monitor = ClipboardMonitor(excludedApps: { settings.value(Self.excludedAppsKey) }) { [weak self] clip in
            self?.capture(clip)
        }
        monitor.start()
        self.monitor = monitor
        context.lifetime.add { monitor.stop() }

        prune()
        context.registerSearchProvider(ClipboardSearchProvider(feature: self))
        context.registerHotkey(Self.showHotkey) { [weak self] in self?.showHistory() }
        context.registerCommand(Command(
            id: "clipboard.show", title: L10n.Clipboard.commandShow, keywords: ["paste", "copy"], symbolName: symbolName
        ) { context.openPalette(query: Self.historyQuery) })
        context.registerCommand(Command(
            id: "clipboard.clear", title: L10n.Clipboard.commandClear, subtitle: L10n.Clipboard.commandClearSubtitle,
            symbolName: "trash"
        ) { [weak self] in self?.clear(keepPinned: true) })
    }

    /// Launcher query that searches the history.
    static let historyQuery = "clip "

    /// Shows the history list (a menu under the Clipboard icon, or at the
    /// pointer if the icon is hidden). Falls back to the Launcher search.
    func showHistory() {
        if QuickAccessCenter.showClickMenu?(.clipboard) == true { return }
        searchHistory()
    }

    /// Opens the history search in the Launcher.
    func searchHistory() {
        context?.openPalette(query: Self.historyQuery)
    }

    public func disable() {
        monitor = nil
        store = nil
        context = nil
    }

    public func makeSettingsView() -> AnyView {
        guard let context else { return AnyView(EmptyView()) }
        return AnyView(ClipboardSettingsView(feature: self, settings: context.settings))
    }

    // MARK: - Operations

    private func capture(_ clip: CapturedClip) {
        guard let store else { return }
        let log = context?.log
        Task.detached(priority: .utility) {
            do {
                try store.insert(clip, at: Date())
            } catch {
                log?.error("Could not store clipboard item: \(String(describing: error), privacy: .public)")
            }
            await MainActor.run { [weak self] in
                self?.prune()
            }
        }
    }

    func prune() {
        guard let store, let settings = context?.settings else { return }
        let days = settings.value(Self.maxAgeDaysKey)
        _ = try? store.prune(
            maxItems: settings.value(Self.maxItemsKey),
            maxAge: days > 0 ? TimeInterval(days) * 86_400 : nil,
            now: Date()
        )
        revision += 1
    }

    /// Newest first, pinned or not (recently copied lists).
    func newestRecords(limit: Int) -> [ClipRecord] {
        _ = revision
        guard let store else { return [] }
        return (try? store.newest(limit: limit)) ?? []
    }

    func records(matching query: String, limit: Int) -> [ClipRecord] {
        _ = revision
        guard let store else { return [] }
        return (try? store.search(query, limit: limit)) ?? []
    }

    func setPinned(_ pinned: Bool, _ record: ClipRecord) {
        guard let id = record.id else { return }
        try? store?.setPinned(pinned, id: id)
        revision += 1
    }

    func delete(_ record: ClipRecord) {
        guard let id = record.id else { return }
        try? store?.delete(id: id)
        revision += 1
    }

    func clear(keepPinned: Bool) {
        try? store?.deleteAll(keepPinned: keepPinned)
        revision += 1
        HUD.show(keepPinned ? L10n.Clipboard.clearedKeepingPinned : L10n.Clipboard.cleared, symbol: "trash")
    }

    func paste(_ record: ClipRecord) {
        guard let store else { return }
        let canPost = context?.permissions.state(of: .accessibility) == .granted
        ClipboardPaster.paste(record, store: store, canPostKeys: canPost)
    }

    func copy(_ record: ClipRecord) {
        guard let store else { return }
        if ClipboardPaster.copy(record, store: store) {
            HUD.show(L10n.Clipboard.copied, symbol: "doc.on.clipboard")
        }
    }
}
