import Foundation
import Testing
@testable import FeatureDeskMinder

struct StretchScaleTests {
    @Test func startsAtOneMinuteAndGrows() {
        #expect(StretchScale.minutes(forStretch: 0) == 1)
        #expect(StretchScale.minutes(forStretch: -20) == 1)
        #expect(StretchScale.minutes(forStretch: StretchScale.step * 9) == 10)
        #expect(StretchScale.minutes(forStretch: StretchScale.step * 29) == 30)
        #expect(StretchScale.minutes(forStretch: StretchScale.step * 30) == 35)
        #expect(StretchScale.minutes(forStretch: StretchScale.step * 47) == 120)
        #expect(StretchScale.minutes(forStretch: 100_000) == 480)
    }

    @Test func neverGoesDownWhenStretchingFurther() {
        var last = 0
        for points in stride(from: 0.0, through: 900, by: 3) {
            let minutes = StretchScale.minutes(forStretch: points)
            #expect(minutes >= last)
            last = minutes
        }
    }

    @Test func labels() {
        let m: (Int) -> String = { "\($0)m" }
        let h: (Int, Int) -> String = { "\($0)h\($1)" }
        #expect(StretchScale.label(minutes: 45, minuteFormat: m, hourFormat: h) == "45m")
        #expect(StretchScale.label(minutes: 90, minuteFormat: m, hourFormat: h) == "1h30")
    }
}

struct MinderTimeParserTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    /// 2026-11-18 13:53 UTC.
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 13, minute: 53))! }

    func hm(_ date: Date?) -> String? {
        guard let date else { return nil }
        let c = calendar.dateComponents([.day, .hour, .minute], from: date)
        return "\(c.day!) \(c.hour!):\(c.minute!)"
    }

    @Test func clockTimes() {
        #expect(hm(MinderTimeParser.due(from: "18:30", now: now, calendar: calendar)) == "18 18:30")
        #expect(hm(MinderTimeParser.due(from: "18:", now: now, calendar: calendar)) == "18 18:0")
        #expect(hm(MinderTimeParser.due(from: "18", now: now, calendar: calendar)) == "18 18:0")
        #expect(hm(MinderTimeParser.due(from: "6pm", now: now, calendar: calendar)) == "18 18:0")
        #expect(hm(MinderTimeParser.due(from: "6:15 pm", now: now, calendar: calendar)) == "18 18:15")
        #expect(hm(MinderTimeParser.due(from: "12am", now: now, calendar: calendar)) == "19 0:0")
    }

    @Test func pastTimeMeansTomorrow() {
        #expect(hm(MinderTimeParser.due(from: "9:00", now: now, calendar: calendar)) == "19 9:0")
        #expect(hm(MinderTimeParser.due(from: "13:53", now: now, calendar: calendar)) == "19 13:53")
    }

    @Test func durations() {
        #expect(hm(MinderTimeParser.due(from: "20m", now: now, calendar: calendar)) == "18 14:13")
        #expect(hm(MinderTimeParser.due(from: "20 min", now: now, calendar: calendar)) == "18 14:13")
        #expect(hm(MinderTimeParser.due(from: "1h", now: now, calendar: calendar)) == "18 14:53")
        #expect(hm(MinderTimeParser.due(from: "1h30", now: now, calendar: calendar)) == "18 15:23")
        #expect(hm(MinderTimeParser.due(from: "90", now: now, calendar: calendar)) == "18 15:23")
    }

    @Test func nonsenseIsRejected() {
        for text in ["", "abc", "25:00", "18:75", "13pm", "0m", "lunch"] {
            #expect(MinderTimeParser.due(from: text, now: now, calendar: calendar) == nil, "\(text)")
        }
    }
}

struct MinderTests {
    @Test func roundTrips() throws {
        let minder = Minder(title: "Reply to John's email", due: Date(timeIntervalSince1970: 1_800_000_000), reminderID: "x")
        let decoded = try JSONDecoder().decode([Minder].self, from: JSONEncoder().encode([minder]))
        #expect(decoded == [minder])
    }
}
