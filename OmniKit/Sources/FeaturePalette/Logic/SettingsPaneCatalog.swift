import Foundation
import OmniCore

/// A System Settings pane the palette can open.
public struct SettingsPane: Sendable, Hashable {
    public let title: String
    public let url: URL
    public let keywords: [String]
}

/// Known System Settings panes, filtered to those installed on this Mac.
///
/// macOS has no API that lists panes with their localized names, so titles
/// are curated and keyed by the pane's extension bundle id. Panes whose
/// extension isn't installed are dropped, so the list follows the OS version.
public enum SettingsPaneCatalog {
    public static let extensionsDirectory = URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions")
    static let settingsExtensionPoint = "com.apple.Settings.extension.ui"

    /// Panes available on this system. If discovery finds nothing (layout
    /// changed), falls back to the full curated list.
    public static func available(in directory: URL = extensionsDirectory) -> [SettingsPane] {
        let installed = installedSettingsExtensions(in: directory)
        let curated = installed.isEmpty ? extensionPanes : extensionPanes.filter { installed.contains($0.id) }
        return curated.map { pane(title: $0.title, target: $0.id, keywords: $0.keywords) } + privacyPanes
    }

    /// Bundle ids of installed System Settings extensions.
    static func installedSettingsExtensions(in directory: URL) -> Set<String> {
        guard let items = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        var ids = Set<String>()
        for item in items where item.pathExtension == "appex" {
            guard let info = NSDictionary(contentsOf: item.appendingPathComponent("Contents/Info.plist")),
                  let id = info["CFBundleIdentifier"] as? String,
                  let attributes = info["EXAppExtensionAttributes"] as? [String: Any],
                  attributes["EXExtensionPointIdentifier"] as? String == settingsExtensionPoint
            else { continue }
            ids.insert(id)
        }
        return ids
    }

    private static func pane(title: String, target: String, keywords: [String]) -> SettingsPane {
        // Constant-derived URL strings; cannot fail.
        SettingsPane(title: title, url: URL(string: "x-apple.systempreferences:\(target)")!, keywords: keywords)
    }

    /// A pane by its extension id, with macOS's own English name for it.
    /// Titles are data matching System Settings, not Omni's own text.
    struct Entry {
        let id: String
        let title: String
        let keywords: [String]

        init(_ id: String, _ title: String, _ keywords: [String]) {
            self.id = id
            self.title = title
            self.keywords = keywords
        }
    }

