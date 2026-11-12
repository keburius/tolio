import AppKit
import Observation
import OmniCore
import OmniPlatform
import os
import SwiftUI

/// Clipboard history: records text, images, and file references; searchable
/// in the palette ("clip …" or ⌃⌥V); pin, delete, retention, exclusions.
@MainActor
@Observable
public final class ClipboardHistoryFeature: Feature {
    public static let showHotkey = HotkeyAction(
        id: "clipboard.show", title: "Show clipboard history",
        defaultCombo: KeyCombo(keyCode: 9, modifiers: [.control, .option]) // ⌃⌥V
    )

    static let maxItemsKey = SettingKey.feature("clipboard", "maxItems", default: 500)
    /// Days; 0 means keep forever.
    static let maxAgeDaysKey = SettingKey.feature("clipboard", "maxAgeDays", default: 30)
    static let excludedAppsKey = SettingKey.feature("clipboard", "excludedApps", default: Set<String>())

    public let id: FeatureID = "clipboard"
    public let displayName = "Clipboard History"
    public let summary = "Keeps text, images, and files you copy. Search it from the palette with “clip”."
    public let symbolName = "doc.on.clipboard"
    public let requiredPermissions: Set<Permission> = []
    /// Only needed to paste directly; without it, items are copied.
    public let optionalPermissions: Set<Permission> = [.accessibility]
    public let isEnabledByDefault = true

    /// Bumped whenever the history changes, so views refresh.
    private(set) var revision = 0
    @ObservationIgnored private(set) var store: ClipboardStore?
    @ObservationIgnored private var context: FeatureContext?
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
        context.registerHotkey(Self.showHotkey) { context.openPalette(query: "clip ") }
        context.registerCommand(Command(
            id: "clipboard.show", title: "Clipboard History", keywords: ["paste", "copy"], symbolName: symbolName
        ) { context.openPalette(query: "clip ") })
        context.registerCommand(Command(
            id: "clipboard.clear", title: "Clear Clipboard History", subtitle: "Keeps pinned items",
            symbolName: "trash"
        ) { [weak self] in self?.clear(keepPinned: true) })
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
        HUD.show(keepPinned ? "Clipboard history cleared (pinned kept)" : "Clipboard history cleared", symbol: "trash")
    }

    func paste(_ record: ClipRecord) {
        guard let store else { return }
        let canPost = context?.permissions.state(of: .accessibility) == .granted
        ClipboardPaster.paste(record, store: store, canPostKeys: canPost)
    }

    func copy(_ record: ClipRecord) {
        guard let store else { return }
        if ClipboardPaster.copy(record, store: store) {
            HUD.show("Copied", symbol: "doc.on.clipboard")
        }
    }
}

/// Palette results for "clip …".
@MainActor
final class ClipboardSearchProvider: SearchProvider {
    let keyword = "clip"
    let title = "Clipboard"
    private weak var feature: ClipboardHistoryFeature?
    private let relative = RelativeDateTimeFormatter()

    init(feature: ClipboardHistoryFeature) {
        self.feature = feature
        relative.unitsStyle = .short
    }

    func results(for query: String, limit: Int) -> [SearchResult] {
        guard let feature, let store = feature.store else { return [] }
        return feature.records(matching: query, limit: limit).map { record in
            let icon: SearchResult.Icon = switch record.kind {
            case .text: .symbol("text.alignleft")
            case .image: store.thumbnailURL(for: record).map { .image($0) } ?? .symbol("photo")
            case .files: record.fileURLs.first.map { .file($0) } ?? .symbol("doc")
            }
            var subtitle = [record.sourceAppName, relative.localizedString(for: record.createdAt, relativeTo: Date())]
                .compactMap { $0 }.joined(separator: " · ")
            if record.pinned { subtitle = "Pinned · " + subtitle }
            return SearchResult(
                id: "\(record.id ?? 0)", title: record.title, subtitle: subtitle, icon: icon,
                primaryAction: { [weak feature] in feature?.paste(record) },
                alternateAction: { [weak feature] in feature?.copy(record) }
            )
        }
    }
}
