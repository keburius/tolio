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
    public let displayName = "Text Selection Popup"
    public let summary = "Select text in any app to get a small bar with copy, search, translate, case changes and more."
    public let symbolName = "text.cursor"
    public let requiredPermissions: Set<Permission> = [.accessibility]

    @ObservationIgnored private var controller: PopupController?
    @ObservationIgnored private var tap: SelectionTap?
    @ObservationIgnored private var settings: SettingsStore?

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
        Section("Show the bar after") {
            Toggle("Selecting with the mouse (drag, double-click, ⇧-click)", isOn: settings.binding(TextActionsFeature.mouseKey))
            Toggle("Selecting with ⇧ and arrow keys", isOn: settings.binding(TextActionsFeature.keyboardKey))
        }
        Section("Actions") {
            ForEach(TextActionCatalog.builtIn, id: \.id) { action in
                Toggle(isOn: Binding(
                    get: { settings.value(TextActionsFeature.actionsKey).contains(action.id) },
                    set: { on in
                        var set = settings.value(TextActionsFeature.actionsKey)
                        if on { set.insert(action.id) } else { set.remove(action.id) }
                        settings.set(set, for: TextActionsFeature.actionsKey)
                    }
                )) { Label(action.title, systemImage: action.symbolName) }
            }
            Picker("Search with", selection: settings.binding(TextActionsFeature.engineKey)) {
                ForEach(SearchEngine.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Text("Search, Open Link and Translate act only when you click them. Search and Open Link hand the text to your browser; Translate uses Apple's translation panel (the same as Translate in context menus).")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Reading the selection") {
            Toggle("When an app doesn't share its selection, copy it briefly (⌘C) and restore the clipboard", isOn: settings.binding(TextActionsFeature.fallbackKey))
            Text("Needed for most Electron and Chromium apps. Omni puts your previous clipboard back right away, and clipboard history never records it. Never used in password fields, while macOS protects password entry, in password managers, or in Finder.")
                .font(.caption).foregroundStyle(.secondary)
        }
        ExcludedAppsSection(settings: settings)
    }
}

private struct ExcludedAppsSection: View {
    let settings: SettingsStore

    var body: some View {
        Section("Never show in") {
            let excluded = settings.value(TextActionsFeature.excludedKey)
            Text("Password managers are always excluded.").font(.caption).foregroundStyle(.secondary)
            ForEach(excluded.sorted(), id: \.self) { bundleID in
                HStack {
                    Text(appName(bundleID))
                    Spacer()
                    Button("Remove") { settings.set(excluded.subtracting([bundleID]), for: TextActionsFeature.excludedKey) }
                        .buttonStyle(.borderless)
                }
            }
            Menu("Add App") {
                ForEach(runningApps(excluding: excluded), id: \.0) { id, name in
                    Button(name) { settings.set(excluded.union([id]), for: TextActionsFeature.excludedKey) }
                }
            }
            .fixedSize()
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
