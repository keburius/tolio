import Foundation
@testable import OmniCore
import Testing

@MainActor
struct SettingsStoreTests {
    private let intKey = SettingKey("test.int", default: 7)
    private struct Point: Codable, Equatable, Sendable { var x: Int; var y: Int }

    @Test func returnsDefaultWhenUnset() {
        let store = SettingsStore(defaults: makeDefaults())
        #expect(store.value(intKey) == 7)
    }

    @Test func roundTripsCodableValues() {
        let store = SettingsStore(defaults: makeDefaults())
        let key = SettingKey("test.point", default: Point(x: 0, y: 0))
        store.set(Point(x: 3, y: 4), for: key)
        #expect(store.value(key) == Point(x: 3, y: 4))
    }

    @Test func persistsAcrossInstances() {
        let defaults = makeDefaults()
        SettingsStore(defaults: defaults).set(42, for: intKey)
        #expect(SettingsStore(defaults: defaults).value(intKey) == 42)
    }

    @Test func corruptDataFallsBackToDefault() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: intKey.name)
        #expect(SettingsStore(defaults: defaults).value(intKey) == 7)
    }

    @Test func resetRestoresDefault() {
        let store = SettingsStore(defaults: makeDefaults())
        store.set(1, for: intKey)
        store.reset(intKey)
        #expect(store.value(intKey) == 7)
    }

    @Test func featureKeysAreNamespaced() {
        let key = SettingKey.feature("clipboard", "retention", default: 30)
        #expect(key.name == "feature.clipboard.retention")
    }
}
