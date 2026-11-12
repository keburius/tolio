import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Text snippets: type an abbreviation (its "code") anywhere and it's
/// replaced with the snippet text. Also insertable from the Launcher with “snip …”.
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
        context.registerSearchProvider(SnippetSearchProvider(feature: self))
        context.registerCommand(Command(
            id: "snippets.browse", title: L10n.Snippets.commandInsert, keywords: ["snippet", "text"], symbolName: symbolName
        ) { context.openPalette(query: "snip ") })
    }

    public func disable() {
        engine = nil
        settings = nil
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(SnippetsSettingsView(settings: settings))
    }

    var snippets: [Snippet] { settings?.value(Self.snippetsKey) ?? [] }

    /// True while on (settings are only available then).
    var isOn: Bool { settings != nil }

    func setSnippets(_ snippets: [Snippet]) {
        settings?.set(snippets, for: Self.snippetsKey)
    }

    func insert(_ snippet: Snippet) {
        engine?.insert(snippet)
    }
}

/// Launcher results for "snip …".
@MainActor
final class SnippetSearchProvider: SearchProvider {
    let keyword = "snip"
    var title: String { L10n.Snippets.searchTitle }
    private weak var feature: SnippetsFeature?

    init(feature: SnippetsFeature) {
        self.feature = feature
    }

    func results(for query: String, limit: Int) -> [SearchResult] {
        guard let feature else { return [] }
        let needle = query.lowercased()
        return feature.snippets
            .filter { $0.isEnabled }
            .filter {
                needle.isEmpty || $0.title.lowercased().contains(needle)
                    || $0.abbreviation.lowercased().contains(needle) || $0.body.lowercased().contains(needle)
            }
            .prefix(limit)
            .map { snippet in
                SearchResult(
                    id: snippet.id.uuidString, title: snippet.title, subtitle: snippet.abbreviation,
                    icon: .symbol("text.quote"),
                    primaryAction: { [weak feature] in
                        // Let focus return to the previous app before pasting.
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(80))
                            feature?.insert(snippet)
                        }
                    }
                )
            }
    }
}
