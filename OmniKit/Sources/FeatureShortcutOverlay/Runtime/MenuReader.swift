import AppKit
import ApplicationServices

/// The result of reading one app's menu bar. Keeps the AX elements so an
/// item can be pressed later. AX calls are thread-safe, so the elements may
/// be read on a background queue and pressed on the main thread.
final class MenuSnapshot: @unchecked Sendable {
    let pid: pid_t
    let menuBar: [MenuNode]
    let itemCount: Int
    /// The walk stopped at a limit (item count, depth, or time).
    let truncated: Bool
    let duration: TimeInterval
    /// `systemUptime` when the read finished.
    let readAt = ProcessInfo.processInfo.systemUptime
    private let elements: [AXUIElement]

    init(pid: pid_t, menuBar: [MenuNode], elements: [AXUIElement], itemCount: Int, truncated: Bool, duration: TimeInterval) {
        self.pid = pid
        self.menuBar = menuBar
        self.elements = elements
        self.itemCount = itemCount
        self.truncated = truncated
        self.duration = duration
    }

    /// Clicks the item, as choosing it from the menu would. May block while
    /// the app handles it (e.g. opens a modal sheet), so call it off the main thread.
    func press(_ ref: Int) -> AXError {
        guard elements.indices.contains(ref) else { return .invalidUIElement }
        let element = elements[ref]
        AXUIElementSetMessagingTimeout(element, 1.0)
        return AXUIElementPerformAction(element, kAXPressAction as CFString)
    }
}

/// Walks an app's menu bar through Accessibility. Runs off the main thread,
/// bounded by item count, depth, and a wall-clock deadline.
enum MenuReader {
    struct Limits: Sendable {
        var maxItems = 4000
        /// Top-level menu = 1; submenus add one each.
        var maxDepth = 4
        var deadline: TimeInterval = 3.0
        /// Per AX call, so one hung app can't stall the walk for long.
        var messagingTimeout: Float = 0.25
        /// The first call may have to wake the app (App Nap), so it gets longer.
        var firstCallTimeout: Float = 1.0
    }

    private static let itemAttributeNames: [String] = [
        kAXTitleAttribute, kAXEnabledAttribute, kAXChildrenAttribute,
        kAXMenuItemCmdCharAttribute, kAXMenuItemCmdModifiersAttribute,
        kAXMenuItemCmdGlyphAttribute, kAXMenuItemCmdVirtualKeyAttribute,
    ]

    private final class Walk {
        let limits: Limits
        let start = ProcessInfo.processInfo.systemUptime
        var elements: [AXUIElement] = []
        var count = 0
        var truncated = false
        let attributes: CFArray

        init(limits: Limits, attributes: CFArray) {
            self.limits = limits
            self.attributes = attributes
        }

        var outOfBudget: Bool {
            if count >= limits.maxItems || ProcessInfo.processInfo.systemUptime - start > limits.deadline {
                truncated = true
                return true
            }
            return false
        }
    }

