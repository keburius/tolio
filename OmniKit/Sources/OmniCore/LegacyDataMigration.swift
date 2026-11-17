import Foundation

/// The app used to be called Omni (`com.george.omni`). On the first launch
/// as Tolio this brings the user's settings and files across, once:
///
/// - **Settings:** every key from Omni's preferences that Tolio doesn't have
///   yet is copied. Omni's preferences are left untouched.
/// - **Files:** Omni's Application Support folder (clipboard history, notes,
///   Launcher data) is *moved* to Tolio's, unless Tolio already has one.
///
/// Nothing is deleted. Runs before anything else touches settings or files.
public enum LegacyDataMigration {
    public static let legacyIdentifier = "com.george.omni"
    static let doneKey = "app.migratedFromOmni"

    public struct Outcome: Equatable, Sendable {
        public var copiedSettings = 0
        public var movedFiles = false
        public var skipped = false
    }

    /// The real run: standard defaults, Omni's stored preferences, the
    /// user's Application Support folder.
    @discardableResult
    public static func runIfNeeded() -> Outcome {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let outcome = run(
            defaults: .standard,
            legacySettings: UserDefaults.standard.persistentDomain(forName: legacyIdentifier),
            legacyFolder: base?.appendingPathComponent(legacyIdentifier, isDirectory: true),
            newFolder: base?.appendingPathComponent(Log.subsystem, isDirectory: true)
        )
        if !outcome.skipped {
            Log.logger("migration").notice(
                "Moved from Omni: \(outcome.copiedSettings) setting(s), files moved: \(outcome.movedFiles)"
            )
        }
        return outcome
    }

    /// Testable core. `legacySettings` is Omni's preferences dictionary (nil
    /// when Omni never ran); the folders are Omni's and Tolio's Application
    /// Support folders.
    public static func run(
        defaults: UserDefaults,
        legacySettings: [String: Any]?,
        legacyFolder: URL?,
        newFolder: URL?,
        fileManager: FileManager = .default
    ) -> Outcome {
        var outcome = Outcome()
        guard !defaults.bool(forKey: doneKey) else {
            outcome.skipped = true
            return outcome
        }
        for (key, value) in legacySettings ?? [:] where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
            outcome.copiedSettings += 1
        }
        if let legacyFolder, let newFolder,
           fileManager.fileExists(atPath: legacyFolder.path),
           !fileManager.fileExists(atPath: newFolder.path) {
            do {
                try fileManager.createDirectory(
                    at: newFolder.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try fileManager.moveItem(at: legacyFolder, to: newFolder)
                outcome.movedFiles = true
            } catch {
                Log.logger("migration").error("Couldn't move Omni's files: \((error as NSError).code)")
            }
        }
        defaults.set(true, forKey: doneKey)
        return outcome
    }
}
