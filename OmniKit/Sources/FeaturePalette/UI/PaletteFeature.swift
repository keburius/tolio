import AppKit
import Observation
import OmniCore
import OmniPlatform
import os
import SwiftUI

/// Launcher: apps, System Settings panes, every feature's commands, plus
/// inline calculator, unit, and currency conversion.
@MainActor
@Observable
public final class PaletteFeature: Feature {
    public static let toggleHotkey = HotkeyAction(
        id: "palette.toggle",
        title: "Open command palette",
        defaultCombo: KeyCombo(keyCode: 49, modifiers: [.control, .option]) // ⌃⌥Space
    )
    /// Command id other parts of the app (e.g. the omni:// URL) use to open the palette.
    public static let showCommandID = "palette.show"

    static let currencyFetchKey = SettingKey.feature("palette", "currencyFetch", default: true)
    static let defaultCurrencyKey = SettingKey.feature(
        "palette", "defaultCurrency", default: Locale.current.currency?.identifier ?? "USD"
    )
    static let usageKey = SettingKey.feature("palette", "usage", default: UsageHistory())

    public let id: FeatureID = "palette"
    public let displayName = "Command Palette"
    public let summary = "Launch apps, open settings, run commands, calculate, and convert units and currencies."
    public let symbolName = "magnifyingglass"
    public let requiredPermissions: Set<Permission> = []
    public let isEnabledByDefault = true

    private(set) var appCount = 0
    /// ECB first, then NBG (see `QuickAnswerEngine.rateTables`).
    private(set) var rateStores: [CurrencyRateStore] = []
    private(set) var lastOpenMilliseconds: Double?

    @ObservationIgnored private var context: FeatureContext?
    @ObservationIgnored private var controller: PaletteController?
    @ObservationIgnored private var staticItems: [PaletteItem] = []
    @ObservationIgnored private var scanGeneration = 0

    public init() {}

    public func enable(context: FeatureContext) throws {
        self.context = context
        let support = try? AppPaths.applicationSupport()
        rateStores = [RateSource.ecb, .nbg].map { source in
            CurrencyRateStore(source: source, cacheURL: support?.appendingPathComponent(source.cacheFileName))
        }

        let model = PaletteViewModel(sources: PaletteSources(
            staticItems: { [weak self] in self?.staticItems ?? [] },
            commandItems: { [weak self] in self?.commandItems() ?? [] },
            answers: { [weak self] query in self?.answerEngine().answers(for: query) ?? [] },
            usage: { context.settings.value(Self.usageKey) },
            providers: { context.searchProviders }
        ))
        let controller = PaletteController(model: model) { [weak self] item, alternate in
            self?.perform(item, alternate: alternate)
        }
        self.controller = controller

        rebuildIndex()
        let watcher = DirectoryWatcher(
            paths: AppScanner.standardRoots.map(\.path).filter { FileManager.default.fileExists(atPath: $0) }
        ) { [weak self] in self?.rebuildIndex() }
        watcher.start()

        context.lifetime.add { [weak self] in
            watcher.stop()
            controller.close()
            self?.controller = nil
        }
        context.registerHotkey(Self.toggleHotkey) { [weak self] in self?.toggle(startedAt: .now) }
        context.setPaletteHandler { [weak self] query in self?.show(startedAt: .now, query: query) }
        context.registerCommand(Command(
            id: Self.showCommandID, title: "Open Command Palette", symbolName: symbolName
        ) { [weak self] in self?.show(startedAt: .now) })
    }

    public func disable() {
        context = nil
        rateStores = []
        staticItems = []
        appCount = 0
    }

    public func makeSettingsView() -> AnyView {
        guard let context else { return AnyView(EmptyView()) }
        return AnyView(PaletteSettingsView(feature: self, settings: context.settings))
    }

    // MARK: - Opening

    func toggle(startedAt: ContinuousClock.Instant) {
        if controller?.isVisible == true {
            controller?.hide()
        } else {
            show(startedAt: startedAt)
        }
    }

    func show(startedAt: ContinuousClock.Instant, query: String = "") {
        guard let controller else { return }
        if context?.settings.value(Self.currencyFetchKey) == true {
            for store in rateStores { store.refreshIfNeeded() }
        }
        controller.show(startedAt: startedAt, query: query)
        lastOpenMilliseconds = controller.lastOpenDuration?.milliseconds
    }

    // MARK: - Items

    /// Rescans apps and Settings panes off the main thread.
    func rebuildIndex() {
        scanGeneration += 1
        let generation = scanGeneration
        Task.detached(priority: .utility) {
            let apps = AppScanner.scan(roots: AppScanner.standardRoots, extras: AppScanner.extraApps)
            let panes = SettingsPaneCatalog.available()
            await MainActor.run { [weak self] in
                guard let self, self.context != nil, generation == self.scanGeneration else { return }
                self.staticItems = Self.items(apps: apps, panes: panes)
                self.appCount = apps.count
            }
        }
    }

    static func items(apps: [AppEntry], panes: [SettingsPane]) -> [PaletteItem] {
        let settingsIcon = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        let appItems = apps.map { app in
            PaletteItem(
                id: "app:\(app.bundleID ?? app.url.path)", title: app.name,
                subtitle: (app.url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath,
                icon: .file(app.url), kind: .app, action: .launchApp(app.url)
            )
        }
        let paneItems = panes.map { pane in
            PaletteItem(
                id: "setting:\(pane.url.absoluteString)", title: pane.title, subtitle: "System Settings",
                icon: .file(settingsIcon), kind: .setting, keywords: pane.keywords, action: .openURL(pane.url)
            )
        }
        return appItems + paneItems
    }

    private func commandItems() -> [PaletteItem] {
        (context?.availableCommands ?? [])
            .filter { !$0.id.hasPrefix("palette.") }
            .map { command in
                PaletteItem(
                    id: "command:\(command.id)", title: command.title, subtitle: command.subtitle,
                    icon: .symbol(command.symbolName), kind: .command, keywords: command.keywords,
                    action: .command(command)
                )
            }
    }

    private func answerEngine() -> QuickAnswerEngine {
        QuickAnswerEngine(
            rateTables: rateStores.compactMap(\.rates),
            defaultCurrency: context?.settings.value(Self.defaultCurrencyKey) ?? "USD",
            currencyFetchEnabled: context?.settings.value(Self.currencyFetchKey) ?? false
        )
    }

    // MARK: - Actions

    /// Runs an item. `alternate` (⌘↩) reveals apps in Finder instead of opening them.
    private func perform(_ item: PaletteItem, alternate: Bool) {
        let log = context?.log
        switch item.action {
        case let .launchApp(url):
            if alternate {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                    if let error { log?.error("Launch failed: \(error.localizedDescription, privacy: .public)") }
                }
            }
        case let .openURL(url):
            NSWorkspace.shared.open(url)
        case let .command(command):
            command.action()
        case let .copy(text):
            guard !text.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            HUD.show("Copied \(text)", symbol: "doc.on.clipboard")
        case let .provided(primary, alternateAction):
            if alternate, let alternateAction {
                alternateAction()
            } else {
                primary()
            }
        }
        if item.kind != .answer && item.kind != .provided { recordUse(item.id) }
    }

    private func recordUse(_ id: String) {
        guard let settings = context?.settings else { return }
        var usage = settings.value(Self.usageKey)
        usage.record(id, at: Date())
        settings.set(usage, for: Self.usageKey)
    }

    func clearUsage() {
        context?.settings.reset(Self.usageKey)
    }
}
