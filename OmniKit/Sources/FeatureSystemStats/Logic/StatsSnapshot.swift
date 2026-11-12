import Foundation

/// The items that can appear in the menu bar.
public enum StatItem: String, CaseIterable, Codable, Sendable {
    case cpu, memory, disk, network, battery

    public var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .disk: "Disk"
        case .network: "Network"
        case .battery: "Battery"
        }
    }
}

/// One reading of everything the feature shows.
public struct StatsSnapshot: Equatable, Sendable {
    public struct Battery: Equatable, Sendable {
        public var percent: Int
        public var isCharging: Bool
        public var onAC: Bool
        /// Minutes to empty (on battery) or full (charging), if known.
        public var minutesRemaining: Int?
    }

    public var cpu: Double?
    public var memoryUsed: UInt64?
    public var memoryTotal: UInt64?
    public var diskFree: UInt64?
    public var diskTotal: UInt64?
    public var downloadRate: Double?
    public var uploadRate: Double?
    public var battery: Battery?

    public init() {}

    /// The widest text the chosen items can produce, used to give the menu
    /// bar item a fixed width so neighboring menu bar icons don't shift as
    /// the numbers change.
    public static func widestMenuBarText(items: Set<StatItem>) -> String {
        var widest = StatsSnapshot()
        widest.cpu = 1
        widest.memoryUsed = 1
        widest.memoryTotal = 1
        widest.diskFree = 888_000_000_000
        widest.downloadRate = 888_000_000
        widest.uploadRate = 888_000_000
        widest.battery = Battery(percent: 100, isCharging: true, onAC: true, minutesRemaining: nil)
        return widest.menuBarText(items: items)
    }

    /// Menu bar text for the chosen items, in a fixed order. Items without a
    /// reading yet (e.g. network before the second sample) are skipped.
    public func menuBarText(items: Set<StatItem>) -> String {
        var parts: [String] = []
        if items.contains(.cpu), let cpu { parts.append("CPU \(StatsFormat.percent(cpu))") }
        if items.contains(.memory), let used = memoryUsed, let total = memoryTotal, total > 0 {
            parts.append("MEM \(StatsFormat.percent(Double(used) / Double(total)))")
        }
        if items.contains(.disk), let free = diskFree { parts.append("SSD \(StatsFormat.storage(free)) free") }
        if items.contains(.network), let down = downloadRate, let up = uploadRate {
            parts.append("↓\(StatsFormat.rate(down)) ↑\(StatsFormat.rate(up))")
        }
        if items.contains(.battery), let battery {
            parts.append("\(battery.isCharging ? "⚡︎" : "")\(battery.percent)%")
        }
        return parts.joined(separator: "  ")
    }
}
