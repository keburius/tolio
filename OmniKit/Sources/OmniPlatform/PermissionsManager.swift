import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import Darwin
import Observation
import OmniCore

/// Checks, requests, and deep-links macOS privacy permissions.
///
/// State is re-read on demand, and polled once a second only while a window
/// that shows permissions holds a monitoring token.
@MainActor
@Observable
public final class PermissionsManager: PermissionChecking {
    public private(set) var states: [Permission: PermissionState] = [:]
    /// Called after `refresh()` if any state changed.
    @ObservationIgnored public var onStatesChanged: (@MainActor () -> Void)?

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var monitorCount = 0
    @ObservationIgnored private var timer: Timer?
    private static let requestedKey = SettingKey<Set<Permission>>("permissions.requested", default: [])

    public init(settings: SettingsStore) {
        self.settings = settings
        refresh()
    }

    public func state(of permission: Permission) -> PermissionState {
        states[permission] ?? readState(permission)
    }

    /// Re-reads all states and notifies `onStatesChanged` on any change.
    public func refresh() {
        var fresh: [Permission: PermissionState] = [:]
        for permission in Permission.allCases { fresh[permission] = readState(permission) }
        guard fresh != states else { return }
        let hadStates = !states.isEmpty
        states = fresh
        if hadStates { onStatesChanged?() }
    }

    /// Shows the system prompt where one exists, otherwise opens System Settings.
    public func request(_ permission: Permission) async -> PermissionState {
        var requested = settings.value(Self.requestedKey)
        let firstRequest = requested.insert(permission).inserted
        settings.set(requested, for: Self.requestedKey)

        switch permission {
        case .accessibility:
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            if !AXIsProcessTrustedWithOptions(options) && !firstRequest { openSettings(for: permission) }
        case .screenRecording:
            if !CGRequestScreenCaptureAccess() && !firstRequest { openSettings(for: permission) }
        case .microphone:
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .notDetermined: _ = await AVCaptureDevice.requestAccess(for: .audio)
            case .authorized: break
            default: openSettings(for: permission)
            }
        case .fullDiskAccess, .appManagement:
            openSettings(for: permission)
        }
        refresh()
        return state(of: permission)
    }

    public func openSettings(for permission: Permission) {
        NSWorkspace.shared.open(permission.settingsURL)
    }

    /// Starts 1 s polling. Balance every call with `stopMonitoring()`.
    public func startMonitoring() {
        monitorCount += 1
        refresh()
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stopMonitoring() {
        monitorCount = max(0, monitorCount - 1)
        guard monitorCount == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    private func readState(_ permission: Permission) -> PermissionState {
        let requested = settings.value(Self.requestedKey).contains(permission)
        switch permission {
        case .accessibility:
            return PermissionStateMapping.fromTrusted(AXIsProcessTrusted(), everRequested: requested)
        case .screenRecording:
            return PermissionStateMapping.fromTrusted(CGPreflightScreenCaptureAccess(), everRequested: requested)
        case .microphone:
            return PermissionStateMapping.fromAVAuthorization(
                rawValue: AVCaptureDevice.authorizationStatus(for: .audio).rawValue
            )
        case .fullDiskAccess:
            return PermissionStateMapping.fullDiskAccess(probes: Self.fullDiskAccessProbePaths.map(Self.probe))
        case .appManagement:
            return .unknown // No API reports App Management.
        }
    }

    /// Files readable only with Full Disk Access.
    private static var fullDiskAccessProbePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/com.apple.TCC/TCC.db",
            "\(home)/Library/Safari/Bookmarks.plist",
            "/Library/Application Support/com.apple.TCC/TCC.db",
        ]
    }

    private static func probe(_ path: String) -> AccessProbeResult {
        let fd = open(path, O_RDONLY)
        if fd >= 0 {
            close(fd)
            return .readable
        }
        return errno == ENOENT ? .missing : .permissionDenied
    }
}