    /// Returns nil if the app exposes no menu bar (or isn't reachable).
    static func read(pid: pid_t, limits: Limits = Limits()) -> MenuSnapshot? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, limits.firstCallTimeout)
        guard let bar: AXUIElement = copy(app, kAXMenuBarAttribute, timeout: limits.firstCallTimeout),
              let topItems: [AXUIElement] = copy(bar, kAXChildrenAttribute, timeout: limits.messagingTimeout) else { return nil }
        let walk = Walk(limits: limits, attributes: itemAttributeNames as CFArray)
        var menus: [MenuNode] = []
        // Index 0 is the Apple menu: system-wide items, not the app's.
        for top in topItems.dropFirst() {
            if walk.outOfBudget { break }
            let title: String = copy(top, kAXTitleAttribute, timeout: limits.messagingTimeout) ?? ""
            let children = submenuItems(of: top, depth: 1, walk: walk)
            menus.append(MenuNode(title: title, children: children))
        }
        return MenuSnapshot(
            pid: pid, menuBar: menus, elements: walk.elements, itemCount: walk.count,
            truncated: walk.truncated, duration: ProcessInfo.processInfo.systemUptime - walk.start
        )
    }

    /// Items of the AXMenu under a menu bar item or a menu item.
    private static func submenuItems(of element: AXUIElement, depth: Int, walk: Walk) -> [MenuNode] {
        guard depth <= walk.limits.maxDepth,
              let menus: [AXUIElement] = copy(element, kAXChildrenAttribute, timeout: walk.limits.messagingTimeout),
              let menu = menus.first,
              let items: [AXUIElement] = copy(menu, kAXChildrenAttribute, timeout: walk.limits.messagingTimeout) else { return [] }
        var nodes: [MenuNode] = []
        nodes.reserveCapacity(items.count)
        for item in items {
            if walk.outOfBudget { break }
            walk.count += 1
            if let node = node(for: item, depth: depth, walk: walk) { nodes.append(node) }
        }
        return nodes
    }

    private static func node(for item: AXUIElement, depth: Int, walk: Walk) -> MenuNode? {
        // Timeouts are per element; without this a hung app stalls each call for macOS's default (~6 s).
        AXUIElementSetMessagingTimeout(item, walk.limits.messagingTimeout)
        var raw: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(item, walk.attributes, AXCopyMultipleAttributeOptions(rawValue: 0), &raw) == .success,
              let values = raw as? [AnyObject], values.count == 7 else { return nil }
        let title = values[0] as? String ?? ""
        guard !title.isEmpty else { return nil } // separators
        let enabled = values[1] as? Bool ?? true
        let hasSubmenu = (values[2] as? [AXUIElement])?.isEmpty == false
        let shortcut = ShortcutFormatter.format(
            cmdChar: values[3] as? String, modifiers: values[4] as? Int,
            glyph: values[5] as? Int, virtualKey: values[6] as? Int
        )
        var ref: Int?
        if shortcut != nil {
            ref = walk.elements.count
            walk.elements.append(item)
        }
        let children = hasSubmenu ? submenuItems(of: item, depth: depth + 1, walk: walk) : []
        return MenuNode(title: title, shortcut: shortcut, isEnabled: enabled, ref: ref, children: children)
    }

    private static func copy<T>(_ element: AXUIElement, _ name: String, timeout: Float) -> T? {
        AXUIElementSetMessagingTimeout(element, timeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}

/// Recent menu snapshots per app. Shows the cached copy at once and
/// refreshes in the background, so changed menus appear within a moment.
@MainActor
final class MenuCache {
    private var snapshots: [pid_t: MenuSnapshot] = [:]
    private var order: [pid_t] = []
    private var inFlight: Set<pid_t> = []
    private var waiters: [pid_t: [(MenuSnapshot?) -> Void]] = [:]
    private let capacity = 6
    private let limits: MenuReader.Limits

    init(limits: MenuReader.Limits = MenuReader.Limits()) {
        self.limits = limits
    }

    func cached(_ pid: pid_t) -> MenuSnapshot? { snapshots[pid] }

    /// Reads in the background; concurrent requests for one app share a read.
    /// A snapshot younger than `maxAge` is reused instead of read again.
    func refresh(_ pid: pid_t, maxAge: TimeInterval = 0, completion: @escaping (MenuSnapshot?) -> Void = { _ in }) {
        if let snapshot = snapshots[pid], !inFlight.contains(pid),
           ProcessInfo.processInfo.systemUptime - snapshot.readAt < maxAge {
            completion(snapshot)
            return
        }
        waiters[pid, default: []].append(completion)
        guard inFlight.insert(pid).inserted else { return }
        let limits = self.limits
        Task.detached(priority: .userInitiated) {
            let snapshot = MenuReader.read(pid: pid, limits: limits)
            await MainActor.run { [weak self] in self?.finish(pid, snapshot) }
        }
    }

    private func finish(_ pid: pid_t, _ snapshot: MenuSnapshot?) {
        inFlight.remove(pid)
        if let snapshot {
            snapshots[pid] = snapshot
            order.removeAll { $0 == pid }
            order.append(pid)
            while order.count > capacity { snapshots[order.removeFirst()] = nil }
        }
        for waiter in waiters.removeValue(forKey: pid) ?? [] { waiter(snapshot) }
    }

    func forget(_ pid: pid_t) {
        snapshots[pid] = nil
        order.removeAll { $0 == pid }
    }

    func clear() {
        snapshots.removeAll()
        order.removeAll()
    }
}
