import AppKit
import OmniCore
import OmniPlatform

/// Applies window actions to real windows through Accessibility.
@MainActor
final class WindowManager {
    enum Outcome: Equatable {
        case done
        case noWindow
        case fullScreen
        case nothingToRestore
        case onlyOneDisplay
        case unreadable
    }

    private var history = RestoreHistory()
    private let gap: () -> CGFloat
    private let log = Log.logger("windows")

    init(gap: @escaping () -> CGFloat) {
        self.gap = gap
    }

    var screens: [ScreenInfo] {
        ScreenGeometry.screens(appKitFrames: ScreenFrames.appKit)
    }

    /// Runs `action` on the focused window.
    @discardableResult
    func perform(_ action: WindowAction) -> Outcome {
        guard let window = AXWindow.focused() else { return report(.noWindow) }
        return report(apply(action, to: window, screenIndex: nil))
    }

    /// Runs `action` on `window`. `screenIndex` overrides which display to
    /// lay out on (drag-to-edge uses the display under the pointer).
    @discardableResult
    func apply(_ action: WindowAction, to window: AXWindow, screenIndex: Int?) -> Outcome {
        guard !window.isFullScreen else { return .fullScreen }
        guard let current = window.frame else { return .unreadable }
        let screens = self.screens
        guard let sourceIndex = screenIndex ?? ScreenGeometry.screenIndex(for: current, in: screens) else {
            return .unreadable
        }
        let id = window.windowID

        let target: CGRect
        var bounds = screens[sourceIndex].visibleFrame
        switch action {
        case .restore:
            guard let id, let previous = history.restoreFrame(for: id, current: current) else { return .nothingToRestore }
            window.setFrame(previous)
            history.forget(id)
            return .done
        case .nextDisplay, .previousDisplay:
            guard screens.count > 1 else { return .onlyOneDisplay }
            let order = ScreenGeometry.displayOrder(screens)
            let position = order.firstIndex(of: sourceIndex) ?? 0
            let step = action == .nextDisplay ? 1 : order.count - 1
            let destination = order[(position + step) % order.count]
            bounds = screens[destination].visibleFrame
            target = WindowLayout.move(current, from: screens[sourceIndex].visibleFrame, to: bounds)
        default:
            guard let frame = WindowLayout.frame(for: action, window: current, visible: bounds, gap: gap()) else {
                return .unreadable
            }
            target = frame
        }

        if let id { history.willApply(to: id, current: current) }
        var actual = window.setFrame(target) ?? target
        // The app enforced a minimum (or stepped) size: re-anchor so the
        // window keeps the intended edge and stays on screen.
        if abs(actual.width - target.width) > 1 || abs(actual.height - target.height) > 1 {
            let fitted = WindowLayout.fit(actualSize: actual.size, target: target, action: action, bounds: bounds)
            window.setPosition(fitted.origin)
            actual = window.frame ?? fitted
            log.debug("Window kept size \(Int(actual.width))×\(Int(actual.height)) for \(action.rawValue, privacy: .public)")
        }
        if let id { history.didApply(to: id, actual: actual) }
        return .done
    }

    private func report(_ outcome: Outcome) -> Outcome {
        switch outcome {
        case .done: break
        case .noWindow: HUD.show("No window to arrange", symbol: "macwindow")
        case .fullScreen: HUD.show("Window is in full screen", symbol: "arrow.up.left.and.arrow.down.right")
        case .nothingToRestore: HUD.show("Nothing to restore", symbol: "arrow.uturn.backward")
        case .onlyOneDisplay: HUD.show("Only one display connected", symbol: "display")
        case .unreadable: HUD.show("This window can't be arranged", symbol: "exclamationmark.triangle")
        }
        return outcome
    }
}
