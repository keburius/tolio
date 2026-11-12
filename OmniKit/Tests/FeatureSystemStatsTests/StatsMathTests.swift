@testable import FeatureSystemStats
import Foundation
import Testing

struct StatsMathTests {
    @Test func cpuUsageAcrossCores() throws {
        let previous = [CPUTicks(user: 100, system: 50, idle: 850, nice: 0), CPUTicks(user: 0, system: 0, idle: 1000, nice: 0)]
        let current = [CPUTicks(user: 160, system: 70, idle: 870, nice: 0), CPUTicks(user: 10, system: 0, idle: 1090, nice: 0)]
        // busy: (60+20) + 10 = 90; total: 100 + 100 = 200
        #expect(try #require(StatsMath.cpuUsage(previous: previous, current: current)) == 0.45)
    }

    @Test func cpuUsageNeedsMatchingSamplesAndElapsedTime() {
        let a = [CPUTicks(user: 1, system: 1, idle: 1, nice: 0)]
        #expect(StatsMath.cpuUsage(previous: a, current: a) == nil)
        #expect(StatsMath.cpuUsage(previous: a, current: a + a) == nil)
        #expect(StatsMath.cpuUsage(previous: [], current: []) == nil)
    }

    @Test func counterWrapAt32Bits() {
        #expect(StatsMath.counterDelta(previous: 100, current: 250) == 150)
        #expect(StatsMath.counterDelta(previous: 4_294_967_000, current: 200) == 496)
        #expect(StatsMath.counterDelta(previous: UInt64.max - 5, current: 4, bits: 64) == 10)
    }

    @Test func rateHandlesZeroInterval() {
        #expect(StatsMath.rate(bytes: 2000, over: 2) == 1000)
        #expect(StatsMath.rate(bytes: 2000, over: 0) == 0)
    }

    @Test func memoryUsedMatchesActivityMonitorFormula() {
        let pages = StatsMath.VMPages(wired: 100, compressed: 50, internalPages: 400, purgeable: 30)
        #expect(StatsMath.memoryUsed(pages, pageSize: 16384) == (370 + 100 + 50) * 16384)
        let odd = StatsMath.VMPages(wired: 1, compressed: 0, internalPages: 5, purgeable: 9)
        #expect(StatsMath.memoryUsed(odd, pageSize: 1) == 1)
    }

    @Test func interfaceFilter() {
        for name in ["en0", "en7", "bridge100x"] where !name.hasPrefix("bridge") {
            #expect(StatsMath.countsTowardThroughput(interface: name))
        }
        for name in ["lo0", "utun3", "awdl0", "llw0", "bridge0", "anpi1", "ap1"] {
            #expect(!StatsMath.countsTowardThroughput(interface: name), "\(name)")
        }
    }

    @Test func formatting() {
        #expect(StatsFormat.percent(0.456) == "46%")
        #expect(StatsFormat.rate(500) == "0 KB/s")
        #expect(StatsFormat.rate(12_400) == "12 KB/s")
        #expect(StatsFormat.rate(1_420_000) == "1.4 MB/s")
        #expect(StatsFormat.rate(120_000_000) == "120 MB/s")
        #expect(StatsFormat.rate(2_500_000_000) == "2.5 GB/s")
        #expect(StatsFormat.duration(minutes: 125) == "2:05")
    }

    @Test func menuBarTextFollowsSelectionAndSkipsMissing() {
        var snapshot = StatsSnapshot()
        snapshot.cpu = 0.12
        snapshot.memoryUsed = 8
        snapshot.memoryTotal = 16
        snapshot.battery = .init(percent: 82, isCharging: true, onAC: true, minutesRemaining: nil)
        #expect(snapshot.menuBarText(items: [.cpu, .memory]) == "CPU 12%  MEM 50%")
        #expect(snapshot.menuBarText(items: [.network]) == "") // no rate yet
        #expect(snapshot.menuBarText(items: [.battery, .cpu]) == "CPU 12%  ⚡︎82%")
        #expect(snapshot.menuBarText(items: []) == "")
    }
}

@MainActor
struct SamplerSmokeTests {
    @Test func readsRealCountersAndRatesAfterSecondSample() throws {
        let sampler = SystemSampler()
        let first = sampler.sample(now: Date())
        #expect(first.cpu == nil)
        #expect(first.downloadRate == nil)
        let memory = try #require(first.memoryUsed)
        #expect(memory > 0 && memory <= ProcessInfo.processInfo.physicalMemory)
        let total = try #require(first.diskTotal)
        #expect(try #require(first.diskFree) <= total)

        Thread.sleep(forTimeInterval: 0.3)
        let second = sampler.sample(now: Date())
        let cpu = try #require(second.cpu)
        #expect(cpu >= 0 && cpu <= 1)
        #expect(second.downloadRate != nil)
    }
}

struct WidestTextTests {
    @Test func widestTextCoversRealisticValues() {
        var real = StatsSnapshot()
        real.cpu = 0.07
        real.memoryUsed = 3
        real.memoryTotal = 4
        real.downloadRate = 1_234_567
        real.uploadRate = 12_345
        let items: Set<StatItem> = [.cpu, .memory, .network]
        #expect(StatsSnapshot.widestMenuBarText(items: items).count >= real.menuBarText(items: items).count)
        #expect(StatsSnapshot.widestMenuBarText(items: []).isEmpty)
    }
}
