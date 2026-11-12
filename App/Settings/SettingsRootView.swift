import OmniCore
import OmniPlatform
import SwiftUI

/// Settings window: app pages, one page per feature, and search.
struct SettingsRootView: View {
    let services: AppServices
    let navigation: SettingsNavigation
    let menuBarEntries: () -> [QuickAccessID: MenuBarController.Entry]
    let onShowOnboarding: () -> Void

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            detail
        }
        .searchable(text: Bindable(navigation).query, placement: .sidebar, prompt: L10n.SettingsUI.searchPrompt)
    }

    @ViewBuilder private var sidebar: some View {
        if navigation.query.trimmingCharacters(in: .whitespaces).isEmpty {
            List(selection: Binding(get: { navigation.page }, set: { if let page = $0 { navigation.open(page) } })) {
                Label(L10n.SettingsUI.overview, systemImage: "square.grid.2x2").tag(SettingsPage.overview)
                Label(L10n.SettingsUI.menuBar, systemImage: "menubar.rectangle").tag(SettingsPage.menuBar)
                Label(L10n.SettingsUI.shortcuts, systemImage: "keyboard").tag(SettingsPage.shortcuts)
                Label(L10n.SettingsUI.permissions, systemImage: "lock.shield").tag(SettingsPage.permissions)
                Label(L10n.SettingsUI.general, systemImage: "gearshape").tag(SettingsPage.general)
                Section(L10n.SettingsUI.features) {
                    ForEach(services.visibleFeatures(includingHidden: navigation.showsHiddenFeatures), id: \.id) { feature in
                        FeatureSidebarRow(feature: feature, status: services.features.status(of: feature.id))
                            .tag(SettingsPage.feature(feature.id))
                    }
                }
            }
        } else {
            searchResults
        }
    }

    @ViewBuilder private var searchResults: some View {
        let results = services.settingsIndex(includingHidden: navigation.showsHiddenFeatures).search(navigation.query)
        if results.isEmpty {
            EmptyState(symbol: "magnifyingglass", message: L10n.SettingsUI.noSettingsMatch(navigation.query))
                .frame(maxHeight: .infinity, alignment: .top)
        } else {
            List(results) { item in
                Button {
                    navigation.open(item.page, anchor: item.anchor)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label).lineLimit(1)
                        Text(item.pageTitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var detail: some View {
        switch navigation.page {
        case .overview:
            OverviewPane(services: services, navigation: navigation)
        case .menuBar:
            MenuBarPane(services: services, entries: menuBarEntries)
        case .shortcuts:
            ShortcutsPane(services: services, navigation: navigation)
        case .permissions:
            PermissionsPane(services: services, navigation: navigation)
        case .general:
            GeneralPane(services: services, onShowOnboarding: onShowOnboarding)
        case let .feature(id):
            if let feature = services.features.feature(id) {
                FeaturePane(feature: feature, services: services, navigation: navigation).id(id)
            }
        }
    }
}

private struct FeatureSidebarRow: View {
    let feature: any Feature
    let status: FeatureRegistry.Status

    var body: some View {
        let badge = StatusBadge(status.badge)
        HStack {
            Label(feature.displayName, systemImage: feature.symbolName)
            Spacer()
            Circle().fill(badge.color).frame(width: 7, height: 7)
        }
        .help(statusText)
        .accessibilityElement(children: .combine)
        .accessibilityValue(statusText)
    }

    private var statusText: String {
        switch status.badge {
        case .working: L10n.Status.working
        case .needsPermission: L10n.Status.needsPermission
        case .off: L10n.Status.off
        case let .problem(detail): L10n.Status.problem(detail)
        }
    }
}
