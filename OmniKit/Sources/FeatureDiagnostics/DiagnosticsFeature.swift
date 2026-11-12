import Observation
import OmniCore
import OmniPlatform
import os
import SwiftUI

/// A test hotkey that confirms global shortcuts work end to end.
@MainActor
@Observable
public final class DiagnosticsFeature: Feature {
    public static let testHotkey = HotkeyAction(
        id: "diagnostics.test",
        title: L10n.Diagnostics.testShortcut,
        defaultCombo: KeyCombo(keyCode: 17, modifiers: [.control, .option, .command]) // ⌃⌥⌘T
    )

    public let id: FeatureID = "diagnostics"
    public var displayName: String { L10n.Diagnostics.name }
    public var summary: String { L10n.Diagnostics.summary }
    public let symbolName = "stethoscope"
    public let requiredPermissions: Set<Permission> = []
    public let isEnabledByDefault = false
    public var isHidden: Bool { true }
    public var declaredHotkeys: [HotkeyAction] { [Self.testHotkey] }

    /// How often the test hotkey fired since the feature was enabled.
    public private(set) var fireCount = 0
    public private(set) var lastFired: Date?
    @ObservationIgnored private var log: Logger?

    public init() {}

    public func enable(context: FeatureContext) throws {
        log = context.log
        fireCount = 0
        lastFired = nil
        context.registerHotkey(Self.testHotkey) { [weak self] in self?.fire() }
        context.registerCommand(Command(
            id: "diagnostics.test",
            title: L10n.Diagnostics.testOmni,
            subtitle: L10n.Diagnostics.testOmniSubtitle,
            keywords: ["diagnostics", "hotkey"],
            symbolName: symbolName
        ) { [weak self] in self?.fire() })
    }

    public func disable() {
        log = nil
    }

    public func makeSettingsView() -> AnyView {
        AnyView(DiagnosticsSettingsView(feature: self))
    }

    func fire() {
        fireCount += 1
        lastFired = Date()
        log?.info("Test hotkey fired, count \(self.fireCount)")
        HUD.show(L10n.Diagnostics.fired)
    }
}

private struct DiagnosticsSettingsView: View {
    let feature: DiagnosticsFeature

    var body: some View {
        LabeledContent(L10n.Diagnostics.timesFired) { Text("\(feature.fireCount)").monospacedDigit() }
        LabeledContent(L10n.Diagnostics.lastFired) {
            if let date = feature.lastFired {
                Text(date, format: .dateTime.hour().minute().second())
            } else {
                Text(L10n.Diagnostics.never).foregroundStyle(.secondary)
            }
        }
        Text(L10n.Diagnostics.help)
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}
