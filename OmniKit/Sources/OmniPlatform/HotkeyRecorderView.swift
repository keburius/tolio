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
                Text(label)
                    .monospaced()
                    .frame(minWidth: 110)
                    .foregroundStyle(isRecording ? Color.accentColor : .primary)
            }
            .help("Click, then press a shortcut. Esc cancels, Delete clears.")
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .onDisappear(perform: stop)
    }

    private var label: String {
        if isRecording { return "Type shortcut…" }
        return combo?.displayString ?? "None"
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
