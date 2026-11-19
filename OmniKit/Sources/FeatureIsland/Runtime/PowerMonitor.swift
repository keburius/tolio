import Foundation
import IOKit.ps

/// Battery level and charger state, pushed when they change (no polling).
@MainActor
final class PowerMonitor {
    struct State: Equatable {
        var percent: Int
        var charging: Bool
        var onPower: Bool
    }

    private(set) var state: State?
    private var source: CFRunLoopSource?
    var onChange: ((_ old: State?, _ new: State) -> Void)?

    func start() {
        guard source == nil else { return }
        state = Self.read()
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.update() }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        self.source = source
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode) }
        source = nil
    }

    private func update() {
        guard let new = Self.read(), new != state else { return }
        let old = state
        state = new
        onChange?(old, new)
    }

    /// Nil on Macs without a battery.
    static func read() -> State? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for item in list {
            guard let description = IOPSGetPowerSourceDescription(info, item)?.takeUnretainedValue() as? [String: Any],
                  (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = description[kIOPSMaxCapacityKey] as? Int ?? 100
            return State(
                percent: max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current,
                charging: description[kIOPSIsChargingKey] as? Bool ?? false,
                onPower: (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            )
        }
        return nil
    }
}
