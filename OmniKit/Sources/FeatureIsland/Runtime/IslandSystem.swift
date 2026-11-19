import AppKit
import CoreWLAN
import Darwin
import OmniCore
import OmniPlatform
import QuickLookThumbnailing

/// CPU and memory use for the Stats widget. Sampled only while visible.
@MainActor
@Observable
final class SystemLoad {
    private(set) var cpu: Double = 0
    private(set) var memory: Double = 0
    /// Recent CPU samples, oldest first, for the little graph.
    private(set) var history: [Double] = []
    @ObservationIgnored private var previous: [(busy: UInt64, total: UInt64)] = []
    @ObservationIgnored private var task: Task<Void, Never>?

    func setLive(_ live: Bool) {
        task?.cancel()
        guard live else { return }
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.sample()
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    private func sample() {
        if let ticks = Self.cpuTicks() {
            if previous.count == ticks.count {
                var busy: UInt64 = 0, total: UInt64 = 0
                for (now, before) in zip(ticks, previous) {
                    busy += now.busy &- before.busy
                    total += now.total &- before.total
                }
                cpu = total > 0 ? Double(busy) / Double(total) : 0
                history = Array((history + [cpu]).suffix(24))
            }
            previous = ticks
        }
        memory = Self.memoryUsed()
    }

    private static func cpuTicks() -> [(busy: UInt64, total: UInt64)]? {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return nil }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)) }
        return (0..<Int(count)).map { cpuIndex in
            let base = cpuIndex * Int(CPU_STATE_MAX)
            let user = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            let system = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            let nice = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            let idle = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            return (user + system + nice, user + system + nice + idle)
        }
    }

    private static func memoryUsed() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return 0 }
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = Double(pageSize)
        let used = Double(stats.active_count + stats.wire_count + stats.compressor_page_count) * page
        return min(used / Double(ProcessInfo.processInfo.physicalMemory), 1)
    }
}

/// The Shortcuts app's shortcuts, listed and run with the `shortcuts` tool.
@MainActor
@Observable
final class ShortcutsLibrary {
    private(set) var names: [String] = []
    private(set) var loaded = false
    private(set) var running: String?

    func load() {
        Task { @MainActor [weak self] in
            let output = await Self.run(["list"])
            self?.names = output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            self?.loaded = true
        }
    }

    func run(_ name: String) {
        running = name
        Task { @MainActor [weak self] in
            _ = await Self.run(["run", name])
            if self?.running == name { self?.running = nil }
        }
    }

    private nonisolated static func run(_ arguments: [String]) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}

/// Watches Downloads for files a browser is still writing.
@MainActor
final class DownloadsMonitor {
    /// Final names of the files downloading now.
    var onChange: (_ active: [String], _ finished: [URL]) -> Void = { _, _ in }
    private var watcher: DirectoryWatcher?
    private var active: Set<String> = []
    private let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

    func start() {
        guard watcher == nil, let folder else { return }
        active = Set(scan())
        let watcher = DirectoryWatcher(paths: [folder.path], latency: 0.5) { [weak self] in self?.changed() }
        watcher.start()
        self.watcher = watcher
    }

    func stop() {
        watcher?.stop()
        watcher = nil
        active = []
    }

    private func scan() -> [String] {
        guard let folder, let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.filter(DownloadFiles.isPartial).map(DownloadFiles.finalName)
    }

    private func changed() {
        guard let folder else { return }
        let now = Set(scan())
        let finished = active.subtracting(now)
            .map { folder.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        active = now
        onChange(now.sorted(), finished)
    }
}

/// Small system switches for the Quick Actions widget.
@MainActor
enum QuickControls {
    static var wifiInterface: CWInterface? { CWWiFiClient.shared().interface() }

    static var wifiOn: Bool { wifiInterface?.powerOn() ?? false }

    static func setWiFi(_ on: Bool) {
        try? wifiInterface?.setPower(on)
    }

    static var darkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// Flips Light/Dark through System Events (macOS asks once).
    static func toggleDarkMode() {
        let source = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode" // l10n-ignore
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            _ = NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
    }

    static func sleepDisplay() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }

    static func startScreenSaver() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
    }
}

/// File previews for the Tray, made once and kept.
@MainActor
@Observable
final class Thumbnails {
    private(set) var images: [URL: NSImage] = [:]
    @ObservationIgnored private var pending: Set<URL> = []

    func image(for url: URL) -> NSImage {
        if let image = images[url] { return image }
        load(url)
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func load(_ url: URL) {
        guard !pending.contains(url) else { return }
        pending.insert(url)
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 96, height: 96),
                                                   scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            guard let cgImage = representation?.cgImage else { return }
            let size = CGSize(width: cgImage.width, height: cgImage.height)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.images[url] = NSImage(cgImage: cgImage, size: size)
                }
            }
        }
    }
}
