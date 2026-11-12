import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Locks the keyboard so you can wipe it. Unlock with the mouse; always
/// unlocks by itself at the time limit or if anything goes wrong.
@MainActor
@Observable
public final class KeyboardCleanFeature: Feature {
    public static let startHotkey = HotkeyAction(
        id: "keyboardclean.start", title: "Lock keyboard for cleaning",
        defaultCombo: KeyCombo(keyCode: 37, modifiers: [.control, .option, .command]) // ⌃⌥⌘L
    )
    static let durationKey = SettingKey.feature("keyboardclean", "duration", default: 120.0)
    /// Gives you time to let go of the shortcut before keys are blocked.
    static let startDelay: Duration = .milliseconds(700)

    public let id: FeatureID = "keyboardclean"
    public let displayName = "Keyboard Cleaning"
    public let summary = "Lock the keyboard while you wipe it. Unlock with the mouse; it also unlocks by itself."
    public let symbolName = "keyboard.badge.ellipsis"
    public let requiredPermissions: Set<Permission> = [.accessibility]

    private(set) var lastEnd: CleaningEndReason?
    @ObservationIgnored private var controller: CleaningController?
    @ObservationIgnored private var settings: SettingsStore?

    public init() {}

    public func enable(context: FeatureContext) throws {
        settings = context.settings
        let controller = CleaningController()
        controller.onEnd = { [weak self] reason in
            self?.lastEnd = reason
            switch reason {
            case .tapDisabled: HUD.show("Keyboard unlocked: macOS stopped the lock", symbol: "keyboard")
            case .timeLimit: HUD.show("Keyboard unlocked (time limit)", symbol: "keyboard")
            case .unlockedByUser, .featureDisabled: HUD.show("Keyboard unlocked", symbol: "keyboard")
            }
        }
        self.controller = controller
        context.lifetime.add { controller.end(.featureDisabled) }
        context.registerHotkey(Self.startHotkey) { [weak self] in self?.startSoon() }
        context.registerCommand(Command(
            id: "keyboardclean.start", title: "Lock Keyboard for Cleaning", keywords: ["clean", "wipe", "keyboard", "lock"],
            symbolName: symbolName
        ) { [weak self] in self?.startSoon() })
    }

    public func disable() {
        controller = nil
        settings = nil
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(KeyboardCleanSettingsView(feature: self, settings: settings))
    }

    func startSoon() {
        guard let controller, !controller.isActive else { return }
        let duration = settings?.value(Self.durationKey) ?? 120
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.startDelay)
            do {
                try controller.start(duration: duration)
            } catch {
                self?.lastEnd = .tapDisabled
                HUD.show("Couldn't lock the keyboard. Check Accessibility.", symbol: "exclamationmark.triangle")
            }
        }
    }
}

struct KeyboardCleanSettingsView: View {
    let feature: KeyboardCleanFeature
    let settings: SettingsStore

    var body: some View {
        Picker("Unlock automatically after", selection: settings.binding(KeyboardCleanFeature.durationKey)) {
            ForEach(CleaningSession.durationChoices, id: \.self) { seconds in
                Text(seconds < 60 ? "\(Int(seconds)) seconds" : "\(Int(seconds / 60)) minute\(seconds == 60 ? "" : "s")").tag(seconds)
            }
        }
        Button("Lock Keyboard Now") { feature.startSoon() }
        Text("All keys, including media and brightness keys, are blocked. The power button and Touch ID can't be blocked. Click Unlock with the mouse, or wait for the time limit. If macOS stops the lock for any reason, the keyboard works again immediately.")
            .font(.caption).foregroundStyle(.secondary)
    }
}
