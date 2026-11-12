@testable import OmniCore
import Testing

@MainActor
struct FeatureRegistryTests {
    let settings = SettingsStore(defaults: makeDefaults())
    let permissions = FakePermissions()
    let hotkeys = FakeHotkeys()
    let commands = CommandRegistry()

    private func makeRegistry(_ features: FakeFeature...) -> FeatureRegistry {
        let registry = FeatureRegistry(settings: settings, permissions: permissions, hotkeys: hotkeys, commands: commands)
        features.forEach(registry.register)
        return registry
    }

    @Test func registeredFeaturesStartOff() {
        let feature = FakeFeature("f", enabledByDefault: true)
        let registry = makeRegistry(feature)
        #expect(registry.status(of: "f") == .off)
        #expect(feature.enableCount == 0)
    }

    @Test func activateWantedStartsDefaultEnabledFeatures() {
        let on = FakeFeature("on", enabledByDefault: true)
        let off = FakeFeature("off")
        let registry = makeRegistry(on, off)
        registry.activateWantedFeatures()
        #expect(registry.status(of: "on") == .running)
        #expect(registry.status(of: "off") == .off)
    }

    @Test func enablingRegistersOwnedHotkeysAndCommands() {
        let registry = makeRegistry(FakeFeature("f"))
        registry.setWanted(true, for: "f")
        #expect(hotkeys.registered["f.hk"] == "f")
        #expect(commands.allCommands.map(\.id) == ["f.cmd"])
    }

    @Test func disablingReleasesEverything() {
        let feature = FakeFeature("f")
        let registry = makeRegistry(feature)
        registry.setWanted(true, for: "f")
        registry.setWanted(false, for: "f")
        #expect(registry.status(of: "f") == .off)
        #expect(feature.disableCount == 1)
        #expect(feature.resourceCancelled == 1)
        #expect(hotkeys.registered.isEmpty)
        #expect(commands.allCommands.isEmpty)
    }

    @Test func wantedStatePersists() {
        let registry = makeRegistry(FakeFeature("f"))
        registry.setWanted(true, for: "f")
        let reloaded = FeatureRegistry(settings: settings, permissions: permissions, hotkeys: hotkeys, commands: commands)
        reloaded.register(FakeFeature("f"))
        #expect(reloaded.isWanted("f"))
    }

    @Test func missingPermissionBlocksStart() {
        let feature = FakeFeature("f", required: [.accessibility])
        let registry = makeRegistry(feature)
        registry.setWanted(true, for: "f")
        #expect(registry.status(of: "f") == .waitingForPermissions([.accessibility]))
        #expect(feature.enableCount == 0)
    }

    @Test func grantingPermissionLetsWaitingFeatureStart() {
        let registry = makeRegistry(FakeFeature("f", required: [.accessibility]))
        registry.setWanted(true, for: "f")
        permissions.states[.accessibility] = .granted
        registry.activateWantedFeatures()
        #expect(registry.status(of: "f") == .running)
    }

    @Test func unknownPermissionStateDoesNotBlock() {
        permissions.states[.screenRecording] = .unknown
        let registry = makeRegistry(FakeFeature("f", required: [.screenRecording]))
        registry.setWanted(true, for: "f")
        #expect(registry.status(of: "f") == .running)
    }

    @Test func throwingEnableCleansUpAndReportsFailure() {
        let feature = FakeFeature("f")
        feature.shouldThrow = true
        let registry = makeRegistry(feature)
        registry.setWanted(true, for: "f")
        guard case .failed = registry.status(of: "f") else {
            Issue.record("Expected failed status")
            return
        }
        #expect(feature.resourceCancelled == 1)
        #expect(hotkeys.registered.isEmpty)
        #expect(commands.allCommands.isEmpty)
    }

    @Test func permissionUnionsCoverOnlyWantedFeatures() {
        let registry = makeRegistry(
            FakeFeature("a", required: [.accessibility], optional: [.microphone]),
            FakeFeature("b", required: [.screenRecording], optional: [.accessibility]),
            FakeFeature("c", required: [.microphone])
        )
        registry.setWanted(true, for: "a")
        registry.setWanted(true, for: "b")
        #expect(registry.permissionsForWantedFeatures == [.accessibility, .screenRecording])
        #expect(registry.optionalPermissionsForWantedFeatures == [.microphone])
    }

    @Test func deactivateAllStopsRunningFeatures() {
        let feature = FakeFeature("f", enabledByDefault: true)
        let registry = makeRegistry(feature)
        registry.activateWantedFeatures()
        registry.deactivateAll()
        #expect(registry.status(of: "f") == .off)
        #expect(feature.disableCount == 1)
    }
}
