import OmniPlatform
import SwiftUI

/// Launch at login and app-level actions.
struct GeneralPane: View {
    let launchAtLogin: LaunchAtLogin
    let onShowOnboarding: () -> Void

    var body: some View {
        Form {
            Section {
                Toggle("Open Omni at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled || launchAtLogin.needsApproval },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                if launchAtLogin.needsApproval {
                    HStack {
                        Text("Approve Omni in Login Items to finish.").foregroundStyle(.orange)
                        Button("Open Login Items") { launchAtLogin.openLoginItemsSettings() }
                    }
                }
                if let error = launchAtLogin.lastError {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
            }
            Section {
                Button("Show Setup Guide…", action: onShowOnboarding)
            }
            Section {
                LabeledContent("Version", value: Bundle.main.versionString)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin.refresh() }
    }
}

extension Bundle {
    var versionString: String {
        let short = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}
