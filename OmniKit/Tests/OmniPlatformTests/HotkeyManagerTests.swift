import Foundation
import OmniCore
@testable import OmniPlatform
import Testing

@MainActor
final class FakeBackend: HotkeyBackend {
    var onPress: (@MainActor (UInt32) -> Void)?
    var active: [UInt32: KeyCombo] = [:]
    var refuse: Set<KeyCombo> = []

    func register(id: UInt32, combo: KeyCombo) -> Int32 {
        if refuse.contains(combo) { return -9878 } // eventHotKeyExistsErr
        active[id] = combo
        return 0
    }

    func unregister(id: UInt32) { active[id] = nil }

    func press(_ combo: KeyCombo) {
        if let id = active.first(where: { $0.value == combo })?.key { onPress?(id) }
    }
}

@MainActor
struct HotkeyManagerTests {
    let backend = FakeBackend()
    let defaults: UserDefaults
    let settings: SettingsStore
    let manager: HotkeyManager

    let cmdA = KeyCombo(keyCode: 0, modifiers: .command)
    let ctrlB = KeyCombo(keyCode: 11, modifiers: .control)

    init() {
        let name = "omni.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
        settings = SettingsStore(defaults: defaults)
        manager = HotkeyManager(backend: backend, settings: settings)
    }

    private func action(_ id: String, _ combo: KeyCombo?) -> HotkeyAction {
        HotkeyAction(id: id, title: id.uppercased(), defaultCombo: combo)
    }

    @Test func registeringBindsDefaultAndPressFiresHandler() {
        var fired = 0
        manager.register(action("a", cmdA), owner: "f") { fired += 1 }
        #expect(manager.registrations["a"]?.state == .active(cmdA))
        backend.press(cmdA)
        #expect(fired == 1)
    }

    @Test func actionWithoutDefaultIsUnbound() {
        manager.register(action("a", nil), owner: "f") {}
        #expect(manager.registrations["a"]?.state == .unbound)
        #expect(backend.active.isEmpty)
    }

    @Test func secondActionWithSameDefaultIsMarkedConflict() {
        manager.register(action("a", cmdA), owner: "f") {}
        manager.register(action("b", cmdA), owner: "g") {}
        #expect(manager.registrations["b"]?.state == .conflict(cmdA, withActionID: "a"))
        #expect(backend.active.count == 1)
    }

    @Test func rebindRejectsInvalidCombo() {
        manager.register(action("a", cmdA), owner: "f") {}
        let result = manager.rebind("a", to: KeyCombo(keyCode: 0, modifiers: .option))
        #expect(result == .invalid(.optionOnlyNotAllowed))
        #expect(manager.registrations["a"]?.state == .active(cmdA))
    }

    @Test func rebindRejectsConflict() {
        manager.register(action("a", cmdA), owner: "f") {}
        manager.register(action("b", ctrlB), owner: "f") {}
        #expect(manager.rebind("b", to: cmdA) == .conflict(withTitle: "A"))
    }

    @Test func rebindMovesBindingAndPersists() {
        manager.register(action("a", cmdA), owner: "f") {}
        #expect(manager.rebind("a", to: ctrlB) == .ok)
        #expect(Array(backend.active.values) == [ctrlB])

        // A new manager over the same settings applies the override.
        let backend2 = FakeBackend()
        let manager2 = HotkeyManager(backend: backend2, settings: SettingsStore(defaults: defaults))
        manager2.register(action("a", cmdA), owner: "f") {}
        #expect(manager2.registrations["a"]?.state == .active(ctrlB))
    }

    @Test func clearingUnbinds() {
        manager.register(action("a", cmdA), owner: "f") {}
        manager.rebind("a", to: nil)
        #expect(manager.registrations["a"]?.state == .unbound)
        #expect(backend.active.isEmpty)
    }

    @Test func resetRestoresDefault() {
        manager.register(action("a", cmdA), owner: "f") {}
        manager.rebind("a", to: ctrlB)
        manager.resetToDefault("a")
        #expect(manager.registrations["a"]?.state == .active(cmdA))
    }

    @Test func systemRefusalIsReported() {
        backend.refuse = [ctrlB]
        manager.register(action("a", cmdA), owner: "f") {}
        #expect(manager.rebind("a", to: ctrlB) == .systemRefused(status: -9878))
        #expect(manager.registrations["a"]?.state == .failed(ctrlB, status: -9878))
    }

    @Test func unregisterAllRemovesOwnerBindings() {
        manager.register(action("a", cmdA), owner: "f") {}
        manager.register(action("b", ctrlB), owner: "g") {}
        manager.unregisterAll(owner: "f")
        #expect(manager.registrations.keys.sorted() == ["b"])
        #expect(Array(backend.active.values) == [ctrlB])
    }

    @Test func rebindWhileFeatureIsOffIsRemembered() {
        let combo = KeyCombo(keyCode: 11, modifiers: [.control, .option])
        #expect(manager.rebind("notRegistered", to: combo) == .ok)
        #expect(manager.bindings.overrides["notRegistered"]?.combo == combo)
        #expect(manager.rebind("notRegistered", to: KeyCombo(keyCode: 0, modifiers: .option)) != .ok)
        manager.resetToDefaults(["notRegistered"])
        #expect(manager.bindings.overrides["notRegistered"] == nil)
    }
}
