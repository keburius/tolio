import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Alt-Tab style switching between individual windows, with thumbnails.
@MainActor
@Observable
public final class SwitcherFeature: Feature {
    static let triggerKey = SettingKey.feature("switcher", "trigger", default: SwitcherTrigger.option)
    static let minimizedKey = SettingKey.feature("switcher", "includeMinimized", default: true)
    static let hiddenKey = SettingKey.feature("switcher", "includeHidden", default: true)
    static let otherSpacesKey = SettingKey.feature("switcher", "includeOtherSpaces", default: true)
    static let thumbnailsKey = SettingKey.feature("switcher", "thumbnails", default: true)

    enum Anchor {
        static let trigger = "switcher.trigger"
        static let thumbnails = "switcher.thumbnails"
        static let minimized = "switcher.includeMinimized"
        static let hidden = "switcher.includeHidden"
        static let otherSpaces = "switcher.includeOtherSpaces"
    }

    public let id: FeatureID = "switcher"
    public var displayName: String { L10n.Switcher.displayName }
    public var summary: String { L10n.Switcher.summary }
    public let symbolName = "rectangle.stack"
    public let requiredPermissions: Set<Permission> = [.accessibility]
    /// Without it: app icons instead of thumbnails, and no other-Space windows.
    public let optionalPermissions: Set<Permission> = [.screenRecording]

    private(set) var tapFailed = false
    @ObservationIgnored private var controller: SwitcherController?
    @ObservationIgnored private(set) var settings: SettingsStore?

    public init() {}

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        tapFailed = false
        let tracker = FocusTracker()
        tracker.start()
        let controller = SwitcherController(tracker: tracker, options: {
            WindowListOptions(
                includeMinimized: settings.value(Self.minimizedKey),
                includeHidden: settings.value(Self.hiddenKey),
                includeOtherSpaces: settings.value(Self.otherSpacesKey)
            )
        }, wantsThumbnails: { settings.value(Self.thumbnailsKey) })
        self.controller = controller

        var isTriggerHeld: () -> Bool = { true }
        let keyTap = SwitcherKeyTap(
            trigger: { settings.value(Self.triggerKey) },
            isOpen: { controller.isOpen },
            onEvent: { event in
                switch event {
                case let .begin(backward):
                    controller.begin(backward: backward)
                    // Released before we got here (a quick tap): switch now
                    // instead of waiting for a release we already missed.
                    if controller.isOpen && !isTriggerHeld() { controller.handle(.release) }
                case let .input(input): controller.handle(input)
                }
            },
            onFailure: { [weak self] in
                controller.handle(.escape)
                self?.tapFailed = true
                HUD.show(L10n.Switcher.paused, symbol: "exclamationmark.triangle")
            }
        )
        isTriggerHeld = { [weak keyTap] in keyTap?.isTriggerHeld() ?? false }
        do {
            try keyTap.start()
        } catch {
            tracker.stop()
            throw error
        }
        context.lifetime.add {
            keyTap.stop()
            tracker.stop()
            controller.close()
        }
        context.registerSearchProvider(WindowSearchProvider(controller: controller))
        context.registerCommand(Command(
            id: "switcher.search", title: L10n.Switcher.searchCommand, keywords: ["window", "switch", "focus"], symbolName: symbolName
        ) { context.openPalette(query: "win ") })
    }

    public func disable() {
        controller = nil
        settings = nil
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(SwitcherSettingsView(feature: self, settings: settings))
    }
}
