@testable import FeatureKeepAwake
import Foundation
import Testing

struct KeepAwakePolicyTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func manualSessions() {
        #expect(!KeepAwakePolicy.shouldHold(session: .off, now: now, ruleApps: [], running: []))
        #expect(KeepAwakePolicy.shouldHold(session: .indefinite, now: now, ruleApps: [], running: []))
        #expect(KeepAwakePolicy.shouldHold(session: .until(now.addingTimeInterval(60)), now: now, ruleApps: [], running: []))
    }

    @Test func timedSessionExpires() {
        let session = KeepAwakeSession.until(now)
        #expect(KeepAwakePolicy.effective(session, now: now) == .off)
        #expect(!KeepAwakePolicy.shouldHold(session: session, now: now.addingTimeInterval(1), ruleApps: [], running: []))
    }

    @Test func ruleAppsHoldOnlyWhileRunning() {
        let rules: Set = ["com.apple.dt.Xcode"]
        #expect(KeepAwakePolicy.shouldHold(session: .off, now: now, ruleApps: rules, running: ["com.apple.dt.Xcode", "x"]))
        #expect(!KeepAwakePolicy.shouldHold(session: .off, now: now, ruleApps: rules, running: ["com.apple.Safari"]))
    }

    @Test func descriptions() {
        #expect(KeepAwakePolicy.describe(session: .off, now: now, activeRuleApps: []) == nil)
        #expect(KeepAwakePolicy.describe(session: .indefinite, now: now, activeRuleApps: []) == "Keeping awake until you turn it off")
        let both = KeepAwakePolicy.describe(session: .indefinite, now: now, activeRuleApps: ["Xcode"])
        #expect(both == "Keeping awake until you turn it off and while Xcode is running")
        let two = KeepAwakePolicy.describe(session: .off, now: now, activeRuleApps: ["Zoom", "Xcode"])
        #expect(two == "Keeping awake while Xcode, Zoom are running")
        let timed = KeepAwakePolicy.describe(session: .until(now.addingTimeInterval(3600)), now: now, activeRuleApps: [])
        #expect(timed?.hasPrefix("Keeping awake until ") == true)
    }
}
