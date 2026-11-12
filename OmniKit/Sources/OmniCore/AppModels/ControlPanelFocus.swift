import Foundation

/// Keyboard focus in the control panel: a ring through every control in
/// reading order. Pure, so the order and wrap-around are tested.
public struct ControlPanelFocus: Equatable, Sendable {
    public enum Target: Hashable, Sendable {
        case tile(QuickAccessID)
        case recent(Int)
        case showAllClips
        case layout(String)
        case settings
        case quit
    }

    public enum Direction: Sendable { case left, right, up, down }

    public private(set) var targets: [Target]
    public private(set) var current: Target?
    /// Controls per row, for up/down.
    private let rows: [[Target]]

    public init(rows: [[Target]]) {
        self.rows = rows.filter { !$0.isEmpty }
        targets = self.rows.flatMap { $0 }
    }

    public mutating func focusFirst() { current = targets.first }

    public mutating func move(_ direction: Direction) {
        guard !targets.isEmpty else { return }
        guard let current, let index = targets.firstIndex(of: current) else {
            self.current = targets.first
            return
        }
        switch direction {
        case .right: self.current = targets[(index + 1) % targets.count]
        case .left: self.current = targets[(index - 1 + targets.count) % targets.count]
        case .down, .up:
            let rowIndex = rows.firstIndex { $0.contains(current) } ?? 0
            let column = rows[rowIndex].firstIndex(of: current) ?? 0
            let nextRow = direction == .down ? (rowIndex + 1) % rows.count : (rowIndex - 1 + rows.count) % rows.count
            let row = rows[nextRow]
            self.current = row[min(column, row.count - 1)]
        }
    }

    public mutating func focus(_ target: Target) {
        if targets.contains(target) { current = target }
    }
}
