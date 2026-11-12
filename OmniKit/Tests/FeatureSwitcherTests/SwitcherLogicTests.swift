import CoreGraphics
@testable import FeatureSwitcher
import Testing

private let ownPID: pid_t = 999
private let apps: [pid_t: WindowSources.App] = [
    1: .init(pid: 1, name: "Safari", bundleID: "com.apple.Safari", isHidden: false),
    2: .init(pid: 2, name: "Notes", bundleID: "com.apple.Notes", isHidden: false),
    3: .init(pid: 3, name: "Mail", bundleID: "com.apple.mail", isHidden: true),
    ownPID: .init(pid: ownPID, name: "Omni", bundleID: "com.george.omni", isHidden: false),
]
private let big = CGRect(x: 0, y: 0, width: 800, height: 600)

private func server(_ id: CGWindowID, pid: pid_t, onScreen: Bool = true, title: String? = nil, layer: Int = 0,
                    bounds: CGRect = big, alpha: Double = 1) -> WindowSources.ServerWindow {
    .init(id: id, pid: pid, layer: layer, bounds: bounds, isOnScreen: onScreen, alpha: alpha, title: title)
}

private func ax(_ id: CGWindowID, _ title: String, minimized: Bool = false, standard: Bool = true) -> (CGWindowID, WindowSources.AXInfo) {
    (id, .init(id: id, title: title, isMinimized: minimized, isStandard: standard))
}

struct WindowListBuilderTests {
    private func build(_ server: [WindowSources.ServerWindow], _ axList: [(CGWindowID, WindowSources.AXInfo)],
                       options: WindowListOptions = .init()) -> [WindowRecord] {
        WindowListBuilder.build(server: server, ax: Dictionary(uniqueKeysWithValues: axList), apps: apps, ownPID: ownPID, options: options)
    }

    @Test func mergesTitlesAndStates() {
        let records = build(
            [server(10, pid: 1), server(11, pid: 2, onScreen: false), server(12, pid: 3, onScreen: false)],
            [ax(10, "Apple"), ax(11, "Shopping", minimized: true), ax(12, "Inbox")]
        )
        #expect(records.map(\.title) == ["Apple", "Shopping", "Inbox"])
        #expect(records.map(\.state) == [.normal, .minimized, .hidden])
        #expect(records[0].appName == "Safari")
    }

    @Test func excludesOwnNonRegularSmallAndOverlayWindows() {
        let records = build(
            [
                server(1, pid: ownPID),
                server(2, pid: 42), // not a regular app
                server(3, pid: 1, bounds: CGRect(x: 0, y: 0, width: 30, height: 30)),
                server(4, pid: 1, layer: 25), // status/overlay layer
                server(5, pid: 1, alpha: 0),
                server(6, pid: 1),
            ],
            [ax(1, "Omni"), ax(2, "x"), ax(3, "tiny"), ax(4, "overlay"), ax(5, "invisible"), ax(6, "Real")]
        )
        #expect(records.map(\.id) == [6])
    }

    @Test func nonStandardAXWindowsAreSkipped() {
        #expect(build([server(1, pid: 1)], [ax(1, "Inspector", standard: false)]).isEmpty)
    }

    @Test func otherSpaceWindowsNeedTitleAndSize() {
        let records = build(
            [
                server(1, pid: 1, onScreen: false, title: "On Space 2"),
                server(2, pid: 1, onScreen: false, title: nil),              // no Screen Recording: no title
                server(3, pid: 1, onScreen: false, title: "helper", bounds: CGRect(x: 0, y: 0, width: 150, height: 90)),
            ],
            []
        )
        #expect(records.map(\.id) == [1])
        #expect(records[0].state == .otherSpace)
    }

    @Test func optionsFilterStates() {
        let windows = [server(1, pid: 1), server(2, pid: 2, onScreen: false), server(3, pid: 3), server(4, pid: 1, onScreen: false, title: "Far")]
        let infos = [ax(1, "a"), ax(2, "b", minimized: true), ax(3, "c")]
        let none = build(windows, infos, options: .init(includeMinimized: false, includeHidden: false, includeOtherSpaces: false))
        #expect(none.map(\.id) == [1])
        #expect(build(windows, infos).map(\.id) == [1, 2, 3, 4])
    }

    @Test func emptyTitleFallsBackToServerThenAppName() {
        let records = build([server(1, pid: 1, title: "Server Title"), server(2, pid: 2)], [ax(1, ""), ax(2, "")])
        #expect(records.map(\.title) == ["Server Title", "Notes"])
    }

