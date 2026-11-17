import Foundation
import Testing
@testable import OmniCore

@Suite struct LegacyDataMigrationTests {
    private func makeDefaults() -> UserDefaults {
        let name = "tolio-migration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func tempFolder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("tolio-mig-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func copiesSettingsAndMovesFiles() throws {
        let defaults = makeDefaults()
        let root = tempFolder()
        let old = root.appendingPathComponent("com.george.omni")
        let new = root.appendingPathComponent("com.george.tolio")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try Data("notes".utf8).write(to: old.appendingPathComponent("notes.json"))

        let outcome = LegacyDataMigration.run(
            defaults: defaults,
            legacySettings: ["app.onboardingCompleted": true, "launcher.hotkey": "x"],
            legacyFolder: old, newFolder: new
        )
        #expect(outcome.copiedSettings == 2)
        #expect(outcome.movedFiles)
        #expect(defaults.bool(forKey: "app.onboardingCompleted"))
        #expect(try String(contentsOf: new.appendingPathComponent("notes.json"), encoding: .utf8) == "notes")
        #expect(!FileManager.default.fileExists(atPath: old.path))
    }

    @Test func neverOverwritesTolioData() throws {
        let defaults = makeDefaults()
        defaults.set("mine", forKey: "launcher.hotkey")
        let root = tempFolder()
        let old = root.appendingPathComponent("com.george.omni")
        let new = root.appendingPathComponent("com.george.tolio")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)

        let outcome = LegacyDataMigration.run(
            defaults: defaults, legacySettings: ["launcher.hotkey": "theirs"], legacyFolder: old, newFolder: new
        )
        #expect(outcome.copiedSettings == 0)
        #expect(!outcome.movedFiles)
        #expect(defaults.string(forKey: "launcher.hotkey") == "mine")
        #expect(FileManager.default.fileExists(atPath: old.path)) // left alone, not deleted
    }

    @Test func runsOnlyOnce() {
        let defaults = makeDefaults()
        let first = LegacyDataMigration.run(defaults: defaults, legacySettings: ["a": 1], legacyFolder: nil, newFolder: nil)
        defaults.removeObject(forKey: "a")
        let second = LegacyDataMigration.run(defaults: defaults, legacySettings: ["a": 1], legacyFolder: nil, newFolder: nil)
        #expect(first.copiedSettings == 1)
        #expect(second.skipped)
        #expect(defaults.object(forKey: "a") == nil)
    }

    @Test func freshInstallWithoutOmniIsFine() {
        let defaults = makeDefaults()
        let root = tempFolder()
        let outcome = LegacyDataMigration.run(
            defaults: defaults, legacySettings: nil,
            legacyFolder: root.appendingPathComponent("com.george.omni"),
            newFolder: root.appendingPathComponent("com.george.tolio")
        )
        #expect(outcome == LegacyDataMigration.Outcome())
    }
}
