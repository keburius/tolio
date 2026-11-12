import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Text snippets: type an abbreviation anywhere and it's replaced with the
/// snippet text. Also insertable from the palette with “snip …”.
@MainActor
@Observable
public final class SnippetsFeature: Feature {
    static let snippetsKey = SettingKey.feature("snippets", "items", default: [
        Snippet(abbreviation: ";date", title: "Today's date", body: "{date}"),
        Snippet(abbreviation: ";sig", title: "Email sign-off", body: "Best regards,\n{cursor}"),
    ])

    public let id: FeatureID = "snippets"
    public let displayName = "Snippets"
    public let summary = "Type an abbreviation like ;sig in any app to insert saved text."
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
            id: "snippets.browse", title: "Insert Snippet", keywords: ["snippet", "text"], symbolName: symbolName
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

    func insert(_ snippet: Snippet) {
        engine?.insert(snippet)
    }
}

/// Palette results for "snip …".
@MainActor
final class SnippetSearchProvider: SearchProvider {
    let keyword = "snip"
    let title = "Snippet"
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
