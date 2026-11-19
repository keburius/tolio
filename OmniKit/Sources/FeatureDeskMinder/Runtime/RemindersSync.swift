import EventKit
import OmniCore

/// Copies reminders to Apple Reminders (default list) so they also alert on
/// iPhone, iPad and Watch through iCloud. Tolio only talks to the local
/// Reminders store; iCloud does the syncing.
@MainActor
final class RemindersSync {
    private let store = EKEventStore()
    private let log = Log.logger("deskminder")

    enum Access { case allowed, denied, notAsked }

    var access: Access {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess, .writeOnly: .allowed
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToReminders()
        } catch {
            log.error("Reminders access request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Adds `minder` with an alert at its time. Returns the new reminder's id.
    func add(_ minder: Minder) -> String? {
        guard access == .allowed, let list = store.defaultCalendarForNewReminders() else { return nil }
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = list
        apply(minder, to: reminder)
        do {
            try store.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            log.error("Couldn't add a reminder: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Moves the synced copy to the new time (snooze).
    func update(_ minder: Minder) {
        guard let reminder = find(minder) else { return }
        apply(minder, to: reminder)
        save(reminder)
    }

    /// Ticks the synced copy off (Close).
    func complete(_ minder: Minder) {
        guard let reminder = find(minder) else { return }
        reminder.isCompleted = true
        save(reminder)
    }

    /// Removes the synced copy (deleted before it was due).
    func remove(_ minder: Minder) {
        guard let reminder = find(minder) else { return }
        do {
            try store.remove(reminder, commit: true)
        } catch {
            log.error("Couldn't remove a reminder: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func find(_ minder: Minder) -> EKReminder? {
        guard access == .allowed, let id = minder.reminderID else { return nil }
        return store.calendarItem(withIdentifier: id) as? EKReminder
    }

    private func apply(_ minder: Minder, to reminder: EKReminder) {
        reminder.title = minder.title
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .timeZone], from: minder.due
        )
        reminder.alarms?.forEach(reminder.removeAlarm)
        reminder.addAlarm(EKAlarm(absoluteDate: minder.due))
    }

    private func save(_ reminder: EKReminder) {
        do {
            try store.save(reminder, commit: true)
        } catch {
            log.error("Couldn't update a reminder: \(error.localizedDescription, privacy: .public)")
        }
    }
}
