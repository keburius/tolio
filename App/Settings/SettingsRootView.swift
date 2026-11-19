import OmniCore
import OmniPlatform
import SwiftUI

/// Settings window: a dark sidebar (pages, features, account pages) and the
/// selected page. Typing in the search field lists matching settings instead.
struct SettingsRootView: View {
    let services: AppServices
    let navigation: SettingsNavigation
    let menuBarEntries: () -> [QuickAccessID: MenuBarController.Entry]
    let onShowOnboarding: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(services: services, navigation: navigation)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AS.window)
        .ignoresSafeArea()
        .allSetWindowStyle()
        .frame(minWidth: 860, minHeight: 600)
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
        case .profile:
            ProfilePane(services: services)
        case let .feature(id):
            if let feature = services.features.feature(id) {
                FeaturePane(feature: feature, services: services, navigation: navigation).id(id)
            }
        }
    }
}

/// The left column: traffic-light space, search, then pages.
private struct SettingsSidebar: View {
    let services: AppServices
    let navigation: SettingsNavigation
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 44)
            searchField
            if navigation.query.trimmingCharacters(in: .whitespaces).isEmpty {
                pages.padding(.top, 10)
            } else {
                searchResults.padding(.top, 10)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .frame(width: 212)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AS.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(AS.divider).frame(width: 1) }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            LineIcon(ASIcon.search, size: 12, lineWidth: 1.7, color: AS.textSecondary)
            TextField(L10n.AllSet.search, text: Bindable(navigation).query)
                .textFieldStyle(.plain)
                .font(AS.body)
                .focused($searchFocused)
                .accessibilityLabel(L10n.SettingsUI.searchPrompt)
            if !navigation.query.isEmpty {
                Button { navigation.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AS.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Common.cancel)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(AS.fieldFill))
    }

    private var pages: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                pageRow(.overview, L10n.SettingsUI.overview, ASIcon.overview)
                pageRow(.menuBar, L10n.SettingsUI.menuBar, ASIcon.menuBar)
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.AllSet.features)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AS.textTertiary)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(services.sidebarFeatures(includingHidden: navigation.showsHiddenFeatures), id: \.id) { feature in
                        SidebarRow(title: feature.sidebarName, selected: navigation.page == .feature(feature.id)) {
                            FeatureIcon(feature.id, size: 20, fallbackSymbol: feature.symbolName)
                        } action: {
                            navigation.open(.feature(feature.id))
                        }
                    }
                }
            }
            VStack(spacing: 0) {
                pageRow(.profile, L10n.AllSet.profile, ASIcon.profile)
                pageRow(.general, L10n.SettingsUI.general, ASIcon.general)
                pageRow(.permissions, L10n.SettingsUI.permissions, ASIcon.permissions)
                pageRow(.shortcuts, L10n.SettingsUI.shortcuts, ASIcon.shortcuts)
            }
            .padding(.top, 6)
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func pageRow(_ page: SettingsPage, _ title: String, _ icon: String) -> some View {
        SidebarRow(title: title, selected: navigation.page == page) {
            LineIconTile(icon, size: 20, iconSize: 12)
        } action: {
            navigation.open(page)
        }
    }

    @ViewBuilder private var searchResults: some View {
        let results = services.settingsIndex(includingHidden: navigation.showsHiddenFeatures).search(navigation.query)
        if results.isEmpty {
            Text(L10n.SettingsUI.noSettingsMatch(navigation.query))
                .font(.system(size: 12))
                .foregroundStyle(AS.textSecondary)
                .padding(.horizontal, 8)
                .frame(maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(results) { item in
                        Button {
                            navigation.open(item.page, anchor: item.anchor)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.label).font(AS.body).foregroundStyle(AS.text).lineLimit(1)
                                Text(item.pageTitle).font(.system(size: 11)).foregroundStyle(AS.textTertiary).lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(SidebarButtonStyle(selected: false))
                    }
                }
            }
        }
    }
}

/// One sidebar line: 20 pt icon tile and the page name; selected rows get a soft fill.
private struct SidebarRow<Icon: View>: View {
    let title: String
    let selected: Bool
    @ViewBuilder let icon: Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon
                Text(title).font(AS.body).foregroundStyle(AS.text).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarButtonStyle(selected: selected))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct SidebarButtonStyle: ButtonStyle {
    let selected: Bool
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected ? AS.selectedFill : (hovering || configuration.isPressed ? Color.white.opacity(0.05) : .clear))
            )
            .onHover { hovering = $0 }
    }
}

/// The frame every Settings page uses: a 40 pt title bar and the content
/// below it, scrolling when it doesn't fit.
struct PageScaffold<Accessory: View, Content: View>: View {
    let title: String
    let spacing: CGFloat
    @ViewBuilder let accessory: Accessory
    @ViewBuilder let content: Content

    init(_ title: String, spacing: CGFloat = 14, @ViewBuilder accessory: () -> Accessory = { EmptyView() }, @ViewBuilder content: () -> Content) {
        self.title = title
        self.spacing = spacing
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text(title).font(AS.pageTitle).foregroundStyle(AS.text).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                accessory
            }
            .frame(height: 40)
            .padding(.horizontal, 24)
            .padding(.top, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: spacing) {
                    content
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
        }
    }
}

extension Feature {
    /// The shorter name the sidebar uses ("Screenshots" for "Screenshots & Recording").
    var sidebarName: String {
        id == "screenshots" ? L10n.Screenshots.sidebarName : displayName
    }
}
