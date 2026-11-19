import AudioToolbox
import CoreAudio
import Foundation

/// The default output's volume and mute, reported when they change.
@MainActor
final class VolumeMonitor {
    var onChange: ((_ volume: Double, _ muted: Bool) -> Void)?
    private var device = AudioObjectID(kAudioObjectUnknown)
    private var listening: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var last: (Double, Bool)?

    func start() {
        guard listening.isEmpty else { return }
        var defaultAddress = Self.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        let deviceChanged: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.attach() }
        }
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, .main, deviceChanged)
        listening.append((AudioObjectID(kAudioObjectSystemObject), defaultAddress, deviceChanged))
        attach()
    }

    func stop() {
        for (object, address, block) in listening {
            var address = address
            AudioObjectRemovePropertyListenerBlock(object, &address, .main, block)
        }
        listening.removeAll()
    }

    /// Listens to the current default output device.
    private func attach() {
        // Drop listeners on the previous device (keep the system one).
        for (object, address, block) in listening.dropFirst() {
            var address = address
            AudioObjectRemovePropertyListenerBlock(object, &address, .main, block)
        }
        listening = Array(listening.prefix(1))
        device = Self.defaultOutput()
        last = read()
        guard device != kAudioObjectUnknown else { return }
        for selector in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute] {
            var address = Self.address(selector, scope: kAudioDevicePropertyScopeOutput)
            guard AudioObjectHasProperty(device, &address) else { continue }
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                DispatchQueue.main.async { self?.changed() }
            }
            AudioObjectAddPropertyListenerBlock(device, &address, .main, block)
            listening.append((device, address, block))
        }
    }

    private func changed() {
        guard let now = read() else { return }
        defer { last = now }
        if let last, abs(last.0 - now.0) < 0.001, last.1 == now.1 { return }
        onChange?(now.0, now.1)
    }

    private func read() -> (Double, Bool)? {
        guard device != kAudioObjectUnknown else { return nil }
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume) == noErr else { return nil }
        var mute = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        address = Self.address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        let muted = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &mute) == noErr && mute != 0
        return (Double(volume), muted)
    }

    private static func defaultOutput() -> AudioObjectID {
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }

    private static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
}
