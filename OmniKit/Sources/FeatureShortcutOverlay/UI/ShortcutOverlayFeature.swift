import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Shows the frontmost app's keyboard shortcuts, read from its menu bar.
@MainActor
@Observable
public final class ShortcutOverlayFeature: Feature {
    static let triggerKey = SettingKey.feature("shortcuts", "trigger", default: OverlayTrigger.command)
    static let includeDisabledKey = SettingKey.feature("shortcuts", "includeDisabled", default: true)

    public static let showHotkey = HotkeyAction(
        id: "shortcuts.show", title: L10n.Cheatsheet.showTitle,
        defaultCombo: KeyCombo(keyCode: 44, modifiers: [.control, .option, .command]) // ⌃⌥⌘/
    )

    public let id: FeatureID = "shortcuts"
    public var displayName: String { L10n.Cheatsheet.name }
    public var summary: String { L10n.Cheatsheet.summary }
    public let symbolName = "command.square"
    public let requiredPermissions: Set<Permission> = [.accessibility]

    private(set) var tapError: String?
    @ObservationIgnored private var controller: OverlayController?
    @ObservationIgnored private var tap: ModifierTap?
    @ObservationIgnored private(set) var settings: SettingsStore?

    public init() {}

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        let controller = OverlayController(includeDisabled: { settings.value(Self.includeDisabledKey) })
        self.controller = controller
        try applyTrigger()
        context.lifetime.add { [weak self] in
            self?.tap?.stop()
            self?.tap = nil
            controller.close()
        }
        context.registerHotkey(Self.showHotkey) { controller.togglePinned() }
        context.registerCommand(Command(
            id: "shortcuts.show", title: L10n.Cheatsheet.showTitle, subtitle: L10n.Cheatsheet.showSubtitle,
            keywords: ["cheatsheet", "keys", "menu", "hotkeys"], symbolName: symbolName
        ) {
            // Let the palette close first so it doesn't take the key focus back.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                controller.togglePinned()
            }
        })
    }

    public func disable() {
        controller = nil
        settings = nil
        tapError = nil
    }

    /// Runs the modifier listener only while a double-press trigger is chosen.
    func applyTrigger() throws {
        guard let settings, let controller else { return }
        let trigger = settings.value(Self.triggerKey)
        if trigger == .off {
            tap?.stop()
            tap = nil
            return
        }
        guard tap == nil else { return }
        let tap = ModifierTap(trigger: { settings.value(Self.triggerKey) }) { [weak controller] event in
            controller?.handle(event)
        }
        do {
            try tap.start()
            self.tap = tap
            tapError = nil
        } catch {
            tapError = L10n.Cheatsheet.cannotWatchKeys
            throw error
        }
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(ShortcutOverlaySettingsView(feature: self, settings: settings))
    }
}

struct ShortcutOverlaySettingsView: View {
    let feature: ShortcutOverlayFeature
    let settings: SettingsStore

    var body: some View {
        Picker(L10n.Cheatsheet.openWith, selection: Binding(
            get: { settings.value(ShortcutOverlayFeature.triggerKey) },
            set: { settings.set($0, for: ShortcutOverlayFeature.triggerKey); try? feature.applyTrigger() }
        )) {
            ForEach(OverlayTrigger.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .settingsAnchor(ShortcutOverlayAnchor.trigger)
        Text(L10n.Cheatsheet.openWithHelp)
            .font(.caption).foregroundStyle(.secondary)
        Toggle(L10n.Cheatsheet.includeDisabled, isOn: settings.binding(ShortcutOverlayFeature.includeDisabledKey))
            .settingsAnchor(ShortcutOverlayAnchor.includeDisabled)
        Text(L10n.Cheatsheet.sourceHelp)
            .font(.caption).foregroundStyle(.secondary)
        if let error = feature.tapError {
            Text(error).font(.caption).foregroundStyle(.orange)
        }
    }
}
