import OmniCore
import OmniPlatform
import SwiftUI

/// First-run flow: choose features, then grant only the permissions they need.
struct OnboardingView: View {
    private enum Step { case features, permissions }

    let services: AppServices
    let onFinish: () -> Void
    @State private var step = Step.features

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch step {
            case .features: featuresStep
            case .permissions: permissionsStep
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 460, alignment: .topLeading)
    }

    private var featuresStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Omni").font(.largeTitle.bold())
            Text("Pick the features you want. You can change this any time in Settings.")
                .foregroundStyle(.secondary)
            List(services.features.features, id: \.id) { feature in
                Toggle(isOn: Binding(
                    get: { services.features.isWanted(feature.id) },
                    set: { services.features.setWanted($0, for: feature.id) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(feature.displayName, systemImage: feature.symbolName)
                        Text(feature.summary).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .listStyle(.bordered)
            HStack {
                Spacer()
                Button("Continue") { step = .permissions }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private var permissionsStep: some View {
        let required = services.features.permissionsForWantedFeatures
        let optional = services.features.optionalPermissionsForWantedFeatures
        return VStack(alignment: .leading, spacing: 16) {
            Text("Permissions").font(.largeTitle.bold())
            if required.isEmpty && optional.isEmpty {
                Text("The features you picked don't need any permissions.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                Text("Omni asks only for what your features need. Nothing you grant leaves this Mac.")
                    .foregroundStyle(.secondary)
                List {
                    ForEach(sorted(required)) { PermissionRow(permission: $0, permissions: services.permissions, note: "Required") }
                    ForEach(sorted(optional)) { PermissionRow(permission: $0, permissions: services.permissions, note: "Optional") }
                }
                .listStyle(.bordered)
            }
            HStack {
                Button("Back") { step = .features }
                Spacer()
                Button("Done", action: onFinish).keyboardShortcut(.defaultAction)
            }
        }
    }

    private func sorted(_ set: Set<Permission>) -> [Permission] {
        Permission.allCases.filter(set.contains)
    }
}
