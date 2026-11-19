import AppKit
import EventKit
import OmniCore

/// Events from Apple Calendar (which also shows Google and Exchange
/// accounts added in macOS).
@MainActor
final class CalendarSource {
    struct Item: Identifiable, Equatable {
        var id: String
        var title: String
        var start: Date
        var end: Date
        var allDay: Bool
        var color: CGColor?
        var location: String?
        /// A video call link found in the event (Zoom, Meet, Teams, Webex).
        var callURL: URL?
        var eventID: String
    }

    private let store = EKEventStore()

    enum Access { case allowed, denied, notAsked }

    var access: Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .allowed
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Events from the start of `from`'s day for `days` days, by start time.
    func events(from: Date = Date(), days: Int = 7) -> [Item] {
        guard access == .allowed else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        guard let end = calendar.date(byAdding: .day, value: days, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                Item(id: (event.calendarItemIdentifier) + "\(event.startDate.timeIntervalSince1970)", title: event.title ?? "",
                     start: event.startDate, end: event.endDate, allDay: event.isAllDay, color: event.calendar.cgColor,
                     location: event.location?.isEmpty == false ? event.location : nil,
                     callURL: Self.callLink(in: [event.url?.absoluteString, event.location, event.notes]),
                     eventID: event.calendarItemIdentifier)
            }
    }

    /// Opens Calendar at the event's day.
    func open(_ item: Item) {
        if let url = URL(string: "ical://ekevent/\(item.eventID)?method=show&options=more"), NSWorkspace.shared.open(url) { return }
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: app, configuration: .init())
        }
    }

    nonisolated static func callLink(in texts: [String?]) -> URL? {
        let hosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com", "facetime.apple.com"]
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for text in texts.compactMap({ $0 }) {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                if let url = match.url, let host = url.host?.lowercased(), hosts.contains(where: { host.hasSuffix($0) }) { return url }
            }
        }
        return nil
    }
}
