import Foundation

public extension L10n {
    /// Desk Minder (feature id `deskminder`).
    enum DeskMinder {
        public static var displayName: String { tr("deskminder.displayName", "Desk Minder") }
        public static var summary: String {
            tr("deskminder.summary", "Stretch a bar or type a time to set a reminder. It fills the screen when it's due.")
        }
        public static var tagline: String { tr("deskminder.tagline", "Stretch a bar to set a reminder.") }
        public static var heroDescription: String {
            tr("deskminder.hero.description", "Example: the reminder bar above the Dock, stretched to 3:15")
        }
        public static var hotkey: String { tr("deskminder.hotkey", "New Reminder") }

        // The bar.
        public static func minutes(_ count: Int) -> String { format("deskminder.minutes", "%lld min", count) }
        public static func hours(_ hours: Int, _ minutes: Int) -> String {
            minutes == 0 ? format("deskminder.hours", "%lld h", hours) : format("deskminder.hoursMinutes", "%lld h %lld min", hours, minutes)
        }
        public static var titlePlaceholder: String { tr("deskminder.titlePlaceholder", "Reminder…") }
        public static var timeHelp: String { tr("deskminder.timeHelp", "Type a time like 18:30, 6pm or 20m, or stretch the bar.") }
        public static var stretchHelp: String { tr("deskminder.stretchHelp", "Drag to the right for more time") }
        public static var add: String { tr("deskminder.add", "Add Reminder") }
        public static var close: String { tr("deskminder.close", "Close the bar") }
        public static var defaultTitle: String { tr("deskminder.defaultTitle", "Reminder") }
        public static func added(_ time: String) -> String { format("deskminder.added", "Reminder at %@", time) }
        public static var badTime: String { tr("deskminder.badTime", "Try a time like 18:30, 6pm or 20m") }

        // The alert.
        public static var alertKicker: String { tr("deskminder.alert.kicker", "Reminder") }
        public static var done: String { tr("deskminder.alert.done", "Close") }
        public static var snooze: String { tr("deskminder.alert.snooze", "Snooze Reminder") }
        public static func snoozeFor(_ label: String) -> String { format("deskminder.alert.snoozeFor", "Snooze %@", label) }
        public static func snoozed(_ time: String) -> String { format("deskminder.alert.snoozed", "Snoozed until %@", time) }

        // Settings.
        public static var showBar: String { tr("deskminder.settings.showBar", "Show the Bar") }
        public static var keepBar: String { tr("deskminder.settings.keepBar", "Keep the bar above the Dock") }
        public static var keepBarHelp: String { tr("deskminder.settings.keepBarHelp", "Otherwise it appears with its shortcut and hides after you add a reminder.") }
        public static var sounds: String { tr("deskminder.settings.sounds", "Tick sound while stretching") }
        public static var sync: String { tr("deskminder.settings.sync", "Also add to Apple Reminders") }
        public static var syncHelp: String {
            tr("deskminder.settings.syncHelp", "Reminders also alert on your iPhone, iPad and Apple Watch. iCloud syncs them from this Mac.")
        }
        public static var allowReminders: String { tr("deskminder.settings.allow", "Allow Access to Reminders…") }
        public static var remindersDenied: String {
            tr("deskminder.settings.denied", "All Set isn't allowed to use Reminders. Turn it on in System Settings → Privacy & Security → Reminders.")
        }
        public static var snoozeLength: String { tr("deskminder.settings.snoozeLength", "Snooze for") }
        public static var upcoming: String { tr("deskminder.settings.upcoming", "Upcoming") }
        public static var noUpcoming: String { tr("deskminder.settings.noUpcoming", "No reminders yet. Press the shortcut to add one.") }
        public static func erase(_ count: Int) -> String {
            plural("deskminder.erase", one: "%lld upcoming reminder", other: "%lld upcoming reminders", count)
        }
    }
}
