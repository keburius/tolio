import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Text snippets: type an abbreviation (its "code") anywhere and it's
/// replaced with the snippet text.
@MainActor
@Observable
public final class SnippetsFeature: Feature {
    static let snippetsKey = SettingKey.feature("snippets", "items", default: [
        Snippet(abbreviation: ";date", title: L10n.Snippets.defaultDateTitle, body: "{date}"),
        Snippet(abbreviation: ";sig", title: L10n.Snippets.defaultSignOffTitle, body: "Best regards,\n{cursor}"),
    ])

    public let id: FeatureID = "snippets"
    public var displayName: String { L10n.Snippets.displayName }
    public var summary: String { L10n.Snippets.summary }
    public let symbolName = "text.badge.plus"
    public let group: FeatureGroup = .clipboard
    public let requiredPermissions: Set<Permission> = [.accessibility]

    @ObservationIgnored private var engine: SnippetEngine?
    @ObservationIgnored private var settings: SettingsStore?

    public init() {}

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        let engine = SnippetEngine { settings.value(Self.snippetsKey) }
        try engine.start()
        self.engine = engine
        context.lifetime.add { engine.stop() }
    }

    public func disable() {
        engine = nil
        settings = nil
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(SnippetsSettingsView(settings: settings))
    }

    public func makeSettingsHero() -> AnyView? {
        AnyView(SnippetsHero())
    }

    var snippets: [Snippet] { settings?.value(Self.snippetsKey) ?? [] }

    /// True while on (settings are only available then).
    var isOn: Bool { settings != nil }

    func setSnippets(_ snippets: [Snippet]) {
        settings?.set(snippets, for: Self.snippetsKey)
    }
}
