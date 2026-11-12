import CoreServices
import Foundation

/// Calls `handler` on the main thread when anything under `paths` changes.
/// Coalesces bursts using FSEvents latency. Call `stop()` before releasing.
@MainActor
public final class DirectoryWatcher {
    private let paths: [String]
    private let latency: TimeInterval
    private let handler: @MainActor () -> Void
    private var stream: FSEventStreamRef?

    public init(paths: [String], latency: TimeInterval = 2, handler: @escaping @MainActor () -> Void) {
        self.paths = paths
        self.latency = latency
        self.handler = handler
    }

    public var isRunning: Bool { stream != nil }

    public func start() {
        guard stream == nil, !paths.isEmpty else { return }
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault, directoryWatcherCallback, &context, paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
        ) else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    fileprivate func fire() { handler() }
}

/// Runs on the main queue (set with `FSEventStreamSetDispatchQueue`).
private func directoryWatcherCallback(
    _ stream: ConstFSEventStreamRef,
    _ info: UnsafeMutableRawPointer?,
    _ count: Int,
    _ paths: UnsafeMutableRawPointer,
    _ flags: UnsafePointer<FSEventStreamEventFlags>,
    _ ids: UnsafePointer<FSEventStreamEventId>
) {
    let address = UInt(bitPattern: info)
    MainActor.assumeIsolated {
        guard let pointer = UnsafeMutableRawPointer(bitPattern: address) else { return }
        Unmanaged<DirectoryWatcher>.fromOpaque(pointer).takeUnretainedValue().fire()
    }
}
