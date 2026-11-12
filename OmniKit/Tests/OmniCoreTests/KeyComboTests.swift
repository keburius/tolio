@testable import OmniCore
import Testing

struct KeyComboTests {
    @Test func displayUsesStandardModifierOrder() {
        let combo = KeyCombo(keyCode: 17, modifiers: [.command, .shift, .option, .control])
        #expect(combo.displayString == "⌃⌥⇧⌘T")
    }

    @Test func unknownKeyCodeHasFallbackName() {
        #expect(KeyCombo(keyCode: 200, modifiers: .command).displayString == "⌘Key 200")
    }

    private static let validationCases: [(ModifierSet, KeyComboIssue?)] = [
        (.command, nil),
        (.control, nil),
        ([.option, .command], nil),
        ([], .needsModifier),
        (.shift, .needsModifier),
        (.option, .optionOnlyNotAllowed),
        ([.option, .shift], .optionOnlyNotAllowed),
    ]

    @Test func validation() {
        for (modifiers, expected) in Self.validationCases {
            #expect(KeyCombo(keyCode: 0, modifiers: modifiers).issue == expected, "\(modifiers.symbols)")
        }
    }

    @Test func functionKeysMayBeBare() {
        #expect(KeyCombo(keyCode: 122, modifiers: []).issue == nil) // F1
    }

    @Test func carbonFlagsMatchCarbonConstants() {
        // cmdKey 256, shiftKey 512, optionKey 2048, controlKey 4096
        #expect(ModifierSet.command.carbonFlags == 256)
        #expect(ModifierSet.shift.carbonFlags == 512)
        #expect(ModifierSet.option.carbonFlags == 2048)
        #expect(ModifierSet.control.carbonFlags == 4096)
        #expect(ModifierSet([.command, .control]).carbonFlags == 4352)
    }
}
