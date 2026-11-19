import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Energy Mode's settings: status and manual controls, display option, app list.
struct KeepAwakeSettingsView: View {
    let feature: KeepAwakeFeature
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ASSection {
                ASRow(L10n.KeepAwake.status, subtitle: feature.statusText ?? L10n.Common.off) {
                    HStack(spacing: 8) {
                        Button(L10n.KeepAwake.commandOn) { feature.start(.indefinite) }
                            .buttonStyle(.asSecondary)
                        Menu {
                            ForEach(KeepAwakePolicy.presetMinutes, id: \.self) { minutes in
                                Button(KeepAwakePolicy.durationTitle(minutes: minutes)) { feature.start(minutes: minutes) }
                            }
                        } label: {
                            ASPopUpLabel(L10n.KeepAwake.forMenu)
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .accessibilityLabel(L10n.KeepAwake.stayAwakeFor)
                        Button(L10n.KeepAwake.stop) { feature.start(.off) }
                            .buttonStyle(.asSecondary)
                            .disabled(feature.currentSession == .off)
                    }
                }
                .settingsAnchor(KeepAwakeFeature.Anchor.status)
                ASToggleRow(L10n.KeepAwake.keepDisplayOn, isOn: Binding(
                    get: { settings.value(KeepAwakeFeature.displayKey) },
                    set: { feature.setKeepDisplayOn($0) }
                ))
                .settingsAnchor(KeepAwakeFeature.Anchor.display)
            }
            apps.settingsAnchor(KeepAwakeFeature.Anchor.apps)
        }
    }

    private var apps: some View {
        let rules = settings.value(KeepAwakeFeature.ruleAppsKey)
        return ASSection(L10n.KeepAwake.appsSection) {
            if rules.isEmpty {
                HStack(spacing: 12) {
                    Text(L10n.KeepAwake.noApps).font(AS.body).foregroundStyle(AS.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    addAppMenu(excluding: rules)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
            } else {
                ForEach(rules.sorted { $0.value < $1.value }, id: \.key) { bundleID, name in
                    ASRow(name) {
                        AppIcon(bundleID: bundleID)
                    } trailing: {
                        Button(L10n.Common.remove) { feature.setRule(bundleID, name: nil, enabled: false) }
                            .buttonStyle(.asSecondary)
                    }
                }
                HStack {
                    Spacer()
                    addAppMenu(excluding: rules)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
            }
        }
    }

    private func addAppMenu(excluding rules: [String: String]) -> some View {
        Menu {
            ForEach(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && rules[$0.bundleIdentifier ?? ""] == nil }
                .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }, id: \.processIdentifier) { app in
                Button(app.localizedName ?? L10n.KeepAwake.unnamedApp) {
                    if let id = app.bundleIdentifier { feature.setRule(id, name: app.localizedName, enabled: true) }
                }
            }
        } label: {
            ASPopUpLabel(L10n.Common.addApp)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(L10n.KeepAwake.addAppLabel)
    }
}

/// An app's icon by bundle ID, or a blank square if it isn't installed.
private struct AppIcon: View {
    let bundleID: String

    var body: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(AS.controlFill)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

/// The example at the top of the page: a ring with the cup inside and "Staying awake".
struct KeepAwakeHero: View {
    private static let tint = Color(hex: 0xB39A7B)

    var body: some View {
        ASStage(tint: Self.tint.opacity(0.25 / 0.30)) {
            HStack(spacing: 22) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: 254 / (2 * .pi * 54))
                        .stroke(Self.tint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    FeatureGlyph(.energyMode, color: Self.tint).frame(width: 60, height: 60)
                }
                .frame(width: 108, height: 108)
                .frame(width: 124, height: 124)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.KeepAwake.heroTitle).font(AS.font(17, .bold)).foregroundStyle(.white)
                    Text(L10n.KeepAwake.heroDetail).font(AS.body).foregroundStyle(AS.textBody)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.KeepAwake.heroLabel)
        .accessibilityAddTraits(.isImage)
    }
}
