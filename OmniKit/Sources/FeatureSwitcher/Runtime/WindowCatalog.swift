import AppKit
import OmniCore
import OmniPlatform

/// Reads the current windows from the window server, Accessibility, and
/// running apps, and keeps the AX handles needed to act on them.
@MainActor
final class WindowCatalog {
    private(set) var records: [WindowRecord] = []
    private var handles: [CGWindowID: AXWindow] = [:]

    /// Rebuilds the list (a few ms per app with windows).
    func reload(options: WindowListOptions, recency: [CGWindowID]) {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ownPID && !$0.isTerminated
        }
        let apps = Dictionary(uniqueKeysWithValues: running.map {
            ($0.processIdentifier, WindowSources.App(
                pid: $0.processIdentifier, name: $0.localizedName ?? "App",
                bundleID: $0.bundleIdentifier, isHidden: $0.isHidden
            ))
        })

        let server = Self.serverWindows()
        let pidsWithWindows = Set(server.map(\.pid)).intersection(apps.keys)
        var axInfo: [CGWindowID: WindowSources.AXInfo] = [:]
        var handles: [CGWindowID: AXWindow] = [:]
        for pid in pidsWithWindows {
            for window in AXWindow.windows(of: pid) {
                guard let id = window.windowID else { continue }
                handles[id] = window
                axInfo[id] = .init(id: id, title: window.title, isMinimized: window.isMinimized, isStandard: window.isStandard)
            }
        }
        self.handles = handles
        let built = WindowListBuilder.build(server: server, ax: axInfo, apps: apps, ownPID: ownPID, options: options)
        records = SwitcherOrdering.sort(built, recency: recency, zOrder: server.map(\.id))
    }

    func handle(for id: CGWindowID) -> AXWindow? { handles[id] }

    /// Front-to-back window-server list. Titles need Screen Recording.
    static func serverWindows() -> [WindowSources.ServerWindow] {
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return info.compactMap { entry in
            guard let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = entry[kCGWindowLayer as String] as? Int,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { return nil }
            return .init(
                id: id, pid: pid, layer: layer, bounds: bounds,
                isOnScreen: entry[kCGWindowIsOnscreen as String] as? Bool ?? false,
                alpha: entry[kCGWindowAlpha as String] as? Double ?? 1,
                title: entry[kCGWindowName as String] as? String
            )
        }
    }
}
