import CoreGraphics
@testable import FeatureWindows
import Testing

/// Built-in 1800×1169 display, menu bar 25 pt, Dock 87 pt (this Mac's real numbers).
let builtIn = ScreenInfo(
    frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
    visibleFrame: CGRect(x: 0, y: 39, width: 1800, height: 1043)
)

struct WindowLayoutTests {
    private let visible = CGRect(x: 0, y: 25, width: 1200, height: 900)
    private let window = CGRect(x: 100, y: 100, width: 600, height: 400)

    private func frame(_ action: WindowAction, gap: CGFloat = 0) -> CGRect? {
        WindowLayout.frame(for: action, window: window, visible: visible, gap: gap)
    }

    @Test func halves() {
        #expect(frame(.leftHalf) == CGRect(x: 0, y: 25, width: 600, height: 900))
        #expect(frame(.rightHalf) == CGRect(x: 600, y: 25, width: 600, height: 900))
        #expect(frame(.topHalf) == CGRect(x: 0, y: 25, width: 1200, height: 450))
        #expect(frame(.bottomHalf) == CGRect(x: 0, y: 475, width: 1200, height: 450))
    }

    @Test func thirds() {
        #expect(frame(.firstThird) == CGRect(x: 0, y: 25, width: 400, height: 900))
        #expect(frame(.centerThird) == CGRect(x: 400, y: 25, width: 400, height: 900))
        #expect(frame(.lastThird) == CGRect(x: 800, y: 25, width: 400, height: 900))
        #expect(frame(.firstTwoThirds) == CGRect(x: 0, y: 25, width: 800, height: 900))
        #expect(frame(.lastTwoThirds) == CGRect(x: 400, y: 25, width: 800, height: 900))
    }

    @Test func quarters() {
        #expect(frame(.topLeft) == CGRect(x: 0, y: 25, width: 600, height: 450))
        #expect(frame(.topRight) == CGRect(x: 600, y: 25, width: 600, height: 450))
        #expect(frame(.bottomLeft) == CGRect(x: 0, y: 475, width: 600, height: 450))
        #expect(frame(.bottomRight) == CGRect(x: 600, y: 475, width: 600, height: 450))
    }

    @Test func maximizeAndCenter() {
        #expect(frame(.maximize) == visible)
        #expect(frame(.center) == CGRect(x: 300, y: 275, width: 600, height: 400))
        let huge = CGRect(x: 0, y: 0, width: 5000, height: 5000)
        #expect(WindowLayout.frame(for: .center, window: huge, visible: visible) == visible)
    }

    @Test func nonLayoutActionsReturnNil() {
        #expect(frame(.nextDisplay) == nil)
        #expect(frame(.previousDisplay) == nil)
        #expect(frame(.restore) == nil)
    }

    @Test func gapsSpaceWindowsEvenly() throws {
        let left = try #require(frame(.leftHalf, gap: 10))
        let right = try #require(frame(.rightHalf, gap: 10))
        #expect(left.minX == 10)
        #expect(left.minY == 35)
        #expect(right.minX - left.maxX == 10)
        #expect(right.maxX == 1190)
    }

    @Test func oddSizesProduceWholePoints() throws {
        let odd = CGRect(x: 0, y: 25, width: 1001, height: 777)
        for action in WindowAction.allCases {
            guard let rect = WindowLayout.frame(for: action, window: window, visible: odd) else { continue }
            #expect(rect == rect.integral, "\(action)")
            #expect(odd.insetBy(dx: -1, dy: -1).contains(rect), "\(action)")
        }
    }

    @Test func everyActionHasTitleAndMostHaveShortcuts() {
        for action in WindowAction.allCases {
            #expect(!action.title.isEmpty)
            #expect(action.defaultCombo?.issue == nil)
        }
        let combos = WindowAction.allCases.compactMap(\.defaultCombo)
        #expect(Set(combos).count == combos.count, "default shortcuts must not collide")
    }
}

struct MinimumSizeTests {
    private let bounds = CGRect(x: 0, y: 25, width: 1200, height: 900)

    @Test func rightAnchoredWindowKeepsRightEdge() {
        // Right half target is 600 wide, but the app's minimum width is 800.
        let target = CGRect(x: 600, y: 25, width: 600, height: 900)
        let fitted = WindowLayout.fit(actualSize: CGSize(width: 800, height: 900), target: target, action: .rightHalf, bounds: bounds)
        #expect(fitted == CGRect(x: 400, y: 25, width: 800, height: 900))
    }

    @Test func leftAnchoredWindowKeepsLeftEdge() {
        let target = CGRect(x: 0, y: 25, width: 400, height: 900)
        let fitted = WindowLayout.fit(actualSize: CGSize(width: 700, height: 900), target: target, action: .firstThird, bounds: bounds)
        #expect(fitted.minX == 0)
        #expect(fitted.width == 700)
    }

