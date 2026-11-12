import AppKit
import ApplicationServices
import OmniCore
import OmniPlatform

/// Records which window gets focus, in every app, to order the switcher by
/// recency. Uses one AXObserver per running app plus app-activation
/// notifications. Observers exist only between `start()` and `stop()`.
@MainActor
final class FocusTracker {
    private(set) var recency = RecencyTracker()
    private var observers: [pid_t: AXObserver] = [:]
    private var tokens: [NSObjectProtocol] = []

    func start() {
        guard tokens.isEmpty else { return }
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            observe(app.processIdentifier)
        }
        let center = NSWorkspace.shared.notificationCenter
        tokens.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated { if let pid { self?.observe(pid) } }
        })
        tokens.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated { if let pid { self?.unobserve(pid) } }
        })
        tokens.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.touchFocusedWindow() }
        })
        touchFocusedWindow()
    }

    func stop() {
        tokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        tokens.removeAll()
        for pid in Array(observers.keys) { unobserve(pid) }
    }

    /// Records the frontmost app's focused window (also called before opening).
    func touchFocusedWindow() {
        if let id = AXWindow.focused()?.windowID { recency.touch(id) }
    }

    func touch(_ id: CGWindowID) { recency.touch(id) }

    func prune(keeping ids: Set<CGWindowID>) { recency.retain(only: ids) }

    fileprivate func focusChanged(to element: AXUIElement, pid: pid_t) {
        if let id = AXWindow(element: element, pid: pid).windowID { recency.touch(id) }
    }

    private func observe(_ pid: pid_t) {
        guard observers[pid] == nil, pid != ProcessInfo.processInfo.processIdentifier else { return }
        var observer: AXObserver?
        guard AXObserverCreate(pid, focusCallback, &observer) == .success, let observer else { return }
        let app = AXUIElementCreateApplication(pid)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for notification in [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification] {
            AXObserverAddNotification(observer, app, notification as CFString, context)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
    }

    private func unobserve(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }
}

/// Runs on the main run loop (where the observer sources are added).
private func focusCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ context: UnsafeMutableRawPointer?) {
    let address = UInt(bitPattern: context)
    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)
    nonisolated(unsafe) let window = element
    MainActor.assumeIsolated {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: address) else { return }
        Unmanaged<FocusTracker>.fromOpaque(pointer).takeUnretainedValue().focusChanged(to: window, pid: pid)
    }
}
