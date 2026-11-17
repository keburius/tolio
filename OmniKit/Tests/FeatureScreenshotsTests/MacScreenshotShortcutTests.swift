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

@Suite struct MacScreenshotShortcutUpdateTests {
    @Test func turningOffKeepsTheComboAndOtherShortcuts() {
        let before: [String: Any] = [
            "30": ["enabled": true, "value": ["type": "standard", "parameters": [52, 21, 1_179_648]]],
            "28": ["enabled": true],
        ]
        let after = MacScreenshotShortcut.updating(before, enabled: false)
        let entry = after["30"] as? [String: Any]
        #expect(entry?["enabled"] as? Bool == false)
        #expect((entry?["value"] as? [String: Any])?["parameters"] as? [Int] == [52, 21, 1_179_648])
        #expect((after["28"] as? [String: Any])?["enabled"] as? Bool == true)
        #expect(!MacScreenshotShortcut.conflicts(with: KeyCombo(keyCode: 21, modifiers: [.shift, .command]), symbolicHotKeys: after))
    }

    @Test func missingEntryGetsMacDefaultAndCanBeRestored() {
        let off = MacScreenshotShortcut.updating(nil, enabled: false)
        let on = MacScreenshotShortcut.updating(off, enabled: true)
        #expect(MacScreenshotShortcut.conflicts(with: KeyCombo(keyCode: 21, modifiers: [.shift, .command]), symbolicHotKeys: on))
    }
}