    static let extensionPanes: [Entry] = [
        Entry("com.apple.wifi-settings-extension", "Wi-Fi", ["wifi", "wireless", "network"]),
        Entry("com.apple.BluetoothSettings", "Bluetooth", []),
        Entry("com.apple.Network-Settings.extension", "Network", ["ethernet", "dns", "proxy", "ip"]),
        Entry("com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension", "VPN", []),
        Entry("com.apple.Notifications-Settings.extension", "Notifications", ["alerts", "banners"]),
        Entry("com.apple.Sound-Settings.extension", "Sound", ["volume", "audio", "output", "input", "microphone"]),
        Entry("com.apple.Focus-Settings.extension", "Focus", ["do not disturb", "dnd"]),
        Entry("com.apple.Screen-Time-Settings.extension", "Screen Time", ["parental"]),
        Entry("com.apple.systempreferences.GeneralSettings", "General", []),
        Entry("com.apple.SystemProfiler.AboutExtension", "About This Mac", ["serial", "model", "version", "about"]),
        Entry("com.apple.Software-Update-Settings.extension", "Software Update", ["upgrade", "macos", "update"]),
        Entry("com.apple.settings.Storage", "Storage", ["disk", "space"]),
        Entry("com.apple.AirDrop-Handoff-Settings.extension", "AirDrop & Handoff", ["airplay", "continuity"]),
        Entry("com.apple.LoginItems-Settings.extension", "Login Items & Extensions", ["startup", "launch at login"]),
        Entry("com.apple.Localization-Settings.extension", "Language & Region", ["locale", "language"]),
        Entry("com.apple.Date-Time-Settings.extension", "Date & Time", ["clock", "time zone"]),
        Entry("com.apple.Sharing-Settings.extension", "Sharing", ["file sharing", "screen sharing", "remote login", "ssh", "computer name"]),
        Entry("com.apple.Time-Machine-Settings.extension", "Time Machine", ["backup"]),
        Entry("com.apple.Transfer-Reset-Settings.extension", "Transfer or Reset", ["erase"]),
        Entry("com.apple.Startup-Disk-Settings.extension", "Startup Disk", ["boot"]),
        Entry("com.apple.Appearance-Settings.extension", "Appearance", ["dark mode", "light mode", "accent color"]),
        Entry("com.apple.Accessibility-Settings.extension", "Accessibility", ["voiceover", "zoom"]),
        Entry("com.apple.ControlCenter-Settings.extension", "Control Center", ["menu bar"]),
        Entry("com.apple.Siri-Settings.extension", "Apple Intelligence & Siri", ["siri", "assistant"]),
        Entry("com.apple.Spotlight-Settings.extension", "Spotlight", ["search"]),
        Entry("com.apple.settings.PrivacySecurity.extension", "Privacy & Security", ["permissions", "filevault", "gatekeeper"]),
        Entry("com.apple.Desktop-Settings.extension", "Desktop & Dock", ["dock", "stage manager", "mission control", "hot corners"]),
        Entry("com.apple.Displays-Settings.extension", "Displays", ["resolution", "monitor", "night shift", "brightness"]),
        Entry("com.apple.Wallpaper-Settings.extension", "Wallpaper", ["background"]),
        Entry("com.apple.ScreenSaver-Settings.extension", "Screen Saver", []),
        Entry("com.apple.Battery-Settings.extension", "Battery", ["energy", "power", "low power mode"]),
        Entry("com.apple.Lock-Screen-Settings.extension", "Lock Screen", ["sleep"]),
        Entry("com.apple.Touch-ID-Settings.extension", "Touch ID & Password", ["fingerprint", "password"]),
        Entry("com.apple.Users-Groups-Settings.extension", "Users & Groups", ["accounts", "guest"]),
        Entry("com.apple.Passwords-Settings.extension", "Passwords", []),
        Entry("com.apple.Internet-Accounts-Settings.extension", "Internet Accounts", ["mail", "email", "calendar"]),
        Entry("com.apple.Game-Center-Settings.extension", "Game Center", []),
        Entry("com.apple.Game-Controller-Settings.extension", "Game Controllers", ["gamepad"]),
        Entry("com.apple.WalletSettingsExtension", "Wallet & Apple Pay", ["cards"]),
        Entry("com.apple.Keyboard-Settings.extension", "Keyboard", ["shortcuts", "input sources", "dictation"]),
        Entry("com.apple.Mouse-Settings.extension", "Mouse", ["scroll", "pointer"]),
        Entry("com.apple.Trackpad-Settings.extension", "Trackpad", ["gestures", "tap to click"]),
        Entry("com.apple.Print-Scan-Settings.extension", "Printers & Scanners", ["printer"]),
        Entry("com.apple.systempreferences.AppleIDSettings", "Apple Account", ["icloud", "apple id"]),
        Entry("com.apple.Family-Settings.extension", "Family", ["family sharing"]),
        Entry("com.apple.Profiles-Settings.extension", "Device Management", ["profiles", "mdm"]),
        Entry("com.apple.CD-DVD-Settings.extension", "CDs & DVDs", []),
    ]

    /// Privacy lists inside Privacy & Security (stable anchors since macOS 10.x).
    static let privacyPanes: [SettingsPane] = [
        ("Accessibility", "Privacy_Accessibility"), ("Screen & System Audio Recording", "Privacy_ScreenCapture"),
        ("Full Disk Access", "Privacy_AllFiles"), ("Microphone", "Privacy_Microphone"),
        ("Camera", "Privacy_Camera"), ("Location Services", "Privacy_LocationServices"),
        ("Input Monitoring", "Privacy_ListenEvent"), ("Automation", "Privacy_Automation"),
        ("App Management", "Privacy_AppBundles"),
    ].map { title, anchor in
        pane(title: L10n.Launcher.privacyPane(title), target: "com.apple.preference.security?\(anchor)", keywords: ["privacy", "permission"])
    }
}
