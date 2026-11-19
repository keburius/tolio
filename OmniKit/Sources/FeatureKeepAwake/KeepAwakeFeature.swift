import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Prevents idle sleep: indefinitely, for a time, or while chosen apps run.
///
/// Observable, so the menu bar icon and Settings follow `session` and `statusText`.
@MainActor
@Observable
public final class KeepAwakeFeature: Feature {
    public static var toggleHotkey: HotkeyAction {
        HotkeyAction(
            id: "keepawake.toggle", title: L10n.KeepAwake.toggleHotkey,
            defaultCombo: KeyCombo(keyCode: 0, modifiers: [.control, .option, .command]) // ⌃⌥⌘A
        )
    }
    static let displayKey = SettingKey.feature("keepawake", "keepDisplayOn", default: true)
    static let ruleAppsKey = SettingKey.feature("keepawake", "whileRunning", default: [String: String]()) // bundle id → name

    enum Anchor {
        static let status = "keepawake.status"
        static let display = "keepawake.keepDisplayOn"
        static let apps = "keepawake.whileRunning"
    }

    public let id: FeatureID = "keepawake"
    public var displayName: String { L10n.KeepAwake.displayName }
    public var summary: String { L10n.KeepAwake.summary }
    public var tagline: String { L10n.KeepAwake.tagline }
    public let symbolName = "bolt"
    public let group: FeatureGroup = .energy
    public let requiredPermissions: Set<Permission> = []
    public let isEnabledByDefault = true
    public var declaredHotkeys: [HotkeyAction] { [Self.toggleHotkey] }

    /// The manual session (read-only for display).
    private(set) var session: KeepAwakeSession = .off
    private(set) var statusText: String?
    @ObservationIgnored private let assertion = PowerAssertion()
    @ObservationIgnored private(set) var settings: SettingsStore?
    @ObservationIgnored private var endTimer: Timer?
    @ObservationIgnored private var appObservers: [NSObjectProtocol] = []

    public init() {}

    public func enable(context: FeatureContext) throws {
        settings = context.settings
        session = .off
        context.lifetime.add { [weak self] in self?.tearDown() }
        context.registerHotkey(Self.toggleHotkey) { [weak self] in self?.toggle() }
        context.registerCommand(Command(
            id: "keepawake.on", title: L10n.KeepAwake.commandOn, subtitle: L10n.KeepAwake.commandOnSubtitle,
            keywords: ["energy", "caffeine", "sleep", "awake", "keep awake"], symbolName: symbolName
        ) { [weak self] in self?.start(.indefinite) })
        for preset in KeepAwakePolicy.presets {
            context.registerCommand(Command(
                id: "keepawake.\(preset.minutes)", title: L10n.KeepAwake.commandFor(preset.title), keywords: ["energy", "caffeine", "sleep", "awake", "keep awake"],
                symbolName: "timer"
            ) { [weak self] in self?.start(minutes: preset.minutes) })
        }
        context.registerCommand(Command(
            id: "keepawake.off", title: L10n.KeepAwake.commandOff, keywords: ["energy", "caffeine", "sleep", "awake"], symbolName: "moon.zzz"
        ) { [weak self] in self?.start(.off) })
        updateRuleObservers()
    }

    public func disable() {
        settings = nil
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(KeepAwakeSettingsView(feature: self, settings: settings))
    }

    public func makeSettingsHero() -> AnyView? {
        AnyView(KeepAwakeHero())
    }

    // MARK: - Control

    func toggle() {
        start(KeepAwakePolicy.effective(session, now: Date()) == .off ? .indefinite : .off)
    }

    /// Keeps awake for a preset number of minutes from now.
    func start(minutes: Int) {
        start(.until(Date().addingTimeInterval(TimeInterval(minutes * 60))))
    }

    func start(_ newSession: KeepAwakeSession) {
        session = newSession
        endTimer?.invalidate()
        endTimer = nil
        if case let .until(end) = newSession {
            // One timer for the end time; no polling.
            let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.start(.off) }
            }
            RunLoop.main.add(timer, forMode: .common)
            endTimer = timer
        }
        apply()
        HUD.show(statusText ?? L10n.KeepAwake.sleepAllowed, symbol: statusText == nil ? "moon.zzz" : "bolt.fill")
    }

    /// Re-evaluates and holds or releases the assertion.
    func apply() {
        guard let settings else { return }
        let rules = settings.value(Self.ruleAppsKey)
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let activeRules = rules.filter { running.contains($0.key) }.map(\.value)
        let now = Date()
        if KeepAwakePolicy.shouldHold(session: session, now: now, ruleApps: Set(rules.keys), running: running) {
            assertion.hold(settings.value(Self.displayKey) ? .display : .system, reason: "Omni Keep Awake")
        } else {
            assertion.release()
        }
        statusText = KeepAwakePolicy.describe(session: session, now: now, activeRuleApps: activeRules)
    }

    var isHolding: Bool { assertion.isHeld }

    func setKeepDisplayOn(_ isOn: Bool) {
        settings?.set(isOn, for: Self.displayKey)
        apply()
    }

    func setRule(_ bundleID: String, name: String?, enabled: Bool) {
        guard let settings else { return }
        var rules = settings.value(Self.ruleAppsKey)
        rules[bundleID] = enabled ? (name ?? bundleID) : nil
        settings.set(rules, for: Self.ruleAppsKey)
        updateRuleObservers()
    }

    /// Empties the while-running app list.
    func removeAllRules() {
        guard let settings else { return }
        settings.set([:], for: Self.ruleAppsKey)
        updateRuleObservers()
    }

    /// App launch/quit observers exist only while there are rule apps.
    private func updateRuleObservers() {
        let needed = !(settings?.value(Self.ruleAppsKey).isEmpty ?? true)
        if needed && appObservers.isEmpty {
            let center = NSWorkspace.shared.notificationCenter
            for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
                appObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.apply() }
                })
            }
        } else if !needed {
            removeRuleObservers()
        }
        apply()
    }

    private func removeRuleObservers() {
        appObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        appObservers.removeAll()
    }

    private func tearDown() {
        endTimer?.invalidate()
        endTimer = nil
        removeRuleObservers()
        assertion.release()
        session = .off
        statusText = nil
    }
}
