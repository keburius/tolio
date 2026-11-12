import Darwin
import Foundation
import IOKit.ps

/// Reads raw counters from the system. Keeps the previous readings to turn
/// cumulative counters into usage and rates.
@MainActor
final class SystemSampler {
    /// Free disk space is slower to read and changes slowly.
    static let diskInterval: TimeInterval = 60

    private let host = mach_host_self()
    private var previousTicks: [CPUTicks]?
    private var previousNet: (down: UInt64, up: UInt64, time: Date)?
    private var lastDisk: (free: UInt64, total: UInt64, time: Date)?

    /// Takes a reading. Rates need two calls; the first returns nil for them.
    func sample(now: Date = Date()) -> StatsSnapshot {
        var snapshot = StatsSnapshot()

        if let ticks = cpuTicks() {
            if let previousTicks { snapshot.cpu = StatsMath.cpuUsage(previous: previousTicks, current: ticks) }
            previousTicks = ticks
        }

        if let pages = vmPages() {
            snapshot.memoryUsed = StatsMath.memoryUsed(pages, pageSize: UInt64(getpagesize()))
            snapshot.memoryTotal = ProcessInfo.processInfo.physicalMemory
        }

        if let net = networkBytes() {
            if let previous = previousNet {
                let interval = now.timeIntervalSince(previous.time)
                snapshot.downloadRate = StatsMath.rate(bytes: StatsMath.counterDelta(previous: previous.down, current: net.down), over: interval)
                snapshot.uploadRate = StatsMath.rate(bytes: StatsMath.counterDelta(previous: previous.up, current: net.up), over: interval)
            }
            previousNet = (net.down, net.up, now)
        }

        if lastDisk == nil || now.timeIntervalSince(lastDisk!.time) >= Self.diskInterval, let disk = diskSpace() {
            lastDisk = (disk.free, disk.total, now)
        }
        snapshot.diskFree = lastDisk?.free
        snapshot.diskTotal = lastDisk?.total
        snapshot.battery = battery()
        return snapshot
    }

    func reset() {
        previousTicks = nil
        previousNet = nil
        lastDisk = nil
    }

    // MARK: - Readers

    private func cpuTicks() -> [CPUTicks]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return nil }
        defer {
            vm_deallocate(task_self_trap(), vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }
        let states = Int(CPU_STATE_MAX)
        return (0..<Int(cpuCount)).map { cpu in
            func tick(_ state: Int32) -> UInt64 { UInt64(UInt32(bitPattern: info[cpu * states + Int(state)])) }
            return CPUTicks(user: tick(CPU_STATE_USER), system: tick(CPU_STATE_SYSTEM), idle: tick(CPU_STATE_IDLE), nice: tick(CPU_STATE_NICE))
        }
    }

    private func vmPages() -> StatsMath.VMPages? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return nil }
        return .init(
            wired: UInt64(stats.wire_count), compressed: UInt64(stats.compressor_page_count),
            internalPages: UInt64(stats.internal_page_count), purgeable: UInt64(stats.purgeable_count)
        )
    }

    private func networkBytes() -> (down: UInt64, up: UInt64)? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }
        var down: UInt64 = 0, up: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            guard let address = entry.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
                  entry.pointee.ifa_flags & UInt32(IFF_UP) != 0,
                  let data = entry.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }
            let name = String(cString: entry.pointee.ifa_name)
            guard StatsMath.countsTowardThroughput(interface: name) else { continue }
            down += UInt64(data.pointee.ifi_ibytes)
            up += UInt64(data.pointee.ifi_obytes)
        }
        return (down, up)
    }

    private func diskSpace() -> (free: UInt64, total: UInt64)? {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity, let free = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return (UInt64(max(0, free)), UInt64(max(0, total)))
    }

    private func battery() -> StatsSnapshot.Battery? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description["Type"] as? String == "InternalBattery",
                  let current = description["Current Capacity"] as? Int,
                  let max = description["Max Capacity"] as? Int, max > 0 else { continue }
            let charging = description["Is Charging"] as? Bool ?? false
            let onAC = description["Power Source State"] as? String == "AC Power"
            let minutes = (charging ? description["Time to Full Charge"] : description["Time to Empty"]) as? Int
            return .init(
                percent: Int((Double(current) / Double(max) * 100).rounded()), isCharging: charging, onAC: onAC,
                minutesRemaining: (minutes ?? -1) > 0 ? minutes : nil
            )
        }
        return nil
    }
}
