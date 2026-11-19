import Foundation

// Strings for the All Set setup guide and the Menu Bar settings page.

public extension L10n {
    enum OnboardingUI {
        public static var openSettings: String { tr("onboardingUI.openSettings", "Open Settings") }
        public static var windowTitle: String { tr("allset.onboarding.windowTitle", "Welcome to All Set") }
        public static func step(_ n: Int, _ total: Int) -> String { format("allset.onboarding.step", "Step %lld of %lld", n, total) }

        // Welcome
        public static var welcomeTitle: String { tr("allset.onboarding.welcome.title", "Welcome to All Set") }
        public static var welcomeBody: String {
            tr("allset.onboarding.welcome.body", "Everyday tools for your clipboard, windows, screenshots and shortcuts, in one menu bar app.")
        }

        // Features
        public static var featuresTitle: String { tr("allset.onboarding.features.title", "Turn on what you need") }
        public static var featuresBody: String {
            tr("allset.onboarding.features.body", "Start with the recommended set. Anything off does nothing in the background, and you can change this any time.")
        }
        public static var preset: String { tr("allset.onboarding.features.preset", "Preset") }
        public static var letMeChoose: String { tr("allset.onboarding.features.custom", "Let me choose") }

        // Permissions
        public static var permissionsBody: String {
            tr("allset.onboarding.permissions.body", "macOS asks before All Set can do these. Each one opens System Settings; flip the switch there and come back.")
        }
        public static var accessibilityWhy: String {
            tr("allset.onboarding.permissions.accessibility", "Lets All Set move windows, read menus and selected text, and listen for shortcuts.")
        }
        public static var screenRecordingWhy: String {
            tr("allset.onboarding.permissions.screenRecording", "Lets All Set take screenshots, record your screen, and show window previews.")
        }
        public static var microphoneWhy: String { tr("allset.onboarding.permissions.microphone", "Only for screen recordings with your voice.") }
        public static func requiredFor(_ list: String) -> String { format("allset.onboarding.permissions.requiredFor", "Required for %@", list) }
        public static var permissionsFootnote: String {
            tr("allset.onboarding.permissions.footnote", "All Set never connects to the internet. You can change these later in Permissions.")
        }
        public static var noPermissions: String {
            tr("allset.onboarding.permissions.none", "The features you chose don't need any permissions.")
        }
        public static var reopenNote: String {
            tr("allset.onboarding.permissions.reopenNote", "Switched it on but it still needs permission? Some permissions start working after All Set reopens.")
        }
        public static var reopen: String { tr("allset.onboarding.permissions.reopen", "Reopen All Set") }

        // Done
        public static var doneTitle: String { tr("allset.onboarding.done.title", "You're all set.") }
        public static var doneBody: String { tr("allset.onboarding.done.body", "All Set lives in your menu bar. Try these first:") }
    }

    enum MenuBarUI {
        public static var separateIcons: String { tr("allset.menuBar.separate", "Separate icons") }
        public static var separateIconsDetail: String { tr("allset.menuBar.separateDetail", "One click for each quick action.") }
        public static var oneIcon: String { tr("allset.menuBar.single", "One icon only") }
        public static var oneIconDetail: String { tr("allset.menuBar.singleDetail", "Everything is in the control panel.") }
        public static var statsNote: String {
            tr("allset.menuBar.statsNote", "System Stats has its own menu bar item. With one icon only, its numbers move into the control panel.")
        }
        public static var dragToReorder: String { tr("allset.menuBar.dragToReorder", "Drag to reorder") }
    }
}
