import Foundation

// Strings added with the All Set redesign (Settings shell, Overview, Profile,
// General, Permissions). Feature pages keep theirs in their own files.

public extension L10n {
    enum AllSet {
        public static var appName: String { tr("allset.appName", "All Set") }
        public static var features: String { tr("allset.sidebar.features", "Features") }
        public static var profile: String { tr("allset.page.profile", "Profile") }
        public static var search: String { tr("allset.sidebar.search", "Search") }

        // Overview
        public static func onCount(_ on: Int, _ total: Int) -> String { format("allset.overview.onCount", "%lld of %lld on", on, total) }
        public static var mostLoved: String { tr("allset.overview.mostLoved", "Most loved") }
        public static var moreFeatures: String { tr("allset.overview.moreFeatures", "More features") }
        public static var aboutTitle: String { tr("allset.overview.about", "About All Set") }
        public static var aboutBody: String {
            tr("allset.overview.aboutBody", "The shortcuts your Mac is missing, in one small menu bar app. Turn on what you need. Everything stays on this Mac.")
        }
        public static var slideClipboardTitle: String { tr("allset.overview.slide.clipboard", "Copy once, paste any time") }
        public static func slideClipboardBody(_ keys: String) -> String {
            format("allset.overview.slide.clipboardBody", "Press %@ to bring back anything you copied: text, links and pictures.", keys)
        }
        public static var slideDropRingTitle: String { tr("allset.overview.slide.dropRing", "Send a file in one move") }
        public static var slideDropRingBody: String {
            tr("allset.overview.slide.dropRingBody", "Shake the pointer while you drag, then drop the file on a folder, an app or a person.")
        }
        public static var slideScreenshotTitle: String { tr("allset.overview.slide.screenshot", "Show it instead of explaining it") }
        public static func slideScreenshotBody(_ keys: String) -> String {
            format("allset.overview.slide.screenshotBody", "Press %@, pick an area and mark it up. It copies itself after 3 seconds.", keys)
        }
        public static var slideMinderTitle: String { tr("allset.overview.slide.minder", "Remember the next thing") }
        public static var slideMinderBody: String {
            tr("allset.overview.slide.minderBody", "Stretch the bar above the Dock to set a reminder. It reaches your iPhone too.")
        }
        public static var previousSlide: String { tr("allset.overview.previousSlide", "Previous slide") }
        public static var nextSlide: String { tr("allset.overview.nextSlide", "Next slide") }
        public static func slideNumber(_ n: Int, _ total: Int) -> String { format("allset.overview.slideNumber", "Slide %lld of %lld", n, total) }

        // Feature page
        public static func changeShortcut(_ action: String) -> String { format("allset.feature.changeShortcut", "%@: change shortcut", action) }
        public static var turnOnToChange: String { tr("allset.feature.turnOnToChange", "Turn it on to change its settings.") }
        public static var shortcutsSection: String { tr("allset.feature.shortcuts", "Shortcuts") }

        // General
        public static var startup: String { tr("allset.general.startup", "Startup") }
        public static var openAtLogin: String { tr("allset.general.openAtLogin", "Open All Set at login") }
        public static var setupGuide: String { tr("allset.general.setupGuide", "Setup guide") }
        public static var setupGuideDetail: String { tr("allset.general.setupGuideDetail", "Choose features and grant permissions again.") }
        public static var feel: String { tr("allset.general.feel", "Feel") }
        public static var hapticTaps: String { tr("allset.general.haptics", "Haptic taps") }
        public static var hapticTapsDetail: String {
            tr("allset.general.hapticsDetail", "A light tap on the trackpad when you stretch, open or change pages.")
        }
        public static var tickSounds: String { tr("allset.general.ticks", "Tick sounds") }
        public static var tickSoundsDetail: String { tr("allset.general.ticksDetail", "Soft ticks to go with the taps.") }
        public static var about: String { tr("allset.general.about", "About") }

        // Permissions
        public static var permissionsIntro: String {
            tr("allset.permissions.intro", "All Set asks only for what a feature needs. Turn a feature off and it stops using its permission.")
        }
        public static var permissionsFootnote: String {
            tr("allset.permissions.footnote", "To change one later, open System Settings, then Privacy & Security.")
        }
        public static var neverConnects: String {
            tr("allset.permissions.neverConnects", "All Set never connects to the internet. Everything stays on this Mac.")
        }
        public static var allowEllipsis: String { tr("allset.permissions.allow", "Allow…") }
        public static var openSystemSettings: String { tr("allset.permissions.openSystemSettings", "Open System Settings…") }
        public static var accessibilityUse: String { tr("allset.permissions.accessibilityUse", "Moves windows, locks the keyboard and listens for shortcuts.") }
        public static var screenRecordingUse: String {
            tr("allset.permissions.screenRecordingUse", "For screenshots, recordings, Capture Text and window previews.")
        }
        public static var microphoneUse: String { tr("allset.permissions.microphoneUse", "Only while you record the screen with your voice.") }
        public static var calendars: String { tr("allset.permissions.calendars", "Calendars") }
        public static var calendarsUse: String { tr("allset.permissions.calendarsUse", "Shows today's and tomorrow's events in the Notch Island.") }
        public static var reminders: String { tr("allset.permissions.reminders", "Reminders") }
        public static var remindersUse: String { tr("allset.permissions.remindersUse", "Sends Desk Minder reminders to your iPhone.") }
        public static var bluetooth: String { tr("allset.permissions.bluetooth", "Bluetooth") }
        public static var bluetoothUse: String { tr("allset.permissions.bluetoothUse", "Shows AirPods and other devices when they connect.") }
        public static var music: String { tr("allset.permissions.music", "Music and Spotify") }
        public static var musicUse: String { tr("allset.permissions.musicUse", "Shows what's playing, with its artwork and controls.") }
        public static var allowed: String { tr("allset.permissions.allowed", "Allowed") }
        public static var needsPermission: String { tr("allset.permissions.needs", "Needs permission") }
        public static var notAskedYet: String { tr("allset.permissions.notAsked", "Not asked yet") }
        public static var askedOnFirstUse: String { tr("allset.permissions.firstUse", "Asked when you first use it") }
        public static var required: String { tr("allset.permissions.required", "Required") }
        public static var optional: String { tr("allset.permissions.optional", "Optional") }

