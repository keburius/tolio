import Testing
@testable import FeatureShortcutOverlay

struct ShortcutFormatterTests {
    @Test func modifierOrderAndImpliedCommand() {
        #expect(ShortcutFormatter.modifierSymbols(0) == "⌘")
        #expect(ShortcutFormatter.modifierSymbols(1) == "⇧⌘")
        #expect(ShortcutFormatter.modifierSymbols(1 | 2 | 4) == "⌃⌥⇧⌘")
        #expect(ShortcutFormatter.modifierSymbols(8) == "")
        #expect(ShortcutFormatter.modifierSymbols(4 | 8) == "⌃")
    }

    @Test func functionModifier() {
        // Values read from Finder's Edit and View menus.
        #expect(ShortcutFormatter.format(cmdChar: "E", modifiers: 24, glyph: nil, virtualKey: nil) == "fn E")
        #expect(ShortcutFormatter.format(cmdChar: "F", modifiers: 24, glyph: nil, virtualKey: nil) == "fn F")
        #expect(ShortcutFormatter.format(cmdChar: "F", modifiers: 16 | 4, glyph: nil, virtualKey: nil) == "fn ⌃⌘F")
        // Dictation: the 🎤 key itself, no modifiers.
        #expect(ShortcutFormatter.format(cmdChar: "🎤", modifiers: 8, glyph: 150, virtualKey: 128) == "🎤")
    }

    @Test func characterKeys() {
        #expect(ShortcutFormatter.format(cmdChar: "s", modifiers: 0, glyph: nil, virtualKey: nil) == "⌘S")
        #expect(ShortcutFormatter.format(cmdChar: "S", modifiers: 1, glyph: nil, virtualKey: nil) == "⇧⌘S")
        #expect(ShortcutFormatter.format(cmdChar: ",", modifiers: 0, glyph: nil, virtualKey: nil) == "⌘,")
        #expect(ShortcutFormatter.format(cmdChar: "/", modifiers: 2, glyph: 0, virtualKey: nil) == "⌥⌘/")
    }

    @Test func glyphsWin() {
        // ⌫ via glyph 0x17, arrows, F-keys.
        #expect(ShortcutFormatter.format(cmdChar: nil, modifiers: 0, glyph: 0x17, virtualKey: nil) == "⌘⌫")
        #expect(ShortcutFormatter.format(cmdChar: "", modifiers: 2, glyph: 0x64, virtualKey: nil) == "⌥⌘←")
        #expect(ShortcutFormatter.format(cmdChar: nil, modifiers: 8, glyph: 0x6F, virtualKey: nil) == "F1")
        #expect(ShortcutFormatter.format(cmdChar: nil, modifiers: 4 | 8, glyph: 0x1B, virtualKey: nil) == "⌃⎋")
    }

    @Test func functionKeyCharacters() {
        #expect(ShortcutFormatter.format(cmdChar: "\u{F700}", modifiers: 0, glyph: nil, virtualKey: nil) == "⌘↑")
        #expect(ShortcutFormatter.format(cmdChar: "\u{F70F}", modifiers: 8, glyph: nil, virtualKey: nil) == "F12")
        #expect(ShortcutFormatter.format(cmdChar: "\r", modifiers: 0, glyph: nil, virtualKey: nil) == "⌘↩")
        #expect(ShortcutFormatter.format(cmdChar: " ", modifiers: 4, glyph: nil, virtualKey: nil) == "⌃⌘Space")
    }

    @Test func virtualKeyFallback() {
        #expect(ShortcutFormatter.format(cmdChar: nil, modifiers: 0, glyph: nil, virtualKey: 123) == "⌘←")
        #expect(ShortcutFormatter.format(cmdChar: nil, modifiers: 0, glyph: nil, virtualKey: 7) == nil)
    }

    @Test func noShortcut() {
        #expect(ShortcutFormatter.format(cmdChar: nil, modifiers: 0, glyph: nil, virtualKey: nil) == nil)
        #expect(ShortcutFormatter.format(cmdChar: "", modifiers: 0, glyph: 0, virtualKey: nil) == nil)
        // Unknown private-use or control characters aren't shown as garbage.
        #expect(ShortcutFormatter.format(cmdChar: "\u{F8FF}", modifiers: 0, glyph: nil, virtualKey: nil) == nil)
        #expect(ShortcutFormatter.format(cmdChar: "\u{01}", modifiers: 0, glyph: nil, virtualKey: nil) == nil)
    }
}
