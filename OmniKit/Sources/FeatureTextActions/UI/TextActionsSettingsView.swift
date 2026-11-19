import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Two tabs: which actions the bar offers, and when it shows. The app
/// draws the Permissions card under them.
struct TextActionsSettingsView: View {
    let settings: SettingsStore
    @State private var tab = Tab.actions
    @Environment(\.settingsHighlight) private var highlight

    enum Tab: Hashable { case actions, whenItShows }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ASSegmented(
                L10n.TextActions.settingsTabs, selection: $tab,
                options: [(.actions, L10n.TextActions.tabActions), (.whenItShows, L10n.TextActions.tabWhenItShows)],
                size: .wide
            )
            switch tab {
            case .actions: actionsTab
            case .whenItShows: whenItShowsTab
            }
        }
        .onChange(of: highlight, initial: true) { _, anchor in
            guard let anchor else { return }
            let whenItShows: Set<String> = [
                TextActionsFeature.Anchor.mouseTrigger, TextActionsFeature.Anchor.keyboardTrigger,
                TextActionsFeature.Anchor.copyFallback, TextActionsFeature.Anchor.excludedApps,
            ]
            if anchor.hasPrefix("textactions.") { tab = whenItShows.contains(anchor) ? .whenItShows : .actions }
        }
    }

    // MARK: Actions

    private var actionsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            ASCard { actionGrid }
            VStack(alignment: .leading, spacing: 6) {
                ASCard {
                    ASRow(L10n.TextActions.searchWith) {
                        ASPopUp(
                            L10n.TextActions.searchWith, selection: settings.binding(TextActionsFeature.engineKey),
                            options: SearchEngine.allCases.map { ($0, $0.label) }
                        )
                    }
                    .settingsAnchor(TextActionsFeature.Anchor.searchEngine)
                }
                ASFootnote(L10n.TextActions.actionsNote)
            }
        }
    }

    private var actionGrid: some View {
        let actions = TextActionCatalog.builtIn
        let rows = stride(from: 0, to: actions.count, by: 2).map { Array(actions[$0 ..< min($0 + 2, actions.count)]) }
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, pair in
                if index > 0 { Rectangle().fill(AS.divider).frame(height: 1) }
                HStack(spacing: 1) {
                    ForEach(pair, id: \.id) { action in actionCell(action) }
                    if pair.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                }
            }
        }
    }

    private func actionCell(_ action: any TextAction) -> some View {
        HStack(spacing: 10) {
            ActionIcon(id: action.id)
            Text(action.title).font(AS.body).foregroundStyle(AS.text).frame(maxWidth: .infinity, alignment: .leading)
            ASSwitch(action.title, isOn: Binding(
                get: { settings.value(TextActionsFeature.actionsKey).contains(action.id) },
                set: { on in
                    var set = settings.value(TextActionsFeature.actionsKey)
                    if on { set.insert(action.id) } else { set.remove(action.id) }
                    settings.set(set, for: TextActionsFeature.actionsKey)
                }
            ))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .settingsAnchor(TextActionsFeature.Anchor.action(action.id))
    }

    // MARK: When it shows

    private var whenItShowsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            ASSection(L10n.TextActions.showAfter) {
                ASToggleRow(L10n.TextActions.mouseTrigger, subtitle: L10n.TextActions.mouseTriggerHelp,
                            isOn: settings.binding(TextActionsFeature.mouseKey))
                    .settingsAnchor(TextActionsFeature.Anchor.mouseTrigger)
                ASToggleRow(L10n.TextActions.keyboardTrigger, isOn: settings.binding(TextActionsFeature.keyboardKey))
                    .settingsAnchor(TextActionsFeature.Anchor.keyboardTrigger)
            }
            ASSection(L10n.TextActions.readingSelection) {
                ASToggleRow(L10n.TextActions.copyBriefly, subtitle: L10n.TextActions.copyBrieflyNote,
                            isOn: settings.binding(TextActionsFeature.fallbackKey))
                    .settingsAnchor(TextActionsFeature.Anchor.copyFallback)
            }
            ExcludedAppsSection(settings: settings)
        }
    }
}

/// An action's line icon (or letter) as the design draws it.
private struct ActionIcon: View {
    let id: String

