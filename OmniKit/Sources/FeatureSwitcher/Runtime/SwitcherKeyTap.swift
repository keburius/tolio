import Carbon.HIToolbox
import CoreGraphics
import OmniCore
import OmniPlatform

/// The modifier held while pressing Tab.
public enum SwitcherTrigger: String, Codable, CaseIterable, Sendable {
    case option, command, control

    var flag: CGEventFlags {
        switch self {
        case .option: .maskAlternate
        case .command: .maskCommand
        case .control: .maskControl
        }
    }

    /// The keys alone, e.g. "⌥ Tab" (not translated).
    var keys: String {
        switch self {
        case .option: "⌥ Tab" // l10n-ignore
        case .command: "⌘ Tab" // l10n-ignore
        case .control: "⌃ Tab" // l10n-ignore
        }
    }

    /// As shown in the trigger picker.
    var label: String {
        self == .command ? L10n.Switcher.replacesAppSwitcher(keys) : keys
    }
}

/// Filtering event tap that turns key events into switcher inputs.
///
/// It only swallows: Tab while the trigger modifier is held, and the
/// switcher's keys while the switcher is open. Everything else passes. If
/// macOS disables the tap, it stops (fails open) and `onFailure` runs.
@MainActor
final class SwitcherKeyTap {
    enum Event {
        case begin(backward: Bool)
        case input(SwitcherStateMachine.Input)
    }

    private var tap: EventTap?
    private let trigger: () -> SwitcherTrigger
    private let isOpen: () -> Bool
    private let onEvent: (Event) -> Void
    private let onFailure: () -> Void

    init(
        trigger: @escaping () -> SwitcherTrigger, isOpen: @escaping () -> Bool,
        onEvent: @escaping (Event) -> Void, onFailure: @escaping () -> Void
    ) {
        self.trigger = trigger
        self.isOpen = isOpen
        self.onEvent = onEvent
        self.onFailure = onFailure
    }

    func start() throws {
        let tap = EventTap(mask: EventTap.mask(.keyDown, .flagsChanged), mode: .filtering, handler: { [weak self] type, event in
            self?.handle(type, event) ?? false
        }, onDisabled: { [weak self] in
            self?.tap = nil
            self?.onFailure()
        })
        try tap.start()
        self.tap = tap
    }

    func stop() {
        tap?.stop()
        tap = nil
    }

    /// Returns true to swallow. Real work is deferred so the callback returns fast.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        guard !KeySender.isOwnEvent(event) else { return false }
        let modifierHeld = event.flags.contains(trigger().flag)
        if type == .flagsChanged {
            if isOpen() && !modifierHeld { dispatch(.input(.release)) }
            return false
        }
        let key = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let shift = event.flags.contains(.maskShift)
        if key == kVK_Tab && modifierHeld {
            dispatch(isOpen() ? .input(.tab(backward: shift)) : .begin(backward: shift))
            return true
        }
        guard isOpen() else { return false }
        switch key {
        case kVK_Escape: dispatch(.input(.escape))
        case kVK_Return, kVK_ANSI_KeypadEnter: dispatch(.input(.enter))
        case kVK_LeftArrow, kVK_UpArrow: dispatch(.input(.move(-1)))
        case kVK_RightArrow, kVK_DownArrow: dispatch(.input(.move(1)))
        case kVK_ANSI_Q: dispatch(.input(.quitApp))
        case kVK_ANSI_W: dispatch(.input(.closeWindow))
        default:
            // Any other key closes the switcher and reaches the app, so the
            // keyboard can never stay captured.
            dispatch(.input(.escape))
            return false
        }
        return true
    }

    /// Whether the trigger modifier is physically held right now.
    func isTriggerHeld() -> Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(trigger().flag)
    }

    private func dispatch(_ event: Event) {
        Task { @MainActor [weak self] in self?.onEvent(event) }
    }
}