    @Test func duplicateServerEntriesAreDropped() {
        #expect(build([server(1, pid: 1), server(1, pid: 1)], [ax(1, "a")]).count == 1)
    }
}

struct OrderingTests {
    private func record(_ id: CGWindowID, _ state: WindowState = .normal) -> WindowRecord {
        WindowRecord(id: id, pid: 1, appName: "A", bundleID: nil, title: "\(id)", frame: big, state: state)
    }

    @Test func recencyFirstThenStackingOrder() {
        let records = [1, 2, 3, 4].map { record($0) }
        let sorted = SwitcherOrdering.sort(records, recency: [3, 1], zOrder: [4, 2, 1, 3])
        #expect(sorted.map(\.id) == [3, 1, 4, 2])
    }

    @Test func minimizedThenHiddenGoLast() {
        let records = [record(1, .hidden), record(2, .minimized), record(3), record(4, .otherSpace)]
        let sorted = SwitcherOrdering.sort(records, recency: [1, 2, 4, 3], zOrder: [])
        #expect(sorted.map(\.id) == [4, 3, 2, 1])
    }

    @Test func trackerMovesToFrontAndPrunes() {
        var tracker = RecencyTracker()
        [1, 2, 3, 2].forEach { tracker.touch($0) }
        #expect(tracker.order == [2, 3, 1])
        tracker.retain(only: [1, 2])
        #expect(tracker.order == [2, 1])
    }

    @Test func trackerIsBounded() {
        var tracker = RecencyTracker()
        for id in 0..<CGWindowID(RecencyTracker.capacity + 50) { tracker.touch(id) }
        #expect(tracker.order.count == RecencyTracker.capacity)
        #expect(tracker.order.first == CGWindowID(RecencyTracker.capacity + 49))
    }
}

struct StateMachineTests {
    @Test func tabOpensOnPreviousWindowAndReleaseActivates() {
        var machine = SwitcherStateMachine()
        do { let result = machine.begin(count: 4, backward: false); #expect(result) }
        #expect(machine.selection == 1)
        do { let result = machine.handle(.tab(backward: false)); #expect(result == [.select(2)]) }
        do { let result = machine.handle(.release); #expect(result == [.activate(2)]) }
        #expect(!machine.isActive)
    }

    @Test func shiftTabStartsAtEndAndWraps() {
        var machine = SwitcherStateMachine()
        _ = machine.begin(count: 3, backward: true)
        #expect(machine.selection == 2)
        _ = machine.handle(.tab(backward: false))
        #expect(machine.selection == 0)
        _ = machine.handle(.tab(backward: true))
        #expect(machine.selection == 2)
    }

    @Test func singleWindowSelectsItself() {
        var machine = SwitcherStateMachine()
        _ = machine.begin(count: 1, backward: false)
        #expect(machine.selection == 0)
    }

    @Test func emptyListDoesNotOpen() {
        var machine = SwitcherStateMachine()
        do { let opened = machine.begin(count: 0, backward: false); #expect(!opened) }
        do { let result = machine.handle(.release); #expect(result.isEmpty) }
    }

    @Test func arrowsClampEscapeCancels() {
        var machine = SwitcherStateMachine()
        _ = machine.begin(count: 3, backward: false)
        do { let result = machine.handle(.move(10)); #expect(result == [.select(2)]) }
        do { let result = machine.handle(.move(-10)); #expect(result == [.select(0)]) }
        do { let result = machine.handle(.escape); #expect(result == [.cancel]) }
        do { let result = machine.handle(.tab(backward: false)); #expect(result.isEmpty) }
    }

    @Test func quitAndCloseKeepItOpen() {
        var machine = SwitcherStateMachine()
        _ = machine.begin(count: 3, backward: false)
        do { let result = machine.handle(.quitApp); #expect(result == [.quitApp(1)]) }
        do { let result = machine.handle(.closeWindow); #expect(result == [.closeWindow(1)]) }
        #expect(machine.isActive)
    }

    @Test func listChangesClampSelectionOrCancelWhenEmpty() {
        var machine = SwitcherStateMachine()
        _ = machine.begin(count: 3, backward: true)
        do { let result = machine.handle(.listChanged(count: 2)); #expect(result == [.select(1)]) }
        do { let result = machine.handle(.listChanged(count: 0)); #expect(result == [.cancel]) }
        #expect(!machine.isActive)
    }

    @Test func clickActivatesValidRow() {
        var machine = SwitcherStateMachine()
        _ = machine.begin(count: 3, backward: false)
        do { let result = machine.handle(.click(7)); #expect(result.isEmpty) }
        do { let result = machine.handle(.click(2)); #expect(result == [.activate(2)]) }
    }
}
