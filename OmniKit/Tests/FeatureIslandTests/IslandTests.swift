import CoreGraphics
import Foundation
import OmniCore
import Testing
@testable import FeatureIsland

struct NotchGeometryTests {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func hardwareNotchIsTheGapBetweenTheMenuBarAreas() {
        let left = CGRect(x: 0, y: 950, width: 662, height: 32)
        let right = CGRect(x: 850, y: 950, width: 662, height: 32)
        let g = NotchGeometry(frame: screen, leftArea: left, rightArea: right, menuBarHeight: 32)
        #expect(g.hasHardwareNotch)
        #expect(g.notch == CGRect(x: 662, y: 950, width: 188, height: 32))
    }

    @Test func virtualNotchWithoutOne() {
        let g = NotchGeometry(frame: screen, leftArea: nil, rightArea: nil, menuBarHeight: 24)
        #expect(!g.hasHardwareNotch)
        #expect(g.notch.midX == screen.midX)
        #expect(g.notch.maxY == screen.maxY)
        #expect(g.notch.height == NotchGeometry.virtualSize.height)
    }

    @Test func windowIsCenteredAndFlushWithTheTop() {
        let g = NotchGeometry(frame: screen, leftArea: CGRect(x: 0, y: 950, width: 662, height: 32),
                              rightArea: CGRect(x: 850, y: 950, width: 662, height: 32), menuBarHeight: 32)
        let frame = g.windowFrame(openSize: CGSize(width: 470, height: 196))
        #expect(abs(frame.midX - g.notch.midX) < 0.001)
        #expect(frame.maxY == screen.maxY)
        #expect(frame.width >= 470 && frame.height >= 196)
    }
}

struct LiveActivityTests {
    func activity(_ id: String, _ priority: LiveActivity.Priority, expires: Date? = nil) -> LiveActivity {
        LiveActivity(id: id, leading: .symbol("bolt"), trailing: .text("1"), title: id, priority: priority, expires: expires)
    }

    @Test func highestPriorityThenNewestWins() {
        let now = Date()
        let list = [activity("a", .normal), activity("b", .high), activity("c", .high), activity("d", .low)]
        #expect(LiveActivityCenter.pick(list, now: now)?.id == "c")
        #expect(LiveActivityCenter.pick([activity("a", .low), activity("b", .normal)], now: now)?.id == "b")
        #expect(LiveActivityCenter.pick([], now: now) == nil)
    }

    @Test func expiredOnesAreIgnored() {
        let now = Date()
        let list = [activity("old", .high, expires: now.addingTimeInterval(-1)), activity("keep", .low)]
        #expect(LiveActivityCenter.pick(list, now: now)?.id == "keep")
    }

    @MainActor @Test func postReplacesById() {
        let center = LiveActivityCenter()
        center.post(activity("x", .low))
        center.post(activity("x", .high))
        #expect(center.activities.count == 1)
        #expect(center.current()?.priority == .high)
        center.remove("x")
        #expect(center.current() == nil)
    }
}

struct IslandSymbolTests {
    @MainActor @Test func bluetoothSymbols() {
        #expect(IslandFeature.bluetoothSymbol("George's AirPods Pro", audio: true) == "airpodspro")
        #expect(IslandFeature.bluetoothSymbol("AirPods Max", audio: true) == "airpodsmax")
        #expect(IslandFeature.bluetoothSymbol("Magic Keyboard", audio: false) == "keyboard")
        #expect(IslandFeature.bluetoothSymbol("Bose QC", audio: true) == "headphones")
    }
}

struct PlayerInfoTests {
    @Test func readsMusicBroadcast() {
        let info = PlayerInfo(["Player State": "Playing", "Name": "Neighbors", "Artist": "J. Cole", "Album": "4 Your Eyez Only", "Total Time": 216_000], player: .music)
        #expect(info.state == "playing" && info.title == "Neighbors" && info.artist == "J. Cole")
        #expect(info.duration == 216)
        #expect(info.position == nil)
    }

    @Test func readsSpotifyBroadcast() {
        let info = PlayerInfo(["Player State": "Paused", "Name": "Song", "Duration": 180_500.0, "Playback Position": 42.5], player: .spotify)
        #expect(info.state == "paused")
        #expect(abs(info.duration - 180.5) < 0.001)
        #expect(info.position == 42.5)
    }
}

