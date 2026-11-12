import Foundation

/// Cumulative CPU time of one core, in ticks.
public struct CPUTicks: Equatable, Sendable {
    public var user: UInt64
    public var system: UInt64
    public var idle: UInt64
    public var nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    var busy: UInt64 { user + system + nice }
    var total: UInt64 { busy + idle }
}

/// Pure calculations behind the stats display.
public enum StatsMath {
    /// Busy fraction (0…1) across all cores between two samples, or nil if
    /// the samples don't line up (core count changed, no time passed).
    public static func cpuUsage(previous: [CPUTicks], current: [CPUTicks]) -> Double? {
        guard previous.count == current.count, !current.isEmpty else { return nil }
        var busy: UInt64 = 0, total: UInt64 = 0
        for (old, new) in zip(previous, current) {
            busy += new.busy &- old.busy
            total += new.total &- old.total
        }
        guard total > 0 else { return nil }
        return min(1, Double(busy) / Double(total))
    }

    /// Difference of a counter that wraps at `bits` (interface byte counters are 32-bit).
    public static func counterDelta(previous: UInt64, current: UInt64, bits: UInt64 = 32) -> UInt64 {
        if current >= previous { return current - previous }
        let modulus: UInt64 = bits >= 64 ? 0 : (1 << bits)
        return modulus == 0 ? current &- previous : modulus - previous + current
    }

    /// Bytes per second.
    public static func rate(bytes: UInt64, over interval: TimeInterval) -> Double {
        interval > 0 ? Double(bytes) / interval : 0
    }

    /// Memory pages from `vm_statistics64`.
    public struct VMPages: Equatable, Sendable {
        public var wired: UInt64
        public var compressed: UInt64
        public var internalPages: UInt64
        public var purgeable: UInt64

        public init(wired: UInt64, compressed: UInt64, internalPages: UInt64, purgeable: UInt64) {
            self.wired = wired
            self.compressed = compressed
            self.internalPages = internalPages
            self.purgeable = purgeable
        }
    }

    /// "Memory Used" as Activity Monitor computes it: app memory
    /// (internal − purgeable) + wired + compressed.
    public static func memoryUsed(_ pages: VMPages, pageSize: UInt64) -> UInt64 {
        let app = pages.internalPages > pages.purgeable ? pages.internalPages - pages.purgeable : 0
        return (app + pages.wired + pages.compressed) * pageSize
    }

    /// Network interfaces that count toward throughput: physical and
    /// tethered links. Excludes loopback and virtual tunnels (VPN traffic
    /// would otherwise be counted twice).
    public static func countsTowardThroughput(interface name: String) -> Bool {
        let excluded = ["lo", "utun", "awdl", "llw", "bridge", "gif", "stf", "anpi", "ap", "ipsec", "vmenet"]
        return !excluded.contains { name.hasPrefix($0) }
    }
}

/// Formatting for the menu bar and popover.
public enum StatsFormat {
    public static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// Compact rate: "0 KB/s", "12 KB/s", "1.4 MB/s", "120 MB/s".
    public static func rate(_ bytesPerSecond: Double) -> String {
        let kb = bytesPerSecond / 1000
        if kb < 1 { return "0 KB/s" }
        if kb < 1000 { return "\(Int(kb.rounded())) KB/s" }
        let mb = kb / 1000
        if mb < 10 { return String(format: "%.1f MB/s", mb) }
        if mb < 1000 { return "\(Int(mb.rounded())) MB/s" }
        return String(format: "%.1f GB/s", mb / 1000)
    }

    public static func bytes(_ count: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: count), countStyle: .memory)
    }

    public static func storage(_ count: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: count), countStyle: .file)
    }

    /// "1:05" from minutes.
    public static func duration(minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}
