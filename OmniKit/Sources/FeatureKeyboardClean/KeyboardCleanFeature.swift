import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Lock Keyboard: locks the keyboard so you can wipe it. Unlock with the
/// mouse; always unlocks by itself at the time limit or if anything goes wrong.
@MainActor
@Observable
public final class KeyboardCleanFeature: Feature {
    public static var startHotkey: HotkeyAction {
        HotkeyAction(
            id: "keyboardclean.start", title: L10n.LockKeyboard.hotkey,
            defaultCombo: KeyCombo(keyCode: 37, modifiers: [.control, .option, .command]) // ⌃⌥⌘L
        )
    }
    static let durationKey = SettingKey.feature("keyboardclean", "duration", default: 120.0)
    /// Gives you time to let go of the shortcut before keys are blocked.
    static let startDelay: Duration = .milliseconds(700)

    enum Anchor {
        static let duration = "lockkeyboard.duration"
        static let lockNow = "lockkeyboard.lockNow"
    }

    public let id: FeatureID = "keyboardclean"
    public var displayName: String { L10n.LockKeyboard.displayName }
    public var summary: String { L10n.LockKeyboard.summary }
    public var tagline: String { L10n.LockKeyboard.tagline }
    public let symbolName = "keyboard.badge.ellipsis"
    public let group: FeatureGroup = .keyboard
    public let requiredPermissions: Set<Permission> = [.accessibility]
    public var declaredHotkeys: [HotkeyAction] { [Self.startHotkey] }

    private(set) var lastEnd: CleaningEndReason?
    @ObservationIgnored private(set) var controller: CleaningController?
    @ObservationIgnored private(set) var settings: SettingsStore?

    public init() {}

    public func enable(context: FeatureContext) throws {
        settings = context.settings
        let controller = CleaningController()
        controller.onEnd = { [weak self] reason in
            self?.lastEnd = reason
            switch reason {
            case .tapDisabled: HUD.show(L10n.LockKeyboard.unlockedStopped, symbol: "keyboard")
            case .timeLimit: HUD.show(L10n.LockKeyboard.unlockedTimeLimit, symbol: "keyboard")
            case .unlockedByUser, .featureDisabled: HUD.show(L10n.LockKeyboard.unlocked, symbol: "keyboard")
            }
        }
        self.controller = controller
        context.lifetime.add { controller.end(.featureDisabled) }
        context.registerHotkey(Self.startHotkey) { [weak self] in self?.startSoon() }
        context.registerCommand(Command(
            id: "keyboardclean.start", title: L10n.LockKeyboard.command, keywords: ["clean", "wipe", "keyboard", "lock"],
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

    public func makeSettingsHero() -> AnyView? {
        AnyView(KeyboardCleanHero())
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
                HUD.show(L10n.LockKeyboard.couldNotLock, symbol: "exclamationmark.triangle")
            }
        }
    }

    /// "30 seconds", "2 minutes".
    static func durationTitle(_ seconds: TimeInterval) -> String {
        seconds < 60 ? L10n.LockKeyboard.seconds(Int(seconds)) : L10n.LockKeyboard.minutes(Int(seconds / 60))
    }
}
