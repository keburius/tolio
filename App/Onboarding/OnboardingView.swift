import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Four screens: what Omni does, choose features, permissions, shortcuts.
struct OnboardingView: View {
    private enum Step: Int, CaseIterable { case welcome, choose, permissions, shortcuts }

    let services: AppServices
    let onFinish: (_ openPanel: Bool) -> Void
    @State private var step = Step.welcome
    @State private var model: OnboardingModel

    init(services: AppServices, onFinish: @escaping (_ openPanel: Bool) -> Void) {
        self.services = services
        self.onFinish = onFinish
        let options = services.visibleFeatures(includingHidden: false).map {
            OnboardingModel.Option(id: $0.id, required: $0.requiredPermissions, optional: $0.optionalPermissions)
        }
        // Someone reopening the guide starts from what's on now.
        let current = Set(options.map(\.id).filter { services.features.isWanted($0) })
        let completed = services.settings.value(AppServices.onboardingCompletedKey)
        _model = State(initialValue: OnboardingModel(options: options, chosen: completed ? current : nil))
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: welcome
                case .choose: choose
                case .permissions: permissions
                case .shortcuts: shortcuts
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(OmniStyle.s5)
            dots.padding(.bottom, OmniStyle.s3)
        }
        .frame(width: 640, height: 540)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { item in
                Circle().fill(item == step ? Color.accentColor : Color.secondary.opacity(0.35)).frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }

    private func go(_ next: Step) {
        if let animation = OmniStyle.motion() { withAnimation(animation) { step = next } } else { step = next }
    }

    // MARK: 1 — What Omni does

    private var welcome: some View {
        VStack(spacing: OmniStyle.s5) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 88, height: 88)
                .accessibilityHidden(true)
            Text(L10n.Onboarding.intro).font(.title3).multilineTextAlignment(.center).frame(maxWidth: 480)
            HStack(spacing: OmniStyle.s5) {
                icon("camera.viewfinder", L10n.Onboarding.screenshots)
                icon("doc.on.clipboard", L10n.Onboarding.clipboard)
                icon("rectangle.split.2x1", L10n.Onboarding.windows)
                icon("cup.and.saucer", L10n.Onboarding.keepAwake)
                icon("magnifyingglass", L10n.Onboarding.launcher)
            }
            Text(L10n.Onboarding.staysOnMac).font(.callout).foregroundStyle(.secondary)
            Spacer()
            HStack {
                Spacer()
                Button(L10n.Onboarding.getStarted) { go(.choose) }.keyboardShortcut(.defaultAction).controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func icon(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: OmniStyle.s1) {
            Image(systemName: symbol).font(.title).symbolRenderingMode(.hierarchical).frame(height: 32)
            Text(title).font(.caption)
        }
        .frame(width: 80)
    }

    // MARK: 2 — Choose features

