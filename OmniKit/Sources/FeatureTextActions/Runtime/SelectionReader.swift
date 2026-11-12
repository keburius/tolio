import AppKit
import ApplicationServices
import OmniPlatform

/// The focused element, kept so an action can replace its selection.
/// AX calls are thread-safe; it's created off the main thread and used on it.
final class FocusedElement: @unchecked Sendable {
    let element: AXUIElement
    init(_ element: AXUIElement) { self.element = element }

    /// Replaces the selected text. Returns false if the app refused.
    func replaceSelection(with text: String) -> Bool {
        AXUIElementSetMessagingTimeout(element, 0.5)
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
    }
}

/// What Accessibility says about the frontmost app's selection.
struct AXSelectionResult: Sendable {
    enum Kind: Sendable {
        /// Bounds are in AX coordinates (top-left origin of the primary display).
        case text(String, editable: Bool, bounds: CGRect?)
        /// The element supports selections and none is selected.
        case empty
        /// No selection attribute (or no focused element): try the ⌘C fallback.
        case unsupported
        /// A password field. Its text is never read.
        case secure
        case tooLong
    }

    var kind: Kind
    var role: String?
    var subrole: String?
    var element: FocusedElement?
    /// Focused window frame in AX coordinates.
    var windowFrame: CGRect?
}

enum SelectionReader {
    /// Longer selections are ignored rather than truncated, so no action can
    /// ever replace a selection with a cut-down copy.
    static let maxLength = 100_000
    static let timeout: Float = 0.3

    static func read(pid: pid_t) -> AXSelectionResult {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, timeout)
        let window: AXUIElement? = copy(app, kAXFocusedWindowAttribute)
        let windowFrame = window.flatMap(frame(of:))
        guard let focused: AXUIElement = copy(app, kAXFocusedUIElementAttribute) else {
            return AXSelectionResult(kind: .unsupported, windowFrame: windowFrame)
        }
        let role: String? = copy(focused, kAXRoleAttribute)
        let subrole: String? = copy(focused, kAXSubroleAttribute)
        var result = AXSelectionResult(kind: .unsupported, role: role, subrole: subrole, element: FocusedElement(focused), windowFrame: windowFrame)
        // Checked before anything else is read from the element.
        if role == "AXSecureTextField" || subrole == "AXSecureTextField" {
            result.kind = .secure
            result.element = nil
            return result
        }
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &value)
        guard error == .success, let text = value as? String else { return result }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            result.kind = .empty
            return result
        }
        guard text.count <= maxLength else {
            result.kind = .tooLong
            return result
        }
        var settable = DarwinBoolean(false)
        let editable = AXUIElementIsAttributeSettable(focused, kAXSelectedTextAttribute as CFString, &settable) == .success && settable.boolValue
        result.kind = .text(text, editable: editable, bounds: selectionBounds(focused))
        return result
    }

    private static func selectionBounds(_ element: AXUIElement) -> CGRect? {
        guard let range: AXValue = copyValue(element, kAXSelectedTextRangeAttribute) else { return nil }
        var raw: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, range, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(raw as! AXValue, .cgRect, &rect), rect.width > 0 || rect.height > 0 else { return nil } // Type checked above.
        return rect
    }

    private static func frame(of window: AXUIElement) -> CGRect? {
        guard let posValue: AXValue = copyValue(window, kAXPositionAttribute),
              let sizeValue: AXValue = copyValue(window, kAXSizeAttribute) else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(posValue, .cgPoint, &point), AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    private static func copy<T>(_ element: AXUIElement, _ name: String) -> T? {
        AXUIElementSetMessagingTimeout(element, timeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private static func copyValue(_ element: AXUIElement, _ name: String) -> AXValue? {
        AXUIElementSetMessagingTimeout(element, timeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue) // Type checked above.
    }
}

/// `NSPasteboard.general` for `CopyFallback`.
@MainActor
final class SystemPasteboard: BorrowablePasteboard {
    private let pasteboard: NSPasteboard
    init(_ pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }

    var changeCount: Int { pasteboard.changeCount }
    var types: Set<String> { Set((pasteboard.pasteboardItems ?? []).flatMap(\.types).map(\.rawValue)) }
    var string: String? { pasteboard.string(forType: .string) }
    func snapshot() -> PasteboardSnapshot { PasteboardSnapshot.capture(pasteboard) }
    func restore(_ snapshot: PasteboardSnapshot) -> Int { snapshot.restore(to: pasteboard) }
    func clear() { pasteboard.clearContents() }
    var snapshotIsEmpty: (PasteboardSnapshot) -> Bool { { $0.isEmpty } }
}
