import Foundation

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

    struct Entry {
        let id: String
        let title: String
        let keywords: [String]
    }

    static let extensionPanes: [Entry] = [
        Entry(id: "com.apple.wifi-settings-extension", title: "Wi-Fi", keywords: ["wifi", "wireless", "network"]),
        Entry(id: "com.apple.BluetoothSettings", title: "Bluetooth", keywords: []),
        Entry(id: "com.apple.Network-Settings.extension", title: "Network", keywords: ["ethernet", "dns", "proxy", "ip"]),
        Entry(id: "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension", title: "VPN", keywords: []),
        Entry(id: "com.apple.Notifications-Settings.extension", title: "Notifications", keywords: ["alerts", "banners"]),
        Entry(id: "com.apple.Sound-Settings.extension", title: "Sound", keywords: ["volume", "audio", "output", "input", "microphone"]),
        Entry(id: "com.apple.Focus-Settings.extension", title: "Focus", keywords: ["do not disturb", "dnd"]),
        Entry(id: "com.apple.Screen-Time-Settings.extension", title: "Screen Time", keywords: ["parental"]),
        Entry(id: "com.apple.systempreferences.GeneralSettings", title: "General", keywords: []),
        Entry(id: "com.apple.SystemProfiler.AboutExtension", title: "About This Mac", keywords: ["serial", "model", "version", "about"]),
        Entry(id: "com.apple.Software-Update-Settings.extension", title: "Software Update", keywords: ["upgrade", "macos", "update"]),
        Entry(id: "com.apple.settings.Storage", title: "Storage", keywords: ["disk", "space"]),
        Entry(id: "com.apple.AirDrop-Handoff-Settings.extension", title: "AirDrop & Handoff", keywords: ["airplay", "continuity"]),
        Entry(id: "com.apple.LoginItems-Settings.extension", title: "Login Items & Extensions", keywords: ["startup", "launch at login"]),
        Entry(id: "com.apple.Localization-Settings.extension", title: "Language & Region", keywords: ["locale", "language"]),
        Entry(id: "com.apple.Date-Time-Settings.extension", title: "Date & Time", keywords: ["clock", "time zone"]),
        Entry(id: "com.apple.Sharing-Settings.extension", title: "Sharing", keywords: ["file sharing", "screen sharing", "remote login", "ssh", "computer name"]),
        Entry(id: "com.apple.Time-Machine-Settings.extension", title: "Time Machine", keywords: ["backup"]),
        Entry(id: "com.apple.Transfer-Reset-Settings.extension", title: "Transfer or Reset", keywords: ["erase"]),
        Entry(id: "com.apple.Startup-Disk-Settings.extension", title: "Startup Disk", keywords: ["boot"]),
        Entry(id: "com.apple.Appearance-Settings.extension", title: "Appearance", keywords: ["dark mode", "light mode", "accent color"]),
        Entry(id: "com.apple.Accessibility-Settings.extension", title: "Accessibility", keywords: ["voiceover", "zoom"]),
        Entry(id: "com.apple.ControlCenter-Settings.extension", title: "Control Center", keywords: ["menu bar"]),
        Entry(id: "com.apple.Siri-Settings.extension", title: "Apple Intelligence & Siri", keywords: ["siri", "assistant"]),
        Entry(id: "com.apple.Spotlight-Settings.extension", title: "Spotlight", keywords: ["search"]),
        Entry(id: "com.apple.settings.PrivacySecurity.extension", title: "Privacy & Security", keywords: ["permissions", "filevault", "gatekeeper"]),
        Entry(id: "com.apple.Desktop-Settings.extension", title: "Desktop & Dock", keywords: ["dock", "stage manager", "mission control", "hot corners"]),
        Entry(id: "com.apple.Displays-Settings.extension", title: "Displays", keywords: ["resolution", "monitor", "night shift", "brightness"]),
        Entry(id: "com.apple.Wallpaper-Settings.extension", title: "Wallpaper", keywords: ["background"]),
        Entry(id: "com.apple.ScreenSaver-Settings.extension", title: "Screen Saver", keywords: []),
        Entry(id: "com.apple.Battery-Settings.extension", title: "Battery", keywords: ["energy", "power", "low power mode"]),
        Entry(id: "com.apple.Lock-Screen-Settings.extension", title: "Lock Screen", keywords: ["sleep"]),
        Entry(id: "com.apple.Touch-ID-Settings.extension", title: "Touch ID & Password", keywords: ["fingerprint", "password"]),
        Entry(id: "com.apple.Users-Groups-Settings.extension", title: "Users & Groups", keywords: ["accounts", "guest"]),
        Entry(id: "com.apple.Passwords-Settings.extension", title: "Passwords", keywords: []),
        Entry(id: "com.apple.Internet-Accounts-Settings.extension", title: "Internet Accounts", keywords: ["mail", "email", "calendar"]),
        Entry(id: "com.apple.Game-Center-Settings.extension", title: "Game Center", keywords: []),
        Entry(id: "com.apple.Game-Controller-Settings.extension", title: "Game Controllers", keywords: ["gamepad"]),
        Entry(id: "com.apple.WalletSettingsExtension", title: "Wallet & Apple Pay", keywords: ["cards"]),
        Entry(id: "com.apple.Keyboard-Settings.extension", title: "Keyboard", keywords: ["shortcuts", "input sources", "dictation"]),
        Entry(id: "com.apple.Mouse-Settings.extension", title: "Mouse", keywords: ["scroll", "pointer"]),
        Entry(id: "com.apple.Trackpad-Settings.extension", title: "Trackpad", keywords: ["gestures", "tap to click"]),
        Entry(id: "com.apple.Print-Scan-Settings.extension", title: "Printers & Scanners", keywords: ["printer"]),
        Entry(id: "com.apple.systempreferences.AppleIDSettings", title: "Apple Account", keywords: ["icloud", "apple id"]),
        Entry(id: "com.apple.Family-Settings.extension", title: "Family", keywords: ["family sharing"]),
        Entry(id: "com.apple.Profiles-Settings.extension", title: "Device Management", keywords: ["profiles", "mdm"]),
        Entry(id: "com.apple.CD-DVD-Settings.extension", title: "CDs & DVDs", keywords: []),
    ]

    /// Privacy lists inside Privacy & Security (stable anchors since macOS 10.x).
    static let privacyPanes: [SettingsPane] = [
        ("Accessibility", "Privacy_Accessibility"), ("Screen & System Audio Recording", "Privacy_ScreenCapture"),
        ("Full Disk Access", "Privacy_AllFiles"), ("Microphone", "Privacy_Microphone"),
        ("Camera", "Privacy_Camera"), ("Location Services", "Privacy_LocationServices"),
        ("Input Monitoring", "Privacy_ListenEvent"), ("Automation", "Privacy_Automation"),
        ("App Management", "Privacy_AppBundles"),
    ].map { title, anchor in
        pane(title: "Privacy: \(title)", target: "com.apple.preference.security?\(anchor)", keywords: ["privacy", "permission"])
    }
}