    private var choose: some View {
        let features = services.visibleFeatures(includingHidden: false)
        let recommended = features.filter { OnboardingModel.recommended.contains($0.id) }
        let more = features.filter { !OnboardingModel.recommended.contains($0.id) }
        return VStack(alignment: .leading, spacing: OmniStyle.s3) {
            Text(L10n.Onboarding.chooseTitle).font(.title.weight(.semibold))
            Text(L10n.Onboarding.chooseSubtitle).foregroundStyle(.secondary)
            HStack {
                Button(L10n.Onboarding.recommended) { model.chooseRecommended() }
                Button(L10n.Onboarding.everything) { model.chooseEverything() }
                Button(L10n.Common.none) { model.chooseNone() }
            }
            .controlSize(.small)
            ScrollView {
                VStack(alignment: .leading, spacing: OmniStyle.s2) {
                    ForEach(recommended, id: \.id) { featureRow($0) }
                    SectionHeader(L10n.Onboarding.more).padding(.top, OmniStyle.s2)
                    ForEach(more, id: \.id) { featureRow($0) }
                }
                .padding(.trailing, OmniStyle.s2)
            }
            HStack {
                Button(L10n.Common.back) { go(.welcome) }
                Spacer()
                Button(L10n.Common.continue) { applyChoice(); go(.permissions) }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private func featureRow(_ feature: any Feature) -> some View {
        Toggle(isOn: Binding(get: { model.chosen.contains(feature.id) }, set: { model.set($0, feature.id) })) {
            HStack(alignment: .top) {
                Image(systemName: feature.symbolName).symbolRenderingMode(.hierarchical).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.displayName).font(.headline)
                    Text(feature.summary).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if let permission = feature.requiredPermissions.sorted(by: { $0.rawValue < $1.rawValue }).first {
                    Text(L10n.Onboarding.needs(permission.displayName)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.checkbox)
    }

    /// Choices take effect only here, so going back and forth starts nothing.
    private func applyChoice() {
        let current = Set(model.options.map(\.id).filter { services.features.isWanted($0) })
        for (id, on) in model.changes(from: current) { services.features.setWanted(on, for: id) }
    }

    // MARK: 3 — Permissions

    private var permissions: some View {
        let required = Permission.allCases.filter(model.requiredPermissions.contains)
        let optional = Permission.allCases.filter(model.optionalPermissions.contains)
        return VStack(alignment: .leading, spacing: OmniStyle.s3) {
            Text(L10n.Onboarding.permissionsTitle).font(.title.weight(.semibold))
            if required.isEmpty && optional.isEmpty {
                Text(L10n.Onboarding.noPermissions).foregroundStyle(.secondary)
                Spacer()
            } else {
                Text(L10n.Permissions.nothingLeavesMac).foregroundStyle(.secondary)
                ScrollView {
                    VStack(spacing: OmniStyle.s2) {
                        ForEach(required) { permissionCard($0, optional: false) }
                        ForEach(optional) { permissionCard($0, optional: true) }
                    }
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.Onboarding.reopenNote).font(.caption).foregroundStyle(.secondary)
                    Button(L10n.Onboarding.reopenOmni) { Self.relaunch() }.controlSize(.small)
                }
            }
            HStack {
                Button(L10n.Common.back) { go(.choose) }
                Spacer()
                if !required.isEmpty { Button(L10n.Onboarding.skipForNow) { go(.shortcuts) } }
                Button(L10n.Common.continue) { go(.shortcuts) }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private func permissionCard(_ permission: Permission, optional: Bool) -> some View {
        let users = model.users(of: permission).compactMap { services.features.feature($0)?.displayName }
        return VStack(alignment: .leading, spacing: OmniStyle.s1) {
            PermissionRow(
                permission: permission, permissions: services.permissions,
                note: ListFormatter().string(from: users).map(L10n.Onboarding.usedBy)
            )
            if optional { Text(L10n.Permissions.optional).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(OmniStyle.s3)
        .omniPanelBackground(radius: OmniStyle.cardRadius, material: .thinMaterial)
    }

    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    // MARK: 4 — Shortcuts

    private var shortcuts: some View {
        let lookup = ShortcutLookup(services: services)
        var rows: [(String, String)] = []
        if let panel = lookup.text(for: AppHotkeys.controlPanel.id) { rows.append((panel, L10n.Onboarding.orClickIcon)) }
        for feature in services.visibleFeatures(includingHidden: false) where model.chosen.contains(feature.id) {
            if let action = feature.declaredHotkeys.first, let text = lookup.text(for: action.id) {
                rows.append((text, action.title))
            } else if let gesture = feature.gestures.first {
                rows.append((gesture.gesture, gesture.title))
            }
        }
        return VStack(alignment: .leading, spacing: OmniStyle.s3) {
            Text(L10n.Onboarding.doneTitle).font(.title2.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: OmniStyle.s4, verticalSpacing: OmniStyle.s2) {
                ForEach(rows, id: \.1) { shortcut, title in
                    GridRow {
                        ShortcutChip(shortcut)
                        Text(title)
                    }
                }
            }
            Text(L10n.Onboarding.doneNote).font(.callout).foregroundStyle(.secondary)
            Spacer()
            HStack {
                Button(L10n.Common.back) { go(.permissions) }
                Spacer()
                Button(L10n.Onboarding.finish) { onFinish(false) }
                Button(L10n.Onboarding.tryIt) { onFinish(true) }.keyboardShortcut(.defaultAction)
            }
        }
    }
}
