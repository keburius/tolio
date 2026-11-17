import Foundation

/// Locations of Omni's own files.
public enum AppPaths {
    /// `~/Library/Application Support/com.george.tolio`, created on first use.
    public static func applicationSupport() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = base.appendingPathComponent(Log.subsystem, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
