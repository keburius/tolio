import OmniCore
import OmniPlatform
import SwiftUI

/// First page: one card per feature with its switch, status and shortcut.
struct OverviewPane: View {
    let services: AppServices
    let navigation: SettingsNavigation

    private var features: [any Feature] { services.visibleFeatures(includingHidden: navigation.showsHiddenFeatures) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OmniStyle.s4) {
                Text(L10n.SettingsUI.overview).font(.title2.weight(.semibold))
                waitingBanner
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: OmniStyle.s3)], spacing: OmniStyle.s3) {
                    ForEach(features, id: \.id) { feature in
                        FeatureCard(feature: feature, services: services) { navigation.open(.feature(feature.id)) }
                    }
                }
            }
            .padding(OmniStyle.s5)
        }
    }

    @ViewBuilder private var waitingBanner: some View {
        let waiting: [(any Feature, Permission)] = features.compactMap { feature in
            if case let .waitingForPermissions(missing) = services.features.status(of: feature.id),
               let permission = missing.sorted(by: { $0.rawValue < $1.rawValue }).first {
                return (feature, permission)
            }
            return nil
        }
        if !waiting.isEmpty {
            VStack(alignment: .leading, spacing: OmniStyle.s2) {
                Label(L10n.SettingsUI.waitingBanner(waiting.count), systemImage: "exclamationmark.triangle.fill")
                    .font(.headline).foregroundStyle(.orange)
                ForEach(waiting, id: \.0.id) { feature, permission in
                    HStack {
                        Text(L10n.SettingsUI.needs(feature.displayName, permission.displayName))
                        Spacer()
                        Button(L10n.Common.allow) { Task { _ = await services.permissions.request(permission) } }
                    }
                }
            }
            .padding(OmniStyle.s3)
            .omniPanelBackground(radius: OmniStyle.cardRadius, material: .thinMaterial)
        }
    }
}

private struct FeatureCard: View {
    let feature: any Feature
    let services: AppServices
    let open: () -> Void

    var body: some View {
        let status = services.features.status(of: feature.id)
        VStack(alignment: .leading, spacing: OmniStyle.s2) {
            HStack(alignment: .top) {
                Label(feature.displayName, systemImage: feature.symbolName)
                    .font(.headline).symbolRenderingMode(.hierarchical)
                Spacer()
                Toggle(feature.displayName, isOn: Binding(
                    get: { services.features.isWanted(feature.id) },
                    set: { services.features.setWanted($0, for: feature.id) }
                ))
                .toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
            Text(feature.summary).font(.callout).foregroundStyle(.secondary).lineLimit(3, reservesSpace: true)
            HStack {
                StatusBadge(status.badge)
                if case let .waitingForPermissions(missing) = status, let permission = missing.first {
                    Button(L10n.Common.allow) { Task { _ = await services.permissions.request(permission) } }.controlSize(.small)
                }
                Spacer()
                if let shortcut = services.mainShortcutText(of: feature) { ShortcutChip(shortcut) }
            }
        }
        .padding(OmniStyle.s3)
        .omniPanelBackground(radius: OmniStyle.cardRadius, material: .thinMaterial)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text(feature.displayName), open)
    }
}