struct WidgetLayoutTests {
    @Test func storedLayoutDropsUnknownAndDuplicates() {
        #expect(IslandWidget.layout(from: ["timer", "nope", "notes", "timer"]) == [.timer, .notes])
    }

    @Test func pagesFitFourColumns() {
        // timer 1 + todos 2 + quick 1 = 4; notes 2 starts a new page.
        let pages = IslandWidget.pages([.timer, .todos, .quickActions, .notes, .stats])
        #expect(pages == [[.timer, .todos, .quickActions], [.notes, .stats]])
        #expect(IslandWidget.pages([]).isEmpty)
    }

    @Test func moveStaysInBounds() {
        let layout: [IslandWidget] = [.timer, .todos, .notes]
        #expect(IslandWidget.move(.timer, by: -1, in: layout) == layout)
        #expect(IslandWidget.move(.timer, by: 1, in: layout) == [.todos, .timer, .notes])
        #expect(IslandWidget.move(.notes, by: 1, in: layout) == layout)
    }
}

struct IslandTimerTests {
    @Test func pauseKeepsTheTimeLeft() {
        let start = Date(timeIntervalSince1970: 1000)
        var timer = IslandTimer(duration: 60)
        timer.start(at: start)
        #expect(timer.timeLeft(at: start.addingTimeInterval(20)) == 40)
        timer.pause(at: start.addingTimeInterval(20))
        #expect(!timer.isRunning)
        #expect(timer.timeLeft(at: start.addingTimeInterval(500)) == 40)
        timer.start(at: start.addingTimeInterval(500))
        #expect(timer.isFinished(at: start.addingTimeInterval(541)))
        #expect(!timer.isFinished(at: start.addingTimeInterval(530)))
    }

    @Test func pomodoroAlternatesWithALongBreakEveryFourth() {
        var focus = IslandTimer(kind: .focus, duration: 1500, round: 0)
        let rest = focus.nextPomodoro()
        #expect(rest?.kind == .rest && rest?.duration == 300 && rest?.round == 1)
        #expect(rest?.nextPomodoro()?.kind == .focus)
        focus.round = 3
        #expect(focus.nextPomodoro()?.duration == 900)
        #expect(IslandTimer(duration: 60).nextPomodoro() == nil)
    }

    @Test func clock() {
        #expect(IslandTimer.clock(59.2) == "1:00")
        #expect(IslandTimer.clock(299) == "4:59")
        #expect(IslandTimer.clock(3725) == "1:02:05")
    }
}

struct SwipeReaderTests {
    @Test func sidewaysAndVerticalOncePerSwipe() {
        var reader = SwipeReader(threshold: 30)
        reader.begin()
        #expect(reader.add(dx: -20, dy: 2) == nil)
        #expect(reader.add(dx: -20, dy: 2) == .left)
        #expect(reader.add(dx: -50, dy: 0) == nil)
        reader.begin()
        #expect(reader.add(dx: 3, dy: 40) == .down)
        reader.begin()
        #expect(reader.add(dx: 2, dy: -40) == .up)
    }

    @Test func diagonalDoesNothing() {
        var reader = SwipeReader(threshold: 30)
        reader.begin()
        #expect(reader.add(dx: 35, dy: 35) == nil)
    }
}

struct DownloadAndMeetingTests {
    @Test func partialDownloads() {
        #expect(DownloadFiles.isPartial("Report.pdf.crdownload"))
        #expect(DownloadFiles.isPartial("movie.mp4.download"))
        #expect(!DownloadFiles.isPartial("Report.pdf"))
        #expect(!DownloadFiles.isPartial(".hidden.part"))
        #expect(DownloadFiles.finalName("Report.pdf.crdownload") == "Report.pdf")
    }

    struct Event { var start: Date; var allDay: Bool }

    @Test func nextMeetingWithinTenMinutes() {
        let now = Date(timeIntervalSince1970: 10_000)
        let events = [Event(start: now.addingTimeInterval(20 * 60), allDay: false),
                      Event(start: now.addingTimeInterval(8 * 60), allDay: false),
                      Event(start: now.addingTimeInterval(60), allDay: true)]
        #expect(MeetingCountdown.next(events, now: now, start: \.start, allDay: \.allDay)?.start == now.addingTimeInterval(8 * 60))
        let started = [Event(start: now.addingTimeInterval(-2 * 60), allDay: false)]
        #expect(MeetingCountdown.next(started, now: now, start: \.start, allDay: \.allDay) != nil)
        let old = [Event(start: now.addingTimeInterval(-10 * 60), allDay: false)]
        #expect(MeetingCountdown.next(old, now: now, start: \.start, allDay: \.allDay) == nil)
    }

