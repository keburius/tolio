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
        })
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

    public func makeSettingsHero() -> AnyView? {
        AnyView(TextActionsHero())
    }
}
