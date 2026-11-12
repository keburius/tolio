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
        title: "Test hotkey",
        defaultCombo: KeyCombo(keyCode: 17, modifiers: [.control, .option, .command]) // ⌃⌥⌘T
    )

    public let id: FeatureID = "diagnostics"
    public let displayName = "Diagnostics"
    public let summary = "A test shortcut that confirms global hotkeys work."
    public let symbolName = "stethoscope"
    public let requiredPermissions: Set<Permission> = []
    public let isEnabledByDefault = true

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
            title: "Test Omni",
            subtitle: "Show the test notification",
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
        HUD.show("Test hotkey fired")
    }
}

private struct DiagnosticsSettingsView: View {
    let feature: DiagnosticsFeature

    var body: some View {
        LabeledContent("Times fired") { Text("\(feature.fireCount)").monospacedDigit() }
        LabeledContent("Last fired") {
            if let date = feature.lastFired {
                Text(date, format: .dateTime.hour().minute().second())
            } else {
                Text("Never").foregroundStyle(.secondary)
            }
        }
        Text("Press the test shortcut (see Shortcuts) from any app. A notice appears and the count goes up.")
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}
