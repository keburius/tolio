import Testing
@testable import FeatureScreenshots
import OmniCore

@Suite struct MacScreenshotShortcutTests {
    private let shiftCommand4 = KeyCombo(keyCode: 21, modifiers: [.shift, .command])

    private func entry(enabled: Bool, keyCode: Int = 21, flags: Int = 1_179_648) -> [String: Any] {
        ["30": ["enabled": enabled, "value": ["parameters": [52, keyCode, flags], "type": "standard"]]]
    }

    @Test func onAndSameComboConflicts() {
        #expect(MacScreenshotShortcut.conflicts(with: shiftCommand4, symbolicHotKeys: entry(enabled: true)))
    }

    @Test func macDefaultCountsAsOn() {
        #expect(MacScreenshotShortcut.conflicts(with: shiftCommand4, symbolicHotKeys: nil))
        #expect(MacScreenshotShortcut.conflicts(with: shiftCommand4, symbolicHotKeys: [:]))
    }

    @Test func switchedOffDoesNotConflict() {
        #expect(!MacScreenshotShortcut.conflicts(with: shiftCommand4, symbolicHotKeys: entry(enabled: false)))
    }

    @Test func differentCombosDoNotConflict() {
        let tolioOld = KeyCombo(keyCode: 21, modifiers: [.control, .option, .command])
        #expect(!MacScreenshotShortcut.conflicts(with: tolioOld, symbolicHotKeys: entry(enabled: true)))
        // macOS shortcut moved to ⌃⇧⌘4 (flags + control).
        #expect(!MacScreenshotShortcut.conflicts(with: shiftCommand4, symbolicHotKeys: entry(enabled: true, flags: 1_179_648 | 262_144)))
        #expect(!MacScreenshotShortcut.conflicts(with: nil, symbolicHotKeys: entry(enabled: true)))
    }
}
