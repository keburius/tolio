import AppKit

/// Finds the macOS Share service (Messages, Mail, AirDrop, Notes, or an
/// app's share extension such as Slack or WhatsApp) that belongs to an app,
/// so dropping files on that app opens its share window with the files
/// attached instead of just opening them.
@MainActor
enum ShareServices {
    /// Services for `items`. `sharingServices(forItems:)` is deprecated in
    /// favour of a picker menu, but it's the only way to reach one service
    /// directly, so it's called by name (no warning, same behaviour).
    static func services(for items: [Any]) -> [NSSharingService] {
        let selector = NSSelectorFromString("sharingServicesForItems:")
        guard NSSharingService.responds(to: selector),
              let result = NSSharingService.perform(selector, with: items)?.takeUnretainedValue() as? [NSSharingService]
        else { return [] }
        return result
    }

    /// The service for `appName` that can take `items`, if any.
    static func service(forApp appName: String, items: [URL]) -> NSSharingService? {
        let found = services(for: items)
        return bestMatch(appName: appName, titles: found.map(\.title)).map { found[$0] }
    }

    /// Whether the app has a share service at all (for the ring's label).
    /// Asked with a small sample file; cached per app for this session.
    static func canShare(appName: String) -> Bool {
        if let known = cache[appName] { return known }
        let probe = FileManager.default.temporaryDirectory.appendingPathComponent("All Set share check.txt")
        if !FileManager.default.fileExists(atPath: probe.path) { try? Data().write(to: probe) }
        let result = service(forApp: appName, items: [probe]) != nil
        cache[appName] = result
        return result
    }

    private static var cache: [String: Bool] = [:]

    /// Chat apps get files by pasting into a conversation rather than by
    /// opening them: anything in the Social Networking category, plus a few
    /// well-known work chat apps filed elsewhere.
    static func isChatApp(at url: URL) -> Bool {
        guard let bundle = Bundle(url: url) else { return false }
        let known: Set<String> = [
            "com.tinyspeck.slackmacgap", "com.microsoft.teams", "com.microsoft.teams2", "com.hnc.Discord",
        ]
        if let id = bundle.bundleIdentifier, known.contains(id) { return true }
        return (bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String) == "public.app-category.social-networking"
    }

    /// Index of the title that names the same app: equal ignoring case and
    /// spaces, or one contains the other ("WhatsApp" / "WhatsApp Desktop").
    nonisolated static func bestMatch(appName: String, titles: [String]) -> Int? {
        func norm(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
        let name = norm(appName)
        guard name.count >= 2 else { return nil }
        if let exact = titles.firstIndex(where: { norm($0) == name }) { return exact }
        return titles.firstIndex { title in
            let t = norm(title)
            return t.count >= 3 && (t.contains(name) || name.contains(t))
        }
    }

    /// Shows the service's share window with `items`. All Set is a menu bar
    /// app, so it comes forward first or the window may open behind.
    static func share(_ items: [URL], with service: NSSharingService) {
        NSApp.activate()
        service.perform(withItems: items)
    }
}