    @Test func callLinks() {
        #expect(CalendarSource.callLink(in: [nil, "Room 4", "Join: https://us02web.zoom.us/j/123"])?.host == "us02web.zoom.us")
        #expect(CalendarSource.callLink(in: ["https://example.com"]) == nil)
    }
}

struct TodoTests {
    @Test func openFirst() {
        let a = IslandTodo(title: "a", done: true), b = IslandTodo(title: "b"), c = IslandTodo(title: "c")
        #expect(IslandTodo.sorted([a, b, c]).map(\.title) == ["b", "c", "a"])
    }
}

@MainActor
struct TrayStoreTests {
    @Test func addsDedupesAndRemoves() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tray-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = dir.appendingPathComponent("a.txt"), b = dir.appendingPathComponent("b.txt")
        try Data("a".utf8).write(to: a)
        try Data("b".utf8).write(to: b)

        let store = TrayStore(directory: dir.appendingPathComponent("store"))
        #expect(store.add([a, b]) == 2)
        #expect(store.add([a]) == 0)
        #expect(store.items.count == 2)
        #expect(store.items.first?.name == "a.txt")

        // Saved and read back.
        let reloaded = TrayStore(directory: dir.appendingPathComponent("store"))
        #expect(reloaded.items.map(\.name) == ["a.txt", "b.txt"])

        // Dropped text becomes an owned file, deleted with its item.
        let text = try #require(store.addText("hello", name: "Note"))
        #expect(FileManager.default.fileExists(atPath: text.path))
        store.remove(Set(store.items.filter(\.owned).map(\.id)))
        #expect(!FileManager.default.fileExists(atPath: text.path))

        // Files that vanish are pruned.
        try FileManager.default.removeItem(at: b)
        store.prune()
        #expect(store.items.map(\.name) == ["a.txt"])
        // Removing a referenced file leaves the original alone.
        store.clear()
        #expect(FileManager.default.fileExists(atPath: a.path))
    }
}

struct DragZoneTests {
    @Test func zoneStopsShortOfTheTopEdgeAndReachesWellBelow() {
        let notch = CGRect(x: 662, y: 950, width: 188, height: 32)
        let zone = IslandFeature.dragZone(notch: notch, openSize: CGSize(width: 640, height: 200))
        #expect(zone.contains(CGPoint(x: notch.midX, y: 870)))        // 112 pt below the top
        #expect(zone.contains(CGPoint(x: notch.midX - 300, y: 960)))  // near the left end of the open island
        #expect(!zone.contains(CGPoint(x: notch.midX, y: 800)))       // too far down
        #expect(!zone.contains(CGPoint(x: notch.midX + 400, y: 960))) // beside it
    }

    @Test func clickZoneReachesTheTopEdge() {
        let notch = CGRect(x: 662, y: 950, width: 188, height: 32)
        let zone = IslandFeature.clickZone(notch: notch, size: CGSize(width: 264, height: 32))
        #expect(zone.contains(CGPoint(x: notch.midX, y: 982)))       // the very top pixel row
        #expect(zone.contains(CGPoint(x: notch.minX - 30, y: 970)))  // on a wing
        #expect(!zone.contains(CGPoint(x: notch.midX, y: 940)))      // below the island
        #expect(!zone.contains(CGPoint(x: notch.maxX + 80, y: 970))) // beside it
    }
}

struct SpotifyArtworkTests {
    @Test func onlySpotifyImageServers() {
        #expect(NowPlaying.spotifyImageURL("https://i.scdn.co/image/ab67616d0000b273abc")?.host == "i.scdn.co")
        #expect(NowPlaying.spotifyImageURL("https://image-cdn-ak.spotifycdn.com/image/x") != nil)
        #expect(NowPlaying.spotifyImageURL("http://i.scdn.co/image/x") == nil)
        #expect(NowPlaying.spotifyImageURL("https://evil.example.com/i.scdn.co") == nil)
        #expect(NowPlaying.spotifyImageURL("") == nil)
    }
}
