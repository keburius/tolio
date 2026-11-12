import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Keep Awake's settings: status and manual controls, display option, app list.
struct KeepAwakeSettingsView: View {
    let feature: KeepAwakeFeature
    let settings: SettingsStore

    var body: some View {
        LabeledContent(L10n.KeepAwake.status) {
            Text(feature.statusText ?? L10n.Common.off).foregroundStyle(feature.isHolding ? .green : .secondary)
        }
        .settingsAnchor(KeepAwakeFeature.Anchor.status)
        HStack {
            Button(L10n.KeepAwake.commandOn) { feature.start(.indefinite) }
            Menu(L10n.KeepAwake.forMenu) {
                ForEach(KeepAwakePolicy.presetMinutes, id: \.self) { minutes in
                    Button(KeepAwakePolicy.durationTitle(minutes: minutes)) { feature.start(minutes: minutes) }
                }
            }
            .fixedSize()
            Button(L10n.KeepAwake.stop) { feature.start(.off) }.disabled(feature.statusText == nil)
        }
        Toggle(L10n.KeepAwake.keepDisplayOn, isOn: Binding(
            get: { settings.value(KeepAwakeFeature.displayKey) },
            set: { feature.setKeepDisplayOn($0) }
        ))
        .settingsAnchor(KeepAwakeFeature.Anchor.display)
        Section(L10n.KeepAwake.appsSection) {
            let rules = settings.value(KeepAwakeFeature.ruleAppsKey)
            if rules.isEmpty {
                EmptyState(symbol: "app.badge.checkmark", message: L10n.KeepAwake.noApps)
            }
            ForEach(rules.sorted { $0.value < $1.value }, id: \.key) { bundleID, name in
                HStack {
                    Text(name)
                    Spacer()
                    Button(L10n.Common.remove) { feature.setRule(bundleID, name: nil, enabled: false) }.buttonStyle(.borderless)
                }
            }
            addAppMenu(excluding: rules)
        }
        .settingsAnchor(KeepAwakeFeature.Anchor.apps)
    }

    private func addAppMenu(excluding rules: [String: String]) -> some View {
        Menu(L10n.Common.addApp) {
            ForEach(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && rules[$0.bundleIdentifier ?? ""] == nil }
                .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }, id: \.processIdentifier) { app in
                Button(app.localizedName ?? L10n.KeepAwake.unnamedApp) {
                    if let id = app.bundleIdentifier { feature.setRule(id, name: app.localizedName, enabled: true) }
                }
            }
        }
        .fixedSize()
    }
}