    @Test func bottomAnchoredWindowKeepsBottomEdge() {
        let target = CGRect(x: 0, y: 475, width: 600, height: 450)
        let fitted = WindowLayout.fit(actualSize: CGSize(width: 600, height: 600), target: target, action: .bottomLeft, bounds: bounds)
        #expect(fitted.maxY == 925)
    }

    @Test func centerThirdStaysCentered() {
        let target = CGRect(x: 400, y: 25, width: 400, height: 900)
        let fitted = WindowLayout.fit(actualSize: CGSize(width: 600, height: 900), target: target, action: .centerThird, bounds: bounds)
        #expect(fitted.midX == target.midX)
    }

    @Test func neverLeavesTheScreen() {
        let target = CGRect(x: 600, y: 25, width: 600, height: 900)
        let fitted = WindowLayout.fit(actualSize: CGSize(width: 1500, height: 1000), target: target, action: .rightHalf, bounds: bounds)
        #expect(bounds.contains(fitted))
    }

    @Test func steppedSizesSmallerThanTargetKeepAnchor() {
        // Terminal rounds 600 down to 596 (character cells): stay on the right edge.
        let target = CGRect(x: 600, y: 25, width: 600, height: 900)
        let fitted = WindowLayout.fit(actualSize: CGSize(width: 596, height: 896), target: target, action: .rightHalf, bounds: bounds)
        #expect(fitted.maxX == 1200)
    }
}

struct MultiDisplayTests {
    /// Primary 1800×1169 at the AppKit origin, external 2560×1440 to its right,
    /// bottoms aligned (AppKit y = 0 for both).
    private var sideBySide: [ScreenInfo] {
        ScreenGeometry.screens(appKitFrames: [
            (CGRect(x: 0, y: 0, width: 1800, height: 1169), CGRect(x: 0, y: 87, width: 1800, height: 1043)),
            (CGRect(x: 1800, y: 0, width: 2560, height: 1440), CGRect(x: 1800, y: 0, width: 2560, height: 1415)),
        ])
    }

    @Test func appKitToAXFlipsAroundPrimary() {
        let screens = sideBySide
        #expect(screens[0] == builtIn)
        // External is taller, so its top is above the primary's top: negative AX y.
        #expect(screens[1].frame == CGRect(x: 1800, y: -271, width: 2560, height: 1440))
        #expect(screens[1].visibleFrame == CGRect(x: 1800, y: -246, width: 2560, height: 1415))
    }

    @Test func roundTripConversion() {
        let rect = CGRect(x: -500, y: 1300, width: 640, height: 480)
        let ax = ScreenGeometry.toAX(rect, primaryHeight: 1169)
        #expect(ScreenGeometry.toAppKit(ax, primaryHeight: 1169) == rect)
    }

    @Test func stackedAboveAndLeftArrangements() {
        let stacked = ScreenGeometry.screens(appKitFrames: [
            (CGRect(x: 0, y: 0, width: 1800, height: 1169), CGRect(x: 0, y: 87, width: 1800, height: 1043)),
            (CGRect(x: -200, y: 1169, width: 1920, height: 1080), CGRect(x: -200, y: 1169, width: 1920, height: 1055)),
            (CGRect(x: -1440, y: 100, width: 1440, height: 900), CGRect(x: -1440, y: 100, width: 1440, height: 900)),
        ])
        #expect(stacked[1].frame == CGRect(x: -200, y: -1080, width: 1920, height: 1080))
        #expect(stacked[2].frame == CGRect(x: -1440, y: 169, width: 1440, height: 900))
        #expect(ScreenGeometry.displayOrder(stacked) == [2, 1, 0])
    }

    @Test func windowBelongsToScreenWithMostOverlap() {
        let screens = sideBySide
        #expect(ScreenGeometry.screenIndex(for: CGRect(x: 1700, y: 100, width: 400, height: 300), in: screens) == 1)
        #expect(ScreenGeometry.screenIndex(for: CGRect(x: 1500, y: 100, width: 400, height: 300), in: screens) == 0)
        #expect(ScreenGeometry.screenIndex(for: CGRect(x: 9000, y: 9000, width: 10, height: 10), in: screens) == 0)
    }

    @Test func layoutsUseTheWindowsOwnScreen() throws {
        let screens = sideBySide
        let window = CGRect(x: 2000, y: 0, width: 800, height: 600)
        let index = try #require(ScreenGeometry.screenIndex(for: window, in: screens))
        let left = try #require(WindowLayout.frame(for: .leftHalf, window: window, visible: screens[index].visibleFrame))
        #expect(left == CGRect(x: 1800, y: -246, width: 1280, height: 1415))
    }

