/// Keyboard behavior of the switcher, independent of AppKit.
///
/// Hold the trigger modifier and press Tab to open and move forward
/// (Shift-Tab backward), release the modifier to switch. While open:
/// arrows move, Return switches, Esc cancels, Q quits the selected app,
/// W closes the selected window.
public struct SwitcherStateMachine: Sendable, Equatable {
    public enum Input: Sendable, Equatable {
        case tab(backward: Bool)
        case move(Int)
        case release
        case enter
        case escape
        case quitApp
        case closeWindow
        case click(Int)
        /// The list was rebuilt (e.g. after closing a window).
        case listChanged(count: Int)
    }

    public enum Effect: Sendable, Equatable {
        case select(Int)
        case activate(Int)
        case cancel
        case quitApp(Int)
        case closeWindow(Int)
    }

    public private(set) var isActive = false
    public private(set) var selection = 0
    public private(set) var count = 0

    public init() {}

    /// Opens the switcher on a fresh list. Starts on the second row (the
    /// previously used window) going forward, or the last row going backward.
    /// Returns false if there's nothing to switch to.
    public mutating func begin(count: Int, backward: Bool) -> Bool {
        guard count > 0 else { return false }
        isActive = true
        self.count = count
        selection = backward ? count - 1 : min(1, count - 1)
        return true
    }

    public mutating func handle(_ input: Input) -> [Effect] {
        guard isActive else { return [] }
        switch input {
        case let .tab(backward):
            return move(backward ? -1 : 1, wrap: true)
        case let .move(delta):
            return move(delta, wrap: false)
        case .release, .enter:
            return finish(.activate(selection))
        case .escape:
            return finish(.cancel)
        case let .click(index):
            guard (0..<count).contains(index) else { return [] }
            selection = index
            return finish(.activate(index))
        case .quitApp:
            return [.quitApp(selection)]
        case .closeWindow:
            return [.closeWindow(selection)]
        case let .listChanged(newCount):
            guard newCount > 0 else { return finish(.cancel) }
            count = newCount
            selection = min(selection, newCount - 1)
            return [.select(selection)]
        }
    }

    private mutating func move(_ delta: Int, wrap: Bool) -> [Effect] {
        guard count > 0 else { return [] }
        selection = wrap ? ((selection + delta) % count + count) % count : min(max(selection + delta, 0), count - 1)
        return [.select(selection)]
    }

    private mutating func finish(_ effect: Effect) -> [Effect] {
        isActive = false
        return [effect]
    }
}