        // Profile
        public static var free: String { tr("allset.profile.free", "Free") }
        public static var proTrial: String { tr("allset.profile.trial", "Pro trial") }
        public static var noAccount: String { tr("allset.profile.noAccount", "No account needed. Your plan and license live on this Mac.") }
        public static var pro: String { tr("allset.profile.pro", "All Set Pro") }
        public static var proPrice: String { tr("allset.profile.proPrice", "$14.99 a year, about $1.25 a month. 3 Macs per license.") }
        public static var startTrial: String { tr("allset.profile.startTrial", "Start 14-day trial") }
        public static func trialDaysLeft(_ days: Int) -> String {
            plural("allset.profile.trialDaysLeft", one: "%lld day left in your trial", other: "%lld days left in your trial", days)
        }
        public static var trialTitle: String { tr("allset.profile.trialTitle", "14-day free trial") }
        public static var trialDetail: String { tr("allset.profile.trialDetail", "No card needed. Stop anytime and keep the Pro version you have.") }
        public static var license: String { tr("allset.profile.license", "License") }
        public static var licenseKey: String { tr("allset.profile.licenseKey", "License key") }
        public static var activate: String { tr("allset.profile.activate", "Activate") }
        public static var haveLicense: String { tr("allset.profile.haveLicense", "Already have a license?") }
        public static var haveLicenseDetail: String { tr("allset.profile.haveLicenseDetail", "Bring Pro back on this Mac.") }
        public static var restore: String { tr("allset.profile.restore", "Restore…") }
        public static var openSource: String { tr("allset.profile.openSource", "Open source") }
        public static var openSourceDetail: String { tr("allset.profile.openSourceDetail", "The free app is MIT-licensed on GitHub.") }
        public static var viewOnGitHub: String { tr("allset.profile.github", "View on GitHub") }
        public static var noTracking: String {
            tr("allset.profile.noTracking", "No account. No tracking. Your license is checked on your Mac, offline.")
        }
        public static var licenseNotAvailable: String {
            tr("allset.profile.notAvailable", "License activation isn't available in this version yet.")
        }
        public static var licenseInvalid: String { tr("allset.profile.invalid", "That doesn't look like a license key. Keys look like XXXX-XXXX-XXXX-XXXX.") }
    }
}

public extension L10n {
    enum ShortcutsUI {
        public static var intro: String { tr("allset.shortcuts.intro", "Click a shortcut, then press the new keys.") }
        public static var controlPanel: String { tr("allset.shortcuts.controlPanel", "Control Panel") }
        public static func change(_ title: String) -> String { format("allset.shortcuts.change", "Change shortcut for %@", title) }
    }
}

public extension L10n {
    /// The menu bar control panel.
    enum PanelUI {
        public static var clipboard: String { tr("allset.panel.clipboard", "Clipboard") }
        public static var screenshot: String { tr("allset.panel.screenshot", "Screenshot") }
        public static var record: String { tr("allset.panel.record", "Record") }
        public static var layouts: String { tr("allset.panel.layouts", "Layouts") }
        public static var dropRing: String { tr("allset.panel.dropRing", "Drop Ring") }
        public static var reminder: String { tr("allset.panel.reminder", "Reminder") }
        public static var island: String { tr("allset.panel.island", "Island") }
        public static var lockKeys: String { tr("allset.panel.lockKeys", "Lock keys") }
        public static var runningNow: String { tr("allset.panel.runningNow", "Running now") }
        public static var more: String { tr("allset.panel.more", "More") }
        public static var stayingAwake: String { tr("allset.panel.stayingAwake", "Staying awake") }
        public static var energyMode: String { tr("allset.panel.energyMode", "Energy Mode") }
        public static var off: String { tr("allset.panel.off", "Off") }
        public static var on: String { tr("allset.panel.on", "On") }
        public static func nextReminderAt(_ time: String) -> String { format("allset.panel.nextReminder", "Next reminder at %@", time) }
        public static var snooze: String { tr("allset.panel.snooze", "Snooze") }
        public static var captureText: String { tr("allset.panel.captureText", "Capture Text") }
        public static var newNote: String { tr("allset.panel.newNote", "New Desktop Note") }
        public static var cheatSheet: String { tr("allset.panel.cheatSheet", "Shortcut Cheat Sheet") }
        public static var settings: String { tr("allset.panel.settings", "Settings…") }
        public static var quit: String { tr("allset.panel.quit", "Quit All Set") }
        public static func stop(_ elapsed: String) -> String { format("allset.panel.stop", "Stop %@", elapsed) }
        public static func featureIsOff(_ feature: String) -> String { format("allset.panel.featureOff", "%@ is off.", feature) }
        public static var turnOn: String { tr("allset.panel.turnOn", "Turn On") }
    }
}
