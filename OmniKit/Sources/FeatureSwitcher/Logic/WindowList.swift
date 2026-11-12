import CoreGraphics

/// Where a window is, as far as the switcher can tell.
public enum WindowState: String, Sendable, Equatable {
    /// On the current Space, not minimized.
    case normal
    case minimized
    /// Its app is hidden (⌘H).
    case hidden
    /// On another Space: listed by the window server but not reachable
    /// through Accessibility. Choosing it activates its app.
    case otherSpace
}

/// One row in the switcher.
public struct WindowRecord: Identifiable, Sendable, Equatable {
    public let id: CGWindowID
    public let pid: pid_t
    public let appName: String
    public let bundleID: String?
    public let title: String
    public let frame: CGRect
    public let state: WindowState
}

/// Inputs gathered from the system, kept as plain values so the merge is testable.
public enum WindowSources {
    /// From `CGWindowListCopyWindowInfo`, in front-to-back order.
    public struct ServerWindow: Sendable, Equatable {
        public let id: CGWindowID
        public let pid: pid_t
        public let layer: Int
        public let bounds: CGRect
        public let isOnScreen: Bool
        public let alpha: Double
        /// Only readable with Screen Recording permission.
        public let title: String?

        public init(id: CGWindowID, pid: pid_t, layer: Int, bounds: CGRect, isOnScreen: Bool, alpha: Double = 1, title: String?) {
            self.id = id
            self.pid = pid
            self.layer = layer
            self.bounds = bounds
            self.isOnScreen = isOnScreen
            self.alpha = alpha
            self.title = title
        }
    }

    /// From the Accessibility API (current Space plus minimized windows).
    public struct AXInfo: Sendable, Equatable {
        public let id: CGWindowID
        public let title: String?
        public let isMinimized: Bool
        /// Normal document/app window (not a palette, sheet, or popover).
        public let isStandard: Bool

        public init(id: CGWindowID, title: String?, isMinimized: Bool, isStandard: Bool) {
            self.id = id
            self.title = title
            self.isMinimized = isMinimized
            self.isStandard = isStandard
        }
    }

    public struct App: Sendable, Equatable {
        public let pid: pid_t
        public let name: String
        public let bundleID: String?
        public let isHidden: Bool

        public init(pid: pid_t, name: String, bundleID: String?, isHidden: Bool) {
            self.pid = pid
            self.name = name
            self.bundleID = bundleID
            self.isHidden = isHidden
        }
    }
}

/// Which kinds of windows to include.
public struct WindowListOptions: Sendable, Equatable {
    public var includeMinimized = true
    public var includeHidden = true
    public var includeOtherSpaces = true

    public init(includeMinimized: Bool = true, includeHidden: Bool = true, includeOtherSpaces: Bool = true) {
        self.includeMinimized = includeMinimized
        self.includeHidden = includeHidden
        self.includeOtherSpaces = includeOtherSpaces
    }
}

/// Merges window-server, Accessibility, and app information into switcher rows.
public enum WindowListBuilder {
    /// Smaller windows are tooltips, status items, and other non-switchable things.
    static let minimumSize = CGSize(width: 80, height: 50)
    /// Stricter size for windows known only from the window server.
    static let minimumUnverifiedSize = CGSize(width: 200, height: 120)

    /// - Parameters:
    ///   - server: window-server windows, front to back.
    ///   - ax: Accessibility windows keyed by window id.
    ///   - apps: regular (Dock) apps keyed by pid; other processes are ignored.
    ///   - ownPID: Omni's pid, always excluded.
    public static func build(
        server: [WindowSources.ServerWindow],
        ax: [CGWindowID: WindowSources.AXInfo],
        apps: [pid_t: WindowSources.App],
        ownPID: pid_t,
        options: WindowListOptions
    ) -> [WindowRecord] {
        var seen = Set<CGWindowID>()
        var records: [WindowRecord] = []
        for window in server {
            guard window.pid != ownPID, let app = apps[window.pid], window.layer == 0, window.alpha > 0,
                  window.bounds.width >= minimumSize.width, window.bounds.height >= minimumSize.height,
                  seen.insert(window.id).inserted else { continue }

            let state: WindowState
            let title: String?
            if let info = ax[window.id] {
                guard info.isStandard else { continue }
                state = app.isHidden ? .hidden : (info.isMinimized ? .minimized : .normal)
                title = info.title?.isEmpty == false ? info.title : window.title
            } else {
                // Not visible to Accessibility: only trust windows with a real
                // title and size, to keep offscreen helper windows out.
                guard let serverTitle = window.title, !serverTitle.isEmpty,
                      window.bounds.width >= minimumUnverifiedSize.width,
                      window.bounds.height >= minimumUnverifiedSize.height else { continue }
                if app.isHidden {
                    state = .hidden
                } else if window.isOnScreen {
                    state = .normal
                } else {
                    state = .otherSpace
                }
                title = serverTitle
            }

            switch state {
            case .minimized where !options.includeMinimized: continue
            case .hidden where !options.includeHidden: continue
            case .otherSpace where !options.includeOtherSpaces: continue
            default: break
            }
            records.append(WindowRecord(
                id: window.id, pid: window.pid, appName: app.name, bundleID: app.bundleID,
                title: title ?? app.name, frame: window.bounds, state: state
            ))
        }
        return records
    }
}