    @Test func moveToOtherDisplayKeepsRelativeFrame() {
        let screens = sideBySide
        let leftHalfOnBuiltIn = CGRect(x: 0, y: 39, width: 900, height: 1043)
        let moved = WindowLayout.move(leftHalfOnBuiltIn, from: screens[0].visibleFrame, to: screens[1].visibleFrame)
        #expect(moved == CGRect(x: 1800, y: -246, width: 1280, height: 1415))
    }

    @Test func moveClampsIntoSmallerDisplay() {
        let small = CGRect(x: 0, y: 0, width: 1000, height: 700)
        let large = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let moved = WindowLayout.move(CGRect(x: 2500, y: 1500, width: 600, height: 600), from: large, to: small)
        #expect(small.contains(moved))
    }
}

struct RestoreHistoryTests {
    private let original = CGRect(x: 100, y: 100, width: 500, height: 400)
    private let left = CGRect(x: 0, y: 25, width: 600, height: 900)
    private let right = CGRect(x: 600, y: 25, width: 600, height: 900)

    @Test func restoresFrameFromBeforeFirstOmniMove() {
        var history = RestoreHistory()
        history.willApply(to: 1, current: original)
        history.didApply(to: 1, actual: left)
        history.willApply(to: 1, current: left)
        history.didApply(to: 1, actual: right)
        #expect(history.restoreFrame(for: 1, current: right) == original)
    }

    @Test func userMoveStartsNewHistory() {
        var history = RestoreHistory()
        history.willApply(to: 1, current: original)
        history.didApply(to: 1, actual: left)
        let dragged = CGRect(x: 300, y: 300, width: 500, height: 400)
        #expect(history.restoreFrame(for: 1, current: dragged) == nil)
        history.willApply(to: 1, current: dragged)
        history.didApply(to: 1, actual: right)
        #expect(history.restoreFrame(for: 1, current: right) == dragged)
    }

    @Test func smallAppAdjustmentsStillCount() {
        var history = RestoreHistory()
        history.willApply(to: 1, current: original)
        history.didApply(to: 1, actual: left)
        #expect(history.restoreFrame(for: 1, current: left.insetBy(dx: 1, dy: 1)) == original)
    }

    @Test func unknownWindowHasNothing() {
        #expect(RestoreHistory().restoreFrame(for: 9, current: original) == nil)
    }

    @Test func capacityIsBounded() {
        var history = RestoreHistory()
        for id in 0...UInt32(RestoreHistory.capacity + 10) {
            history.willApply(to: id, current: original)
        }
        #expect(history.count == RestoreHistory.capacity)
        #expect(history.restoreFrame(for: 0, current: original) == nil) // oldest evicted
    }
}

struct SnapZoneTests {
    private let sideBySide = [
        builtIn,
        ScreenInfo(frame: CGRect(x: 1800, y: -271, width: 2560, height: 1440), visibleFrame: CGRect(x: 1800, y: -246, width: 2560, height: 1415)),
    ]

    @Test func edgesOfASingleDisplay() {
        let screens = [builtIn]
        #expect(SnapZones.action(at: CGPoint(x: 0, y: 500), screens: screens) == .leftHalf)
        #expect(SnapZones.action(at: CGPoint(x: 1799, y: 500), screens: screens) == .rightHalf)
        #expect(SnapZones.action(at: CGPoint(x: 900, y: 0), screens: screens) == .maximize)
        #expect(SnapZones.action(at: CGPoint(x: 900, y: 1168), screens: screens) == nil)
        #expect(SnapZones.action(at: CGPoint(x: 900, y: 500), screens: screens) == nil)
    }

    @Test func corners() {
        let screens = [builtIn]
        #expect(SnapZones.action(at: CGPoint(x: 0, y: 10), screens: screens) == .topLeft)
        #expect(SnapZones.action(at: CGPoint(x: 1799, y: 1160), screens: screens) == .bottomRight)
        #expect(SnapZones.action(at: CGPoint(x: 1790, y: 0), screens: screens) == .topRight)
        #expect(SnapZones.action(at: CGPoint(x: 5, y: 1168), screens: screens) == .bottomLeft)
    }

    @Test func sharedEdgesDoNotSnap() {
        // The built-in's right edge touches the external display.
        #expect(SnapZones.action(at: CGPoint(x: 1799, y: 500), screens: sideBySide) == nil)
        #expect(SnapZones.action(at: CGPoint(x: 1800, y: 500), screens: sideBySide) == nil)
        // The external's far right edge is open.
        #expect(SnapZones.action(at: CGPoint(x: 4359, y: 500), screens: sideBySide) == .rightHalf)
        // The external's top edge (above the built-in's top) is open.
        #expect(SnapZones.action(at: CGPoint(x: 3000, y: -271), screens: sideBySide) == .maximize)
    }

    @Test func pointOutsideAllScreens() {
        #expect(SnapZones.action(at: CGPoint(x: -50, y: -50), screens: [builtIn]) == nil)
    }
}
