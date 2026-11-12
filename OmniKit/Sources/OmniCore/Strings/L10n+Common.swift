import Foundation

public extension L10n {
    /// Words and buttons used all over the app.
    enum Common {
        public static var turnOn: String { tr("common.turnOn", "Turn On") }
        public static var cancel: String { tr("common.cancel", "Cancel") }
        public static var done: String { tr("common.done", "Done") }
        public static var back: String { tr("common.back", "Back") }
        public static var `continue`: String { tr("common.continue", "Continue") }
        public static var remove: String { tr("common.remove", "Remove") }
        public static var add: String { tr("common.add", "Add") }
        public static var addApp: String { tr("common.addApp", "Add App") }
        public static var close: String { tr("common.close", "Close") }
        public static var reset: String { tr("common.reset", "Reset") }
        public static var resetToDefault: String { tr("common.resetToDefault", "Reset to default") }
        public static var openSystemSettings: String { tr("common.openSystemSettings", "Open System Settings") }
        public static var allow: String { tr("common.allow", "Allow…") }
        public static var settingsEllipsis: String { tr("common.settingsEllipsis", "Settings…") }
        public static var hideThisIcon: String { tr("common.hideThisIcon", "Hide This Icon") }
        public static var off: String { tr("common.off", "Off") }
        public static var on: String { tr("common.on", "On") }
        public static var none: String { tr("common.none", "None") }
        public static var noAppsExcluded: String { tr("common.noAppsExcluded", "No apps excluded.") }
        public static var passwordManagersAlwaysExcluded: String { tr("common.passwordManagersAlwaysExcluded", "Password managers are always excluded.") }
        public static func featureSettings(_ feature: String) -> String {
            format("common.featureSettings", "%@ Settings…", feature)
        }
        public static func turnOnFeatureToChange(_ feature: String) -> String {
            format("common.turnOnFeatureToChange", "Turn on %@ to see and change its settings.", feature)
        }
        public static func noMatches(_ query: String) -> String {
            format("common.noMatches", "No matches for “%@”.", query)
        }
    }

    /// Feature states shown on cards, the sidebar and tiles.
    enum Status {
        public static var working: String { tr("status.working", "Working") }
        public static var needsPermission: String { tr("status.needsPermission", "Needs permission") }
        public static var off: String { tr("status.off", "Off") }
        public static func problem(_ detail: String) -> String { format("status.problem", "Problem: %@", detail) }
    }

    /// Permission names and why Omni asks for them.
    enum Permissions {
        public static var accessibility: String { tr("permission.accessibility", "Accessibility") }
        public static var screenRecording: String { tr("permission.screenRecording", "Screen Recording") }
        public static var microphone: String { tr("permission.microphone", "Microphone") }
        public static var accessibilityWhy: String {
            tr("permission.accessibility.why", "Lets Omni move windows, type snippets for you, read menus and selected text, and listen for shortcuts.")
        }
        public static var screenRecordingWhy: String {
            tr("permission.screenRecording.why", "Lets Omni take screenshots, record your screen, and show window previews.")
        }
        public static var microphoneWhy: String {
            tr("permission.microphone.why", "Only for screen recordings with your voice.")
        }
        public static var allowed: String { tr("permission.state.allowed", "Allowed") }
        public static var notAllowed: String { tr("permission.state.notAllowed", "Not allowed") }
        public static var notAskedYet: String { tr("permission.state.notAsked", "Not asked yet") }
        public static var unknown: String { tr("permission.state.unknown", "Can't be checked") }
        public static var required: String { tr("permission.required", "Required") }
        public static var optional: String { tr("permission.optional", "Optional") }
        public static var resetAndAskAgain: String { tr("permission.resetAndAskAgain", "Reset and Ask Again") }
        public static var resetHelp: String {
            tr("permission.resetHelp", "Already switched on in System Settings but still not allowed? This removes Omni's old entry and asks again.")
        }
        public static func usedBy(_ features: String) -> String { format("permission.usedBy", "Used by %@", features) }
        public static func optionalFor(_ features: String) -> String { format("permission.optionalFor", "Optional for %@", features) }
        public static var unused: String { tr("permission.unused", "No feature you turned on uses this.") }
        public static var nothingLeavesMac: String {
            tr("permission.nothingLeaves", "macOS asks you to allow these yourself. Nothing you allow leaves this Mac.")
        }
    }
}

public extension L10n {
    /// Accessibility labels of shared UI pieces.
    enum A11y {
        public static func shortcut(_ spoken: String) -> String { format("a11y.shortcut", "shortcut %@", spoken) }
    }
}
