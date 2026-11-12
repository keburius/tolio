import OmniCore
import OmniPlatform
import SwiftUI

/// Open at login, setup guide, language, version, reset everything.
struct GeneralPane: View {
    let services: AppServices
    let onShowOnboarding: () -> Void
    @State private var confirmReset = false

    private var launchAtLogin: LaunchAtLogin { services.launchAtLogin }

    var body: some View {
        Form {
            Section {
                Toggle(L10n.SettingsUI.openAtLogin, isOn: Binding(
                    get: { launchAtLogin.isEnabled || launchAtLogin.needsApproval },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                if launchAtLogin.needsApproval {
                    HStack {
                        Text(L10n.SettingsUI.approveLoginItem).foregroundStyle(.orange)
                        Button(L10n.SettingsUI.openLoginItems) { launchAtLogin.openLoginItemsSettings() }
                    }
                }
                if let error = launchAtLogin.lastError {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
            }
            .settingsAnchor("general.login")
            Section {
                Button(L10n.SettingsUI.openSetupGuide, action: onShowOnboarding)
            }
            .settingsAnchor("general.setup")
            Section {
                Picker(L10n.SettingsUI.language, selection: .constant(0)) {
                    Text(L10n.SettingsUI.english).tag(0)
                }
                .disabled(true)
                Text(L10n.SettingsUI.languageNote).font(.caption).foregroundStyle(.secondary)
            }
            .settingsAnchor("general.language")
            Section {
                LabeledContent(L10n.SettingsUI.version, value: Bundle.main.versionString)
            }
            Section {
                Button(L10n.SettingsUI.resetAllSettings) { confirmReset = true }
                    .confirmationDialog(L10n.SettingsUI.resetAllQuestion, isPresented: $confirmReset) {
                        Button(L10n.Common.reset, role: .destructive) { services.resetAllSettings() }
                        Button(L10n.Common.cancel, role: .cancel) {}
                    } message: {
                        Text(L10n.SettingsUI.resetAllExplanation)
                    }
            }
            .settingsAnchor("general.reset")
        }
        .formStyle(.grouped)
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
