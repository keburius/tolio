import Foundation

/// macOS's "Drag windows to top of screen to enter Mission Control" (Desktop
/// & Dock settings). While it's on, anything dragged to the top edge shows
/// the Spaces bar, which covers the notch.
enum DockSpaces {
    private static var domain: CFString { "com.apple.dock" as CFString }
    private static var key: CFString { "enterMissionControlByTopWindowDrag" as CFString }

    /// On unless turned off (macOS's default is on).
    static var dragToTopShowsSpaces: Bool {
        CFPreferencesCopyAppValue(key, domain) as? Bool ?? true
    }

    /// Changes the setting and restarts the Dock so it takes effect.
    static func setDragToTopShowsSpaces(_ on: Bool) {
        CFPreferencesSetAppValue(key, on as CFBoolean, domain)
        CFPreferencesAppSynchronize(domain)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        try? process.run()
    }
}
