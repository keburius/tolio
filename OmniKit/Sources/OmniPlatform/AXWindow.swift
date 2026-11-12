import AppKit
import ApplicationServices

/// Private API, approved for Omni: maps an AX window element to its
/// CGWindowID (needed to identify the same window across calls and to
/// match AX windows with CGWindowList / ScreenCaptureKit windows).
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

/// A window of another app, reached through the Accessibility API.
/// Frames are in AX coordinates (top-left origin of the primary display).
@MainActor
public struct AXWindow {
    /// Seconds before an unresponsive app's AX call gives up.
    static let messagingTimeout: Float = 0.5

    public let element: AXUIElement
    public let pid: pid_t

    public init(element: AXUIElement, pid: pid_t) {
        self.element = element
        self.pid = pid
    }

    /// The focused window of the frontmost app.
    public static func focused() -> AXWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = applicationElement(pid: app.processIdentifier)
        guard let window: AXUIElement = appElement.attribute(kAXFocusedWindowAttribute) else { return nil }
        return AXWindow(element: window, pid: app.processIdentifier)
    }

    /// The window under a screen point (AX coordinates), if any.
    public static func at(_ point: CGPoint) -> AXWindow? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, messagingTimeout)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit) == .success,
              let hit else { return nil }
        var pid: pid_t = 0
        AXUIElementGetPid(hit, &pid)
        if hit.attribute(kAXRoleAttribute) as String? == kAXWindowRole as String {
            return AXWindow(element: hit, pid: pid)
        }
        guard let window: AXUIElement = hit.attribute(kAXWindowAttribute) else { return nil }
        return AXWindow(element: window, pid: pid)
    }

    static func applicationElement(pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }

    // MARK: - Attributes

    public var windowID: CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(element, &id) == .success && id != 0 ? id : nil
    }

    public var frame: CGRect? {
        guard let position: CGPoint = element.value(kAXPositionAttribute),
              let size: CGSize = element.value(kAXSizeAttribute) else { return nil }
        return CGRect(origin: position, size: size)
    }

    public var title: String? { element.attribute(kAXTitleAttribute) }
    public var subrole: String? { element.attribute(kAXSubroleAttribute) }
    public var isMinimized: Bool { element.attribute(kAXMinimizedAttribute) ?? false }
    public var isFullScreen: Bool { element.attribute("AXFullScreen") ?? false }

    /// False for fixed-size windows (some dialogs, utility panels).
    public var isResizable: Bool {
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &settable) == .success
            && settable.boolValue
    }

    /// A normal document/app window (not a sheet, popover, or panel).
    public var isStandard: Bool { subrole == kAXStandardWindowSubrole as String }

    // MARK: - Moving

    @discardableResult
    public func setPosition(_ point: CGPoint) -> Bool {
        element.setPoint(point, for: kAXPositionAttribute)
    }

    @discardableResult
    public func setSize(_ size: CGSize) -> Bool {
        element.setSize(size, for: kAXSizeAttribute)
    }

    /// Size, then position, then size again: shrinking first lets a window
    /// move onto a smaller display; the second resize applies sizes the app
    /// refused while the window was still partly offscreen. Returns the frame
    /// the window actually ended up with.
    @discardableResult
    public func setFrame(_ frame: CGRect) -> CGRect? {
        withEnhancedUserInterfaceDisabled {
            setSize(frame.size)
            setPosition(frame.origin)
            setSize(frame.size)
        }
        return self.frame
    }

    /// Apps with `AXEnhancedUserInterface` on (often turned on by other
    /// assistive tools) animate every AX move, which makes them slow and
    /// sometimes wrong. Turn it off for the duration of `body`.
    public func withEnhancedUserInterfaceDisabled(_ body: () -> Void) {
        let app = Self.applicationElement(pid: pid)
        let key = "AXEnhancedUserInterface"
        let wasOn: Bool = app.attribute(key) ?? false
        if wasOn { AXUIElementSetAttributeValue(app, key as CFString, kCFBooleanFalse) }
        body()
        if wasOn { AXUIElementSetAttributeValue(app, key as CFString, kCFBooleanTrue) }
    }
}

extension AXUIElement {
    /// Reads an attribute as a Swift/CF type.
    func attribute<T>(_ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    /// Reads an AXValue-wrapped CGPoint/CGSize/CGRect.
    func value<T>(_ name: String) -> T? {
        guard let raw: AnyObject = attribute(name), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let axValue = raw as! AXValue // Type checked above.
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AXValueGetValue(axValue, AXValueGetType(axValue), pointer) else { return nil }
        return pointer.pointee
    }

    @discardableResult
    func setPoint(_ point: CGPoint, for name: String) -> Bool {
        var copy = point
        guard let axValue = AXValueCreate(.cgPoint, &copy) else { return false }
        return AXUIElementSetAttributeValue(self, name as CFString, axValue) == .success
    }

    @discardableResult
    func setSize(_ size: CGSize, for name: String) -> Bool {
        var copy = size
        guard let axValue = AXValueCreate(.cgSize, &copy) else { return false }
        return AXUIElementSetAttributeValue(self, name as CFString, axValue) == .success
    }
}

/// Builds AX-space screen rects from `NSScreen`.
@MainActor
public enum ScreenFrames {
    /// (frame, visibleFrame) per screen in AppKit coordinates, primary first.
    public static var appKit: [(frame: CGRect, visible: CGRect)] {
        NSScreen.screens.map { ($0.frame, $0.visibleFrame) }
    }

    public static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }
}
