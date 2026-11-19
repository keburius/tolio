import Foundation
import IOBluetooth

/// Tells when a Bluetooth device (AirPods, headphones, a keyboard)
/// connects or disconnects. IOBluetooth calls back on its own background
/// queue, so each callback copies what it needs and hops to the main thread.
@MainActor
final class BluetoothMonitor: NSObject {
    var onConnect: ((_ name: String, _ isAudio: Bool) -> Void)?
    var onDisconnect: ((_ name: String) -> Void)?
    private var connectNote: IOBluetoothUserNotification?
    private var disconnectNotes: [Box] = []
    private var startedAt = Date.distantFuture

    /// Holds IOBluetooth objects (not Sendable) while they cross to the main thread.
    final class Box: @unchecked Sendable {
        let note: IOBluetoothUserNotification
        init(_ note: IOBluetoothUserNotification) { self.note = note }
    }

    func start() {
        guard connectNote == nil else { return }
        startedAt = Date()
        connectNote = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
    }

    func stop() {
        connectNote?.unregister()
        connectNote = nil
        disconnectNotes.forEach { $0.note.unregister() }
        disconnectNotes.removeAll()
    }

    @objc nonisolated private func connected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let name = device.name ?? ""
        let audio = device.deviceClassMajor == kBluetoothDeviceClassMajorAudio
        let disconnect = device.register(forDisconnectNotification: self, selector: #selector(disconnected(_:device:))).map(Box.init)
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let disconnect { self.disconnectNotes.append(disconnect) }
                // Registering reports devices that were already connected; skip those.
                guard Date().timeIntervalSince(self.startedAt) > 2 else { return }
                self.onConnect?(name, audio)
            }
        }
    }

    @objc nonisolated private func disconnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let name = device.name ?? ""
        note.unregister()
        let id = ObjectIdentifier(note)
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.disconnectNotes.removeAll { ObjectIdentifier($0.note) == id }
                self.onDisconnect?(name)
            }
        }
    }
}
