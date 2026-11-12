import Foundation

/// An installed application found on disk.
public struct AppEntry: Sendable, Hashable {
    public let name: String
    public let url: URL
    public let bundleID: String?
}

/// Finds `.app` bundles in a set of folders. Pure file system work, safe to
/// run off the main thread.
public enum AppScanner {
    /// Standard locations, in priority order (earlier wins on duplicates).
    public static var standardRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            home.appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
        ]
    }

    /// Single apps outside the standard roots.
    public static var extraApps: [URL] {
        [URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")]
    }

    /// Scans `roots` up to `maxDepth` folder levels (not descending into bundles)
    /// and adds `extras`. Duplicates by bundle id or path are dropped.
    public static func scan(roots: [URL], extras: [URL] = [], maxDepth: Int = 2) -> [AppEntry] {
        var found: [AppEntry] = []
        var seenIDs = Set<String>(), seenPaths = Set<String>()

        func add(_ url: URL) {
            let path = url.resolvingSymlinksInPath().path
            guard seenPaths.insert(path).inserted else { return }
            let bundleID = bundleIdentifier(of: url)
            if let bundleID, !seenIDs.insert(bundleID).inserted { return }
            found.append(AppEntry(name: displayName(of: url), url: url, bundleID: bundleID))
        }

        func walk(_ dir: URL, depth: Int) {
            let keys: [URLResourceKey] = [.isDirectoryKey]
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
            ) else { return }
            for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if child.pathExtension == "app" {
                    add(child)
                } else if depth < maxDepth, (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    walk(child, depth: depth + 1)
                }
            }
        }

        for root in roots { walk(root, depth: 1) }
        for extra in extras where FileManager.default.fileExists(atPath: extra.path) { add(extra) }
        return found
    }

    static func bundleIdentifier(of app: URL) -> String? {
        let plist = app.appendingPathComponent("Contents/Info.plist")
        guard let info = NSDictionary(contentsOf: plist) else { return nil }
        return info["CFBundleIdentifier"] as? String
    }

    /// Localized Finder name without ".app".
    static func displayName(of app: URL) -> String {
        var name = FileManager.default.displayName(atPath: app.path)
        if name.hasSuffix(".app") { name.removeLast(4) }
        return name
    }
}
