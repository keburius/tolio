import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Prevents idle sleep: indefinitely, for a time, or while chosen apps run.
@MainActor
@Observable
public final class KeepAwakeFeature: Feature {
    public static let toggleHotkey = HotkeyAction(
        id: "keepawake.toggle", title: "Toggle keep awake",
        defaultCombo: KeyCombo(keyCode: 0, modifiers: [.control, .option, .command]) // ⌃⌥⌘A
    )
    static let displayKey = SettingKey.feature("keepawake", "keepDisplayOn", default: true)
    static let ruleAppsKey = SettingKey.feature("keepawake", "whileRunning", default: [String: String]()) // bundle id → name

    public let id: FeatureID = "keepawake"
    public let displayName = "Keep Awake"
    public let summary = "Stop your Mac from sleeping: indefinitely, for a while, or while certain apps run."
    public let symbolName = "cup.and.saucer"
    public let requiredPermissions: Set<Permission> = []
    public let isEnabledByDefault = true

    private(set) var session: KeepAwakeSession = .off
    private(set) var statusText: String?
    @ObservationIgnored private let assertion = PowerAssertion()
    @ObservationIgnored private var settings: SettingsStore?
    @ObservationIgnored private var endTimer: Timer?
    @ObservationIgnored private var appObservers: [NSObjectProtocol] = []

    public init() {}

    public func enable(context: FeatureContext) throws {
        settings = context.settings
        session = .off
        context.lifetime.add { [weak self] in self?.tearDown() }
        context.registerHotkey(Self.toggleHotkey) { [weak self] in self?.toggle() }
        context.registerCommand(Command(
            id: "keepawake.on", title: "Keep Awake", subtitle: "Until turned off", keywords: ["caffeine", "sleep", "awake"],
            symbolName: symbolName
        ) { [weak self] in self?.start(.indefinite) })
        for preset in KeepAwakePolicy.presets {
            context.registerCommand(Command(
                id: "keepawake.\(preset.minutes)", title: "Keep Awake for \(preset.title)", keywords: ["caffeine", "sleep", "awake"],
                symbolName: "timer"
            ) { [weak self] in self?.start(.until(Date().addingTimeInterval(TimeInterval(preset.minutes * 60)))) })
        }
        context.registerCommand(Command(
            id: "keepawake.off", title: "Stop Keeping Awake", keywords: ["caffeine", "sleep"], symbolName: "moon.zzz"
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

    // MARK: - Control

    func toggle() {
        start(KeepAwakePolicy.effective(session, now: Date()) == .off ? .indefinite : .off)
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
        HUD.show(statusText ?? "Sleep allowed again", symbol: statusText == nil ? "moon.zzz" : "cup.and.saucer")
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

    func setRule(_ bundleID: String, name: String?, enabled: Bool) {
        guard let settings else { return }
        var rules = settings.value(Self.ruleAppsKey)
        rules[bundleID] = enabled ? (name ?? bundleID) : nil
        settings.set(rules, for: Self.ruleAppsKey)
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

struct KeepAwakeSettingsView: View {
    let feature: KeepAwakeFeature
    let settings: SettingsStore

    var body: some View {
        LabeledContent("Status") {
            Text(feature.statusText ?? "Off").foregroundStyle(feature.isHolding ? .green : .secondary)
        }
        HStack {
            Button("Keep Awake") { feature.start(.indefinite) }
            Menu("For…") {
                ForEach(KeepAwakePolicy.presets, id: \.minutes) { preset in
                    Button(preset.title) { feature.start(.until(Date().addingTimeInterval(TimeInterval(preset.minutes * 60)))) }
                }
            }
            .fixedSize()
            Button("Stop") { feature.start(.off) }.disabled(feature.statusText == nil)
        }
        Toggle("Keep the display on too", isOn: Binding(
            get: { settings.value(KeepAwakeFeature.displayKey) },
            set: { settings.set($0, for: KeepAwakeFeature.displayKey); feature.apply() }
        ))
        Section("Also keep awake while these apps run") {
            let rules = settings.value(KeepAwakeFeature.ruleAppsKey)
            ForEach(rules.sorted { $0.value < $1.value }, id: \.key) { bundleID, name in
                HStack {
                    Text(name)
                    Spacer()
                    Button("Remove") { feature.setRule(bundleID, name: nil, enabled: false) }.buttonStyle(.borderless)
                }
            }
            Menu("Add App") {
                ForEach(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && rules[$0.bundleIdentifier ?? ""] == nil }
                    .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }, id: \.processIdentifier) { app in
                    Button(app.localizedName ?? "App") {
                        if let id = app.bundleIdentifier { feature.setRule(id, name: app.localizedName, enabled: true) }
                    }
                }
            }
            .fixedSize()
        }
    }
}
