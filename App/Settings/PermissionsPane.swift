import AppKit
import Carbon
import CoreBluetooth
import EventKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Every permission All Set can use, its live state, and a way to allow it.
struct PermissionsPane: View {
    let services: AppServices
    let navigation: SettingsNavigation
    @State private var extras: [ExtraPermission: PermissionState] = [:]

    var body: some View {
        PageScaffold(L10n.SettingsUI.permissions) {
            Text(L10n.AllSet.permissionsIntro)
                .font(AS.body).lineSpacing(3).foregroundStyle(AS.textBody)
                .fixedSize(horizontal: false, vertical: true)
            ASSection(footer: L10n.AllSet.permissionsFootnote) {
                ForEach(Permission.allCases) { permission in
                    let state = services.permissions.state(of: permission)
                    row(icon: icon(of: permission), title: permission.displayName, use: use(of: permission), state: state, askable: true) {
                        Task { _ = await services.permissions.request(permission) }
                    }
                    .settingsAnchor("permissions.\(permission.rawValue)")
                }
                ForEach(ExtraPermission.allCases, id: \.self) { extra in
                    row(icon: extra.icon, title: extra.title, use: extra.use, state: extras[extra] ?? .unknown, askable: false) { extra.openSettings() }
                }
            }
            HStack {
                Spacer()
                Button(L10n.AllSet.openSystemSettings) { ExtraPermission.openPrivacySettings(nil) }.buttonStyle(.asSecondary)
            }
            HStack(spacing: 6) {
                LineIcon(ASIcon.lock, size: 11, lineWidth: 1.8)
                Text(L10n.AllSet.neverConnects)
            }
            .font(AS.font(12))
            .foregroundStyle(AS.textSecondary)
            .padding(.leading, 12)
        }
        .task {
            // System Settings changes these behind our back; check while the page is open.
            while !Task.isCancelled {
                extras = Dictionary(uniqueKeysWithValues: ExtraPermission.allCases.map { ($0, $0.state) })
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func row(icon: String, title: String, use: String, state: PermissionState, askable: Bool, allow: @escaping () -> Void) -> some View {
        ASRow(title, subtitle: use) {
            LineIconTile(icon, size: 28, iconSize: 16)
        } trailing: {
            HStack(spacing: 10) {
                if state == .notDetermined && title == L10n.AllSet.music {
                    Text(L10n.AllSet.askedOnFirstUse).font(AS.font(12)).foregroundStyle(AS.textSecondary)
                } else {
                    PermissionStateLabel(state: state)
                }
                if state == .denied || (askable && state == .notDetermined) {
                    Button(L10n.AllSet.allowEllipsis, action: allow).buttonStyle(.asSecondary)
                }
            }
        }
    }

    private func icon(of permission: Permission) -> String {
        switch permission {
        case .accessibility: ASIcon.accessibility
        case .screenRecording: ASIcon.screen
        case .microphone: ASIcon.microphone
        }
    }

    private func use(of permission: Permission) -> String {
        switch permission {
        case .accessibility: L10n.AllSet.accessibilityUse
        case .screenRecording: L10n.AllSet.screenRecordingUse
        case .microphone: L10n.AllSet.microphoneUse
        }
    }
}

/// Permissions features ask for themselves (macOS prompts on first use);
/// shown here so everything is in one place.
enum ExtraPermission: CaseIterable {
    case calendars, reminders, bluetooth, music

    var title: String {
        switch self {
        case .calendars: L10n.AllSet.calendars
        case .reminders: L10n.AllSet.reminders
        case .bluetooth: L10n.AllSet.bluetooth
        case .music: L10n.AllSet.music
        }
    }

    var use: String {
        switch self {
        case .calendars: L10n.AllSet.calendarsUse
        case .reminders: L10n.AllSet.remindersUse
        case .bluetooth: L10n.AllSet.bluetoothUse
        case .music: L10n.AllSet.musicUse
        }
    }

    var icon: String {
        switch self {
        case .calendars: "M3 4h10v9H3zM3 6.8h10M5.5 2.5v2.5M10.5 2.5v2.5"
        case .reminders: "M4 4.5h.01M4 8h.01M4 11.5h.01M6.5 4.5h6M6.5 8h6M6.5 11.5h6"
        case .bluetooth: "M5 5l6 6-3 2.5v-11L11 5l-6 6"
        case .music: "M6 12.5V4l6.5-1.5V11M6 12.5a1.6 1.6 0 1 1-1.6-1.6M12.5 11a1.6 1.6 0 1 1-1.6-1.6"
        }
    }

    @MainActor var state: PermissionState {
        switch self {
        case .calendars: Self.eventState(.event)
        case .reminders: Self.eventState(.reminder)
        case .bluetooth:
            switch CBManager.authorization {
            case .allowedAlways: .granted
            case .notDetermined: .notDetermined
            case .denied, .restricted: .denied
            @unknown default: .unknown
            }
        case .music: Self.automationState()
        }
    }

    private static func eventState(_ type: EKEntityType) -> PermissionState {
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess, .writeOnly: .granted
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        @unknown default: .unknown
        }
    }

    /// Asks macOS (without prompting) whether we may control Music or Spotify.
    private static func automationState() -> PermissionState {
        var best = PermissionState.notDetermined
        for bundleID in ["com.apple.Music", "com.spotify.client"] { // l10n-ignore
            guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first != nil else { continue }
            var target = AEAddressDesc()
            let status: OSStatus = bundleID.withCString { pointer in
                guard AECreateDesc(DescType(typeApplicationBundleID), pointer, strlen(pointer), &target) == noErr else { return OSStatus(procNotFound) }
                defer { AEDisposeDesc(&target) }
                return AEDeterminePermissionToAutomateTarget(&target, AEEventClass(typeWildCard), AEEventID(typeWildCard), false)
            }
            switch status {
            case noErr: return .granted
            case OSStatus(errAEEventNotPermitted): best = .denied
            default: break
            }
        }
        return best
    }

    func openSettings() {
        switch self {
        case .calendars: Self.openPrivacySettings("Privacy_Calendars")
        case .reminders: Self.openPrivacySettings("Privacy_Reminders")
        case .bluetooth: Self.openPrivacySettings("Privacy_Bluetooth")
        case .music: Self.openPrivacySettings("Privacy_Automation")
        }
    }

    static func openPrivacySettings(_ anchor: String?) {
        var link = "x-apple.systempreferences:com.apple.preference.security" // l10n-ignore
        if let anchor { link += "?\(anchor)" }
        if let url = URL(string: link) { NSWorkspace.shared.open(url) }
    }
}