    var body: some View {
        switch id {
        case "copy": LineIcon("M5.500 4.500h6.500v8.500H5.500zM3.500 11V2.500h6", color: AS.icon)
        case "paste": LineIcon("M4 4h8v9.500H4zM6 2.800h4v2.200H6z", color: AS.icon)
        case "openURL": LineIcon("M8 2.500a5.500 5.500 0 1 0 .01 0M10.500 5.500l-1.500 3.500-3.500 1.500 1.500-3.500z", color: AS.icon)
        case "search": LineIcon("M7 2.500a4.500 4.500 0 1 0 .01 0M10.400 10.400L13.500 13.500", color: AS.icon)
        case "translate": LineIcon("M8 2.500a5.500 5.500 0 1 0 .01 0M2.500 8h11M8 2.500c-3 3-3 8 0 11M8 2.500c3 3 3 8 0 11", color: AS.icon)
        case "uppercase": letter("A") // l10n-ignore
        case "lowercase": letter("a") // l10n-ignore
        case "count": letter("#")
        default: Color.clear.frame(width: 16, height: 16)
        }
    }

    private func letter(_ text: String) -> some View {
        Text(verbatim: text)
            .font(AS.font(14, .semibold))
            .foregroundStyle(AS.icon)
            .frame(width: 16)
            .accessibilityHidden(true)
    }
}

private struct ExcludedAppsSection: View {
    let settings: SettingsStore

    var body: some View {
        let excluded = settings.value(TextActionsFeature.excludedKey)
        ASSection(L10n.TextActions.neverShowIn) {
            ForEach(excluded.sorted(), id: \.self) { bundleID in
                ASRow(appName(bundleID)) {
                    Button(L10n.Common.remove) { settings.set(excluded.subtracting([bundleID]), for: TextActionsFeature.excludedKey) }
                        .buttonStyle(.asSecondary)
                }
            }
            HStack(spacing: 12) {
                Text(excluded.isEmpty ? L10n.TextActions.noOtherAppsExcluded : L10n.Common.passwordManagersAlwaysExcluded)
                    .font(AS.body).foregroundStyle(AS.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Menu {
                    ForEach(runningApps(excluding: excluded), id: \.0) { id, name in
                        Button(name) { settings.set(excluded.union([id]), for: TextActionsFeature.excludedKey) }
                    }
                } label: {
                    ASPopUpLabel(L10n.Common.addApp)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .settingsAnchor(TextActionsFeature.Anchor.excludedApps)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
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

/// The example at the top of the page: a small bar of actions above some
/// selected text (the design's 420×140 drawing).
struct TextActionsHero: View {
    var body: some View {
        ASStage(tint: Color(hex: 0x55B1CA).opacity(0.67)) {
            Canvas { context, size in
                let ink = Color(hex: 0x15161B)
                let line = Color.white.opacity(0.32)
                func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
                    Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r, style: .continuous)
                }
                func svg(_ data: String) -> Path { SVGPath(data, viewBox: size).path(in: CGRect(origin: .zero, size: size)) }

                // The bar and its pointer.
                context.fill(rect(118, 14, 184, 46, 23), with: .color(ink))
                context.stroke(rect(118, 14, 184, 46, 23), with: .color(.white.opacity(0.14)), lineWidth: 1.2)
                context.fill(svg("M202 59l8 9 8-9z"), with: .color(ink))
                let icon = StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                for data in [
                    "M144 31h10v13h-10zM140.500 41v-13h9.500",
                    "M186 30a6.500 6.500 0 1 0 .01 0M191 41.500l5.500 5.500",
                    "M230 28a9 9 0 1 0 .01 0M221 37h18M230 28c-5 5-5 13 0 18M230 28c5 5 5 13 0 18",
                ] {
                    context.stroke(svg(data), with: .color(.white), style: icon)
                }
                context.draw(Text(verbatim: "Aa").font(AS.font(17, .semibold)).foregroundStyle(.white), // l10n-ignore
                             at: CGPoint(x: 274, y: 37.5), anchor: .center)

                // Lines of text, one selected.
                context.fill(rect(40, 88, 84, 10, 5), with: .color(line))
                context.fill(rect(134, 78, 152, 30, 7), with: .color(Color(hex: 0x55B1CA).opacity(0.4)))
                context.fill(rect(143, 88, 134, 10, 5), with: .color(.white))
                context.fill(rect(296, 88, 84, 10, 5), with: .color(line))
                context.fill(rect(40, 122, 180, 10, 5), with: .color(line))
                context.fill(rect(230, 122, 110, 10, 5), with: .color(line))
            }
            .frame(width: 420, height: 140)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.TextActions.heroDescription)
        .accessibilityAddTraits(.isImage)
    }
}
