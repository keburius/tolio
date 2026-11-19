import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// The setup guide, four screens: welcome, choose features, permissions, done.
/// Drawn edge to edge in a 760×580 All Set window; the top 40 pt is left for
/// the traffic lights.
struct OnboardingView: View {
    private enum Step: Int, CaseIterable { case welcome, choose, permissions, done }
    private enum Preset: Hashable { case recommended, everything, custom }

    let services: AppServices
    let onFinish: (_ openSettings: Bool) -> Void
    @State private var step = Step.welcome
    @State private var model: OnboardingModel
    @State private var preset: Preset

    init(services: AppServices, onFinish: @escaping (_ openSettings: Bool) -> Void) {
        self.services = services
        self.onFinish = onFinish
        let options = services.visibleFeatures(includingHidden: false).map {
            OnboardingModel.Option(id: $0.id, required: $0.requiredPermissions, optional: $0.optionalPermissions)
        }
        // Someone reopening the guide starts from what's on now.
        let current = Set(options.map(\.id).filter { services.features.isWanted($0) })
        let completed = services.settings.value(AppServices.onboardingCompletedKey)
        let model = OnboardingModel(options: options, chosen: completed ? current : nil)
        _model = State(initialValue: model)
        let all = Set(options.map(\.id))
        let recommended = OnboardingModel.recommended.intersection(all)
        _preset = State(initialValue: model.chosen == recommended ? .recommended : (model.chosen == all ? .everything : .custom))
    }

    var body: some View {
        VStack(spacing: 0) {
            // The real traffic lights sit here.
            Color.clear.frame(height: 40)
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    switch step {
                    case .welcome: welcome
                    case .choose: choose
                    case .permissions: permissions
                    case .done: done
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                bottomBar
            }
            .padding(.top, 4)
            .padding(.horizontal, 40)
            .padding(.bottom, 28)
        }
        .frame(width: 760, height: 580)
        .background(AS.window)
        .ignoresSafeArea()
        .allSetWindowStyle()
    }

    private func go(_ next: Step) {
        if let animation = OmniStyle.motion() { withAnimation(animation) { step = next } } else { step = next }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        ZStack {
            dots
            HStack(spacing: 8) {
                leadingButton
                Spacer(minLength: 0)
                trailingButtons
            }
        }
        .frame(height: 34)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item == step ? Color.white : Color.white.opacity(0.28))
                    .frame(width: item == step ? 18 : 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(L10n.OnboardingUI.step(step.rawValue + 1, Step.allCases.count))
    }

    @ViewBuilder private var leadingButton: some View {
        switch step {
        case .welcome: Color.clear.frame(width: 70, height: 1)
        case .choose: backButton(.welcome)
        case .permissions: backButton(.choose)
        case .done: backButton(.permissions)
        }
    }

    private func backButton(_ target: Step) -> some View {
        Button(L10n.Common.back) { go(target) }
            .buttonStyle(BackButtonStyle())
            .keyboardShortcut(.cancelAction)
    }

    @ViewBuilder private var trailingButtons: some View {
        switch step {
        case .welcome:
            Button(L10n.Onboarding.getStarted) { go(.choose) }
                .buttonStyle(.asLargePrimary).keyboardShortcut(.defaultAction)
        case .choose:
            Button(L10n.Common.continue) { applyChoice(); go(.permissions) }
                .buttonStyle(.asLargePrimary).keyboardShortcut(.defaultAction)
        case .permissions:
            Button(L10n.Common.continue) { go(.done) }
                .buttonStyle(.asLargePrimary).keyboardShortcut(.defaultAction)
        case .done:
            Button(L10n.OnboardingUI.openSettings) { onFinish(true) }
                .buttonStyle(.asLargePrimary).keyboardShortcut(.defaultAction)
        }
    }

