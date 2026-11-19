import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Your agenda beside the month: the chosen day and the next few, each
/// event tinted in its calendar's color with Join for video calls; the
/// month on the right with today circled and a dot on busy days.
struct CalendarPage: View {
    let services: IslandServices
    @State private var selected = Calendar.current.startOfDay(for: Date())

    static let accent = Color(red: 0.98, green: 0.45, blue: 0.38)

    var body: some View {
        switch services.calendarAccess {
        case .allowed:
            HStack(alignment: .top, spacing: 30) {
                Agenda(selected: selected, events: services.calendarEvents, open: services.openCalendarItem)
                    .frame(maxWidth: .infinity, alignment: .leading)
                MonthGrid(selected: $selected, events: services.calendarEvents)
                    .frame(width: 236)
            }
        case .notAsked:
            VStack(spacing: 8) {
                Image(systemName: "calendar").font(.system(size: 22)).foregroundStyle(Self.accent)
                Button(L10n.Island.showCalendar, action: services.requestCalendar)
                    .buttonStyle(.bordered).controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied:
            Text(L10n.Island.calendarDenied).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Agenda

private struct Agenda: View {
    let selected: Date
    let events: [CalendarSource.Item]
    let open: (CalendarSource.Item) -> Void

    private struct Day: Identifiable {
        var date: Date
        var items: [CalendarSource.Item]
        var id: Date { date }
    }

    /// The chosen day (always) and the next six that have events.
    private func days(now: Date) -> [Day] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset -> Day? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: selected),
                  let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let items = events.filter { $0.start < next && $0.end > day && $0.end > now }
            return offset == 0 || !items.isEmpty ? Day(date: day, items: items) : nil
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let list = days(now: context.date)
            VStack(alignment: .leading, spacing: 8) {
                header
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(list) { day in
                            if day.date != selected {
                                Text(day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased(with: .current))
                                    .font(.system(size: 11.5, weight: .bold)).tracking(0.3)
                                    .foregroundStyle(.white.opacity(0.45))
                                    .padding(.top, 2)
                            }
                            if day.items.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle").foregroundStyle(.green)
                                    Text(Calendar.current.isDateInToday(day.date) ? L10n.Island.noMoreToday : L10n.Island.nothingThatDay)
                                }
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                                .padding(.vertical, 6)
                            }
                            ForEach(day.items) { item in
                                EventCard(item: item, now: context.date, open: { open(item) })
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    /// "THU 19 W47"
    private var header: some View {
        let week = Calendar.current.component(.weekOfYear, from: selected)
        return HStack(spacing: 7) {
            Text(selected.formatted(.dateTime.weekday(.abbreviated)).uppercased(with: .current)).foregroundStyle(CalendarPage.accent)
            Text(selected.formatted(.dateTime.day())).foregroundStyle(.white)
            Text(L10n.Island.weekNumber(week)).foregroundStyle(CalendarPage.accent.opacity(0.6))
        }
        .font(.system(size: 16, weight: .bold).monospacedDigit())
        .contentTransition(.numericText())
    }
}

/// One event, tinted in its calendar's color.
struct EventCard: View {
    let item: CalendarSource.Item
    let now: Date
    let open: () -> Void
    @State private var hover = false

    var body: some View {
        let color = item.color.map { Color(cgColor: $0) } ?? Color(red: 0.4, green: 0.6, blue: 1)
        let light = Self.lighter(item.color)
        HStack(spacing: 10) {
            Capsule().fill(color).frame(width: 3.5).padding(.vertical, 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(light).lineLimit(1)
                HStack(spacing: 5) {
                    Text(item.allDay ? L10n.Island.allDay
                         : "\(item.start.formatted(date: .omitted, time: .shortened)) – \(item.end.formatted(date: .omitted, time: .shortened))")
                    if let badge = Self.badge(item, now: now) {
                        Text(badge).foregroundStyle(item.start <= now ? .green : .orange)
                    }
                }
                .font(.system(size: 12.5, weight: .medium).monospacedDigit())
                .foregroundStyle(light.opacity(0.75))
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let call = item.callURL {
                Button { NSWorkspace.shared.open(call) } label: {
                    Text(L10n.Island.join).font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 13).frame(height: 26)
                        .background(Capsule().fill(Color(red: 0.36, green: 0.76, blue: 0.4)))
                        .foregroundStyle(.white)
                }
                .buttonStyle(IslandPress())
                .help(call.host() ?? "")
            }
        }
        .padding(.leading, 9)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(color.opacity(hover ? 0.3 : 0.22)))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(count: 2, perform: open)
        .help(item.location ?? item.title)
    }

    /// The calendar color mixed with white, for text on the tinted card.
    static func lighter(_ color: CGColor?) -> Color {
        guard let color, let ns = NSColor(cgColor: color)?.usingColorSpace(.sRGB) else { return Color(red: 0.75, green: 0.85, blue: 1) }
        return Color(nsColor: ns.blended(withFraction: 0.5, of: .white) ?? ns)
    }

    /// "in 12 min", "now": only for timed events starting within 2 hours.
    static func badge(_ item: CalendarSource.Item, now: Date) -> String? {
        guard !item.allDay else { return nil }
        if item.start <= now, item.end > now { return L10n.Island.now }
        let minutes = Int(item.start.timeIntervalSince(now) / 60)
        guard minutes >= 0, minutes < 120 else { return nil }
        return L10n.Island.inMinutes(max(minutes, 1))
    }
}

// MARK: - Month

private struct MonthGrid: View {
    @Binding var selected: Date
    let events: [CalendarSource.Item]

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let month = calendar.dateInterval(of: .month, for: today)!
        let count = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        let lead = (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7
        let cells: [Date?] = Array(repeating: nil, count: lead)
            + (0..<count).map { calendar.date(byAdding: .day, value: $0, to: month.start) }
        let rows = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let ordered = (0..<7).map { symbols[($0 + calendar.firstWeekday - 1) % 7] }

        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text(today.formatted(.dateTime.month(.abbreviated)).uppercased(with: .current))
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(CalendarPage.accent)
            }
            .padding(.bottom, 6)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(ordered[i]).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)
            VStack(spacing: 1) {
                ForEach(rows.indices, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { c in
                            let day = c < rows[r].count ? rows[r][c] : nil
                            if let day {
                                cell(day, today: today)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 27, maxHeight: 27)
                            }
                        }
                    }
                }
            }
        }
        .animation(OmniStyle.motion(.spring(response: 0.3, dampingFraction: 0.75)), value: selected)
    }

    private func cell(_ day: Date, today: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let busy = events.contains { calendar.isDate($0.start, inSameDayAs: day) }
        let dim = calendar.isDateInWeekend(day)
        return Button { selected = day } label: {
            Text(day.formatted(.dateTime.day()))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(isToday ? .white : .white.opacity(dim ? 0.45 : 0.9))
                .frame(width: 25, height: 25)
                .background {
                    if isToday { Circle().fill(CalendarPage.accent) }
                    else if isSelected { Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1) }
                }
                .overlay(alignment: .bottom) {
                    if busy && !isToday {
                        Circle().fill(.white.opacity(0.55)).frame(width: 3, height: 3).offset(y: 3)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 27, maxHeight: 27)
                .contentShape(Rectangle())
        }
        .buttonStyle(IslandPress())
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
    }
}
