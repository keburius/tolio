import OmniCore
import OmniPlatform
import SwiftUI

/// Startup, language, feel, version, reset everything.
struct GeneralPane: View {
    let services: AppServices
    let onShowOnboarding: () -> Void
    @State private var confirmReset = false

    private var launchAtLogin: LaunchAtLogin { services.launchAtLogin }

    var body: some View {
        PageScaffold(L10n.SettingsUI.general) {
            ASSection(L10n.AllSet.startup) {
                ASToggleRow(L10n.AllSet.openAtLogin, isOn: Binding(
                    get: { launchAtLogin.isEnabled || launchAtLogin.needsApproval },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .settingsAnchor("general.login")
                if launchAtLogin.needsApproval {
                    ASRow(L10n.SettingsUI.approveLoginItem) {
                        Button(L10n.SettingsUI.openLoginItems) { launchAtLogin.openLoginItemsSettings() }.buttonStyle(.asSecondary)
                    }
                }
                if let error = launchAtLogin.lastError {
                    ASRow(error)
                }
                ASRow(L10n.AllSet.setupGuide, subtitle: L10n.AllSet.setupGuideDetail) {
                    Button(L10n.SettingsUI.openSetupGuide, action: onShowOnboarding).buttonStyle(.asSecondary)
                }
                .settingsAnchor("general.setup")
            }
            ASSection(L10n.SettingsUI.language, footer: L10n.SettingsUI.languageNote) {
                ASRow(L10n.SettingsUI.language) {
                    ASPopUp(L10n.SettingsUI.language, selection: .constant(0), options: [(0, L10n.SettingsUI.english)])
                }
            }
            .settingsAnchor("general.language")
            ASSection(L10n.AllSet.feel) {
                ASToggleRow(L10n.AllSet.hapticTaps, subtitle: L10n.AllSet.hapticTapsDetail, isOn: services.settings.binding(AppFeel.hapticsKey))
                ASToggleRow(L10n.AllSet.tickSounds, subtitle: L10n.AllSet.tickSoundsDetail, isOn: services.settings.binding(AppFeel.ticksKey))
            }
            .settingsAnchor("general.feel")
            ASSection(L10n.AllSet.about) {
                ASRow(L10n.SettingsUI.version) {
                    Text(Bundle.main.versionString).font(AS.body).monospacedDigit().foregroundStyle(AS.textSecondary)
                }
            }
            HStack {
                Spacer()
                Button(L10n.SettingsUI.resetAllSettings) { confirmReset = true }
                    .buttonStyle(.asSecondary)
                    .confirmationDialog(L10n.SettingsUI.resetAllQuestion, isPresented: $confirmReset) {
                        Button(L10n.Common.reset, role: .destructive) { services.resetAllSettings() }
                        Button(L10n.Common.cancel, role: .cancel) {}
                    } message: {
                        Text(L10n.SettingsUI.resetAllExplanation)
                    }
            }
            .settingsAnchor("general.reset")
        }
        .onAppear { launchAtLogin.refresh() }
    }
}

extension Bundle {
    var versionString: String {
        let short = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))" // l10n-ignore
    }
}
