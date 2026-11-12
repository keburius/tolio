import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// A small action bar next to selected text in any app.
@MainActor
@Observable
public final class TextActionsFeature: Feature {
    static let mouseKey = SettingKey.feature("textactions", "mouseTrigger", default: true)
    static let keyboardKey = SettingKey.feature("textactions", "keyboardTrigger", default: true)
    static let fallbackKey = SettingKey.feature("textactions", "copyFallback", default: true)
    static let excludedKey = SettingKey.feature("textactions", "excludedApps", default: Set<String>())
    static let actionsKey = SettingKey.feature("textactions", "actions", default: Set(TextActionCatalog.builtIn.map(\.id)))
    static let engineKey = SettingKey.feature("textactions", "searchEngine", default: SearchEngine.google)

    public let id: FeatureID = "textactions"
    public var displayName: String { L10n.TextActions.displayName }
    public var summary: String { L10n.TextActions.summary }
    public let symbolName = "text.cursor"
    public let requiredPermissions: Set<Permission> = [.accessibility]

    @ObservationIgnored private var controller: PopupController?
    @ObservationIgnored private var tap: SelectionTap?
    @ObservationIgnored private(set) var settings: SettingsStore?

    public init() {}

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        let controller = PopupController(options: {
            PopupOptions(
                mouseTrigger: settings.value(Self.mouseKey),
                keyboardTrigger: settings.value(Self.keyboardKey),
                copyFallback: settings.value(Self.fallbackKey),
                excludedApps: settings.value(Self.excludedKey),
                enabledActions: settings.value(Self.actionsKey),
                searchEngine: settings.value(Self.engineKey)
            )
        }, openPalette: { context.openPalette(query: $0) })
        let tap = SelectionTap { [weak controller] event in controller?.handle(event) }
        try tap.start()
        self.controller = controller
        self.tap = tap
        context.lifetime.add {
            tap.stop()
            controller.close()
        }
    }

    public func disable() {
        controller = nil
        tap = nil
        settings = nil
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(TextActionsSettingsView(settings: settings))
    }
}

struct TextActionsSettingsView: View {
    let settings: SettingsStore

    var body: some View {
        Section(L10n.TextActions.showAfter) {
            Toggle(L10n.TextActions.mouseTrigger, isOn: settings.binding(TextActionsFeature.mouseKey))
                .settingsAnchor(TextActionsFeature.Anchor.mouseTrigger)
            Toggle(L10n.TextActions.keyboardTrigger, isOn: settings.binding(TextActionsFeature.keyboardKey))
                .settingsAnchor(TextActionsFeature.Anchor.keyboardTrigger)
        }
        Section(L10n.TextActions.actions) {
            ForEach(TextActionCatalog.builtIn, id: \.id) { action in
                Toggle(isOn: Binding(
                    get: { settings.value(TextActionsFeature.actionsKey).contains(action.id) },
                    set: { on in
                        var set = settings.value(TextActionsFeature.actionsKey)
                        if on { set.insert(action.id) } else { set.remove(action.id) }
                        settings.set(set, for: TextActionsFeature.actionsKey)
                    }
                )) { Label(action.title, systemImage: action.symbolName) }
                .settingsAnchor(TextActionsFeature.Anchor.action(action.id))
            }
            Picker(L10n.TextActions.searchWith, selection: settings.binding(TextActionsFeature.engineKey)) {
                ForEach(SearchEngine.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .settingsAnchor(TextActionsFeature.Anchor.searchEngine)
            Text(L10n.TextActions.actionsNote)
                .font(.caption).foregroundStyle(.secondary)
        }
        Section(L10n.TextActions.readingSelection) {
            Toggle(L10n.TextActions.copyBriefly, isOn: settings.binding(TextActionsFeature.fallbackKey))
                .settingsAnchor(TextActionsFeature.Anchor.copyFallback)
            Text(L10n.TextActions.copyBrieflyNote)
                .font(.caption).foregroundStyle(.secondary)
        }
        ExcludedAppsSection(settings: settings)
    }
}

private struct ExcludedAppsSection: View {
    let settings: SettingsStore

    var body: some View {
        Section(L10n.TextActions.neverShowIn) {
            let excluded = settings.value(TextActionsFeature.excludedKey)
            Text(L10n.Common.passwordManagersAlwaysExcluded).font(.caption).foregroundStyle(.secondary)
            if excluded.isEmpty {
                EmptyState(symbol: "app.dashed", message: L10n.Common.noAppsExcluded)
            }
            ForEach(excluded.sorted(), id: \.self) { bundleID in
                HStack {
                    Text(appName(bundleID))
                    Spacer()
                    Button(L10n.Common.remove) { settings.set(excluded.subtracting([bundleID]), for: TextActionsFeature.excludedKey) }
                        .buttonStyle(.borderless)
                }
            }
            Menu(L10n.Common.addApp) {
                ForEach(runningApps(excluding: excluded), id: \.0) { id, name in
                    Button(name) { settings.set(excluded.union([id]), for: TextActionsFeature.excludedKey) }
                }
            }
            .fixedSize()
            .settingsAnchor(TextActionsFeature.Anchor.excludedApps)
        }
    }

    private func appName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path)
    }

    private func runningApps(excluding excluded: Set<String>) -> [(String, String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (String, String)? in
                guard let id = app.bundleIdentifier, !excluded.contains(id), !KnownApps.passwordManagers.contains(id) else { return nil }
                return (id, app.localizedName ?? id)
            }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }
}
