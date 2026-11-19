import AppKit
import OmniCore
import SwiftUI

public extension ModifierSet {
    /// Converts AppKit modifier flags, ignoring Caps Lock and Fn.
    init(_ flags: NSEvent.ModifierFlags) {
        var set: ModifierSet = []
        if flags.contains(.control) { set.insert(.control) }
        if flags.contains(.option) { set.insert(.option) }
        if flags.contains(.shift) { set.insert(.shift) }
        if flags.contains(.command) { set.insert(.command) }
        self = set
    }
}

/// Click to record a shortcut. Esc cancels, Delete clears.
///
/// `onRecord` receives the new combo (or `nil` to clear) and returns an error
/// message to show, or `nil` if accepted.
public struct HotkeyRecorderView: View {
    private let combo: KeyCombo?
    private let onRecord: (KeyCombo?) -> String?

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var error: String?

    public init(combo: KeyCombo?, onRecord: @escaping (KeyCombo?) -> String?) {
        self.combo = combo
        self.onRecord = onRecord
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Button(action: toggle) {
                Group {
                    if isRecording {
                        Text(L10n.Shared.recorderPrompt)
                            .font(AS.font(12))
                            .foregroundStyle(AS.text)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(RoundedRectangle(cornerRadius: AS.controlRadius, style: .continuous).fill(AS.blue.opacity(0.25)))
                            .overlay(RoundedRectangle(cornerRadius: AS.controlRadius, style: .continuous).strokeBorder(AS.blue, lineWidth: 1))
                    } else if let combo {
                        KeyCaps(combo.displayString)
                            .padding(.horizontal, 3)
                            .frame(height: 24)
                    } else {
                        Text(L10n.Common.none)
                            .font(AS.font(12))
                            .foregroundStyle(AS.textSecondary)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(RoundedRectangle(cornerRadius: AS.controlRadius, style: .continuous).fill(AS.controlFill))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRecording ? L10n.Shared.recorderPrompt : (combo.map { L10n.A11y.shortcut(KeySpeech.spoken($0.displayString)) } ?? L10n.Common.none))
            .help(L10n.Shared.recorderHelp)
            if let error {
                Text(error).font(AS.footnote).foregroundStyle(AS.red)
            }
        }
        .onDisappear(perform: stop)
    }

    private func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        error = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        let modifiers = ModifierSet(event.modifierFlags)
        let keyCode = UInt32(event.keyCode)
        if modifiers.isEmpty && keyCode == 53 { // Escape
            stop()
            return
        }
        if modifiers.isEmpty && (keyCode == 51 || keyCode == 117) { // Delete, Forward Delete
            error = onRecord(nil)
            stop()
            return
        }
        let candidate = KeyCombo(keyCode: keyCode, modifiers: modifiers)
        if let issue = candidate.issue {
            error = issue.message
            return
        }
        error = onRecord(candidate)
        stop()
    }
}
