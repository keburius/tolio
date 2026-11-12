import Foundation
@testable import OmniCore
import Testing

struct HotkeyBindingsTests {
    private let action = HotkeyAction(id: "a", title: "A", defaultCombo: KeyCombo(keyCode: 0, modifiers: .command))
    private let other = KeyCombo(keyCode: 1, modifiers: .control)

    @Test func defaultAppliesWithoutOverride() {
        #expect(HotkeyBindings().combo(for: action) == action.defaultCombo)
    }

    @Test func overrideReplacesDefault() {
        var bindings = HotkeyBindings()
        bindings.set(other, for: "a")
        #expect(bindings.combo(for: action) == other)
    }

    @Test func clearedOverrideMeansUnbound() {
        var bindings = HotkeyBindings()
        bindings.set(nil, for: "a")
        #expect(bindings.combo(for: action) == nil)
    }

    @Test func resetRestoresDefault() {
        var bindings = HotkeyBindings()
        bindings.set(nil, for: "a")
        bindings.reset("a")
        #expect(bindings.combo(for: action) == action.defaultCombo)
    }

    @Test func codableRoundTripKeepsClearedOverrides() throws {
        var bindings = HotkeyBindings()
        bindings.set(nil, for: "a")
        bindings.set(other, for: "b")
        let decoded = try JSONDecoder().decode(HotkeyBindings.self, from: JSONEncoder().encode(bindings))
        #expect(decoded == bindings)
        #expect(decoded.combo(for: action) == nil)
    }
}