    private func heading(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 24, weight: .bold)).tracking(-0.3).accessibilityAddTraits(.isHeader)
            Text(body)
                .font(.system(size: 14)).lineSpacing(3).foregroundStyle(AS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 1 — Welcome

    private var welcome: some View {
        VStack(spacing: 30) {
            iconGrid
            VStack(spacing: 10) {
                Text(L10n.OnboardingUI.welcomeTitle)
                    .font(.system(size: 34, weight: .bold)).tracking(-0.6)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.OnboardingUI.welcomeBody)
                    .font(.system(size: 16)).lineSpacing(4).foregroundStyle(AS.textBody)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    LineIcon(ASIcon.lock, size: 12, lineWidth: 1.8, color: AS.textSecondary)
                    Text(L10n.Onboarding.staysOnMac)
                }
                .font(.system(size: 13))
                .foregroundStyle(AS.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconGrid: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 14) {
            ForEach(FeatureLook.designOrder, id: \.self) { id in
                FeatureIcon(id, size: 56)
            }
        }
        .padding(18)
        .frame(width: 520)
        .background(shape.fill(Color.white.opacity(0.06)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        .overlay {
            // Inner highlight along the top edge.
            shape.inset(by: 1).stroke(Color.white.opacity(0.10), lineWidth: 1)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.06)))
        }
        .accessibilityHidden(true)
    }

    // MARK: 2 — Choose features

    private var choose: some View {
        let features = services.sidebarFeatures(includingHidden: false)
        let loved = OverviewPane.mostLoved.compactMap { id in features.first { $0.id == id } }
        let others = features.filter { !OverviewPane.mostLoved.contains($0.id) }
        return VStack(alignment: .leading, spacing: 20) {
            heading(L10n.OnboardingUI.featuresTitle, L10n.OnboardingUI.featuresBody)
            ASSegmented(L10n.OnboardingUI.preset, selection: Binding(get: { preset }, set: choosePreset), options: [
                (Preset.recommended, L10n.Onboarding.recommended),
                (Preset.everything, L10n.Onboarding.everything),
                (Preset.custom, L10n.OnboardingUI.letMeChoose),
            ], size: .wide)
            HStack(alignment: .top, spacing: 14) {
                featureColumn(L10n.AllSet.mostLoved, loved)
                featureColumn(L10n.AllSet.moreFeatures, others)
            }
            .padding(.top, -6)
        }
    }

    private func choosePreset(_ value: Preset) {
        preset = value
        switch value {
        case .recommended: model.chooseRecommended()
        case .everything: model.chooseEverything()
        case .custom: break
        }
    }

    @ViewBuilder private func featureColumn(_ title: String, _ features: [any Feature]) -> some View {
        if features.isEmpty {
            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
        } else {
            ASSection(title) {
                ForEach(features, id: \.id) { featureRow($0) }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func featureRow(_ feature: any Feature) -> some View {
        let isOn = model.chosen.contains(feature.id)
        return HStack(spacing: 10) {
            if isOn {
                FeatureIcon(feature.id, size: 24, fallbackSymbol: feature.symbolName)
            } else {
                OffFeatureIcon(id: feature.id, size: 24, fallbackSymbol: feature.symbolName)
            }
            Text(feature.sidebarName)
                .font(AS.body)
                .foregroundStyle(isOn ? AS.text : AS.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            ASSwitch(feature.displayName, isOn: Binding(get: { isOn }, set: { on in
                model.set(on, feature.id)
                preset = .custom
            }))
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .frame(height: 34)
        .help(feature.summary)
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
        let missing = required.contains { services.permissions.state(of: $0) != .granted }
        return VStack(alignment: .leading, spacing: 20) {
            heading(L10n.Onboarding.permissionsTitle, L10n.OnboardingUI.permissionsBody)
            if required.isEmpty && optional.isEmpty {
                ASCard(padding: 12) {
                    Text(L10n.OnboardingUI.noPermissions).font(AS.body).foregroundStyle(AS.textBody)
                }
            } else {
                ASCard {
                    ASDividedStack {
                        ForEach(required) { permissionRow($0, optional: false) }
                        ForEach(optional) { permissionRow($0, optional: true) }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    LineIcon(ASIcon.lock, size: 12, lineWidth: 1.8, color: AS.textSecondary)
                    Text(L10n.OnboardingUI.permissionsFootnote)
                }
                .font(.system(size: 12))
                .foregroundStyle(AS.textSecondary)
                if missing {
                    HStack(spacing: 8) {
                        Text(L10n.OnboardingUI.reopenNote)
                            .font(AS.footnote).foregroundStyle(AS.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(L10n.OnboardingUI.reopen) { Self.relaunch() }
                            .buttonStyle(ASButtonStyle(.secondary, height: 22, fontSize: 12))
                    }
                }
            }
            .padding(.leading, 12)
        }
    }

    private func permissionRow(_ permission: Permission, optional: Bool) -> some View {
        let state = services.permissions.state(of: permission)
        return HStack(spacing: 12) {
            LineIconTile(Self.icon(of: permission), size: 30, iconSize: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(permission.displayName).font(.system(size: 14, weight: .semibold)).foregroundStyle(AS.text)
                    Text(optional ? L10n.AllSet.optional : requiredLabel(permission))
                        .font(AS.footnote).foregroundStyle(AS.textTertiary).lineLimit(1)
                }
                Text(Self.why(permission))
                    .font(.system(size: 12)).lineSpacing(2).foregroundStyle(AS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            permissionStatus(permission, state: state, optional: optional)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 68)
        .contextMenu {
            if state == .denied {
                Button(L10n.Permissions.resetAndAskAgain) { Task { _ = await services.permissions.resetAndRequest(permission) } }
            }
        }
    }

    @ViewBuilder private func permissionStatus(_ permission: Permission, state: PermissionState, optional: Bool) -> some View {
        if state == .granted {
            ASStatusLabel(.good, L10n.AllSet.allowed)
        } else if optional && state == .notDetermined && permission.hasSystemPrompt {
            Text(L10n.AllSet.askedOnFirstUse).font(.system(size: 12)).foregroundStyle(AS.textSecondary)
        } else {
            HStack(spacing: 10) {
                ASStatusLabel(.warning, L10n.AllSet.needsPermission)
                Button(L10n.AllSet.allowEllipsis) { Task { _ = await services.permissions.request(permission) } }
                    .buttonStyle(.asPrimary)
            }
        }
    }

    /// "Required", or "Required for Screenshots" when only one or two chosen features need it.
    private func requiredLabel(_ permission: Permission) -> String {
        let users = services.sidebarFeatures(includingHidden: false)
            .filter { model.chosen.contains($0.id) && $0.requiredPermissions.contains(permission) }
            .map(\.sidebarName)
        guard users.count <= 2, let list = ListFormatter().string(from: users), !users.isEmpty else { return L10n.AllSet.required }
        return L10n.OnboardingUI.requiredFor(list)
    }

    private static func icon(of permission: Permission) -> String {
        switch permission {
        case .accessibility: ASIcon.accessibility
        case .screenRecording: ASIcon.screen
        case .microphone: ASIcon.microphone
        }
    }

    private static func why(_ permission: Permission) -> String {
        switch permission {
        case .accessibility: L10n.OnboardingUI.accessibilityWhy
        case .screenRecording: L10n.OnboardingUI.screenRecordingWhy
        case .microphone: L10n.OnboardingUI.microphoneWhy
        }
    }

    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    // MARK: 4 — Done

    private struct TryRow: Identifiable {
        let id: String
        let feature: FeatureID?
        let symbol: String
        let title: String
        let keys: String?
        let gesture: String?
    }

    /// Up to three things to try: chosen features with a shortcut first, then
    /// ones with a gesture; the control panel if nothing was chosen.
    private var tryRows: [TryRow] {
        let lookup = ShortcutLookup(services: services)
        let chosen = services.sidebarFeatures(includingHidden: false).filter { model.chosen.contains($0.id) }
        var keyed: [TryRow] = []
        var gestured: [TryRow] = []
        for feature in chosen {
            if let action = feature.declaredHotkeys.first, let text = lookup.text(for: action.id) {
                keyed.append(TryRow(id: action.id, feature: feature.id, symbol: feature.symbolName, title: action.title, keys: text, gesture: nil))
            } else if let gesture = feature.gestures.first {
                gestured.append(TryRow(id: feature.id.rawValue, feature: feature.id, symbol: feature.symbolName,
                                       title: gesture.title, keys: nil, gesture: gesture.gesture))
            }
        }
        var rows = Array((keyed + gestured).prefix(3))
        if rows.isEmpty, let panel = lookup.text(for: AppHotkeys.controlPanel.id) {
            rows.append(TryRow(id: AppHotkeys.controlPanel.id, feature: nil, symbol: "square.grid.3x3.square",
                               title: L10n.App.openControlPanelAction, keys: panel, gesture: nil))
        }
        return rows
    }

    private var done: some View {
        let rows = tryRows
        let login = services.launchAtLogin
        return VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(AS.accent)
                        .shadow(color: AS.accent.opacity(0.45), radius: 14, y: 10)
                    LineIcon("M3.5 8.5l3 3 6-7", size: 30, lineWidth: 2.4, color: .white)
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
                Text(L10n.OnboardingUI.doneTitle)
                    .font(.system(size: 30, weight: .bold)).tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.OnboardingUI.doneBody).font(.system(size: 14)).foregroundStyle(AS.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            if !rows.isEmpty {
                ASCard {
                    ASDividedStack {
                        ForEach(rows) { row in
                            HStack(spacing: 12) {
                                if let id = row.feature {
                                    FeatureIcon(id, size: 28, fallbackSymbol: row.symbol)
                                } else {
                                    LineIconTile(ASIcon.overview, size: 28, iconSize: 16)
                                }
                                Text(row.title).font(.system(size: 13.5)).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let keys = row.keys {
                                    KeyCaps(keys, spacing: 4)
                                } else if let gesture = row.gesture {
                                    Text(gesture).font(.system(size: 12)).foregroundStyle(AS.textSecondary).lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 46)
                        }
                    }
                }
            }
            ASCard {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 12) {
                        Text(L10n.AllSet.openAtLogin).font(.system(size: 13.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ASSwitch(L10n.AllSet.openAtLogin, isOn: Binding(
                            get: { login.isEnabled || login.needsApproval },
                            set: { login.setEnabled($0) }
                        ))
                    }
                    if login.needsApproval {
                        Text(L10n.SettingsUI.approveLoginItem).font(AS.footnote).foregroundStyle(AS.orange)
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
            }
        }
    }
}

/// A feature tile without its color, for features that are off.
private struct OffFeatureIcon: View {
    let id: FeatureID
    let size: CGFloat
    let fallbackSymbol: String

    var body: some View {
        GlassTile(size: size) {
            if let look = FeatureLook.of(id) {
                FeatureGlyph(look.glyph, color: Color(hex: 0x8E8E93))
                    .frame(width: (size * 0.73).rounded(), height: (size * 0.73).rounded())
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x8E8E93))
            }
        }
    }
}

/// The design's Back button: 34 pt, soft fill, medium weight.
private struct BackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AS.text)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AS.controlFill))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Rectangle())
    }
}
