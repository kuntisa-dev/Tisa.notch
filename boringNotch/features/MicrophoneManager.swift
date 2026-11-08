//
//  MicrophoneManager.swift
//  boringNotch
//
//  Mutes and unmutes the default input device through CoreAudio.
//

import CoreAudio
import Foundation

@MainActor
final class MicrophoneManager {
    static let shared = MicrophoneManager()

    /// Input volume remembered when a device has no mute switch and we mute it by setting volume to 0.
    private var volumeBeforeMute: [AudioObjectID: Float32] = [:]

    private init() {}

    // MARK: - Public

    /// Whether the current default input device is muted (or at zero volume).
    var isMuted: Bool {
        let device = defaultInputDevice()
        guard device != kAudioObjectUnknown else { return false }
        if let muted = readMute(device) { return muted }
        if let volume = readVolume(device) { return volume <= 0.001 }
        return false
    }

    /// Toggles the microphone. Returns the new muted state, or nil if no input device could be changed.
    @discardableResult
    func toggle() -> Bool? {
        let device = defaultInputDevice()
        guard device != kAudioObjectUnknown else { return nil }

        let shouldMute = !isMuted

        // Prefer the device's own mute switch.
        if isSettable(device, selector: kAudioDevicePropertyMute), writeMute(device, muted: shouldMute) {
            return shouldMute
        }

        // Fall back to input volume (0 when muted, the remembered level when unmuted).
        if isSettable(device, selector: kAudioDevicePropertyVolumeScalar) {
            if shouldMute {
                volumeBeforeMute[device] = readVolume(device) ?? 1.0
                if writeVolume(device, 0) { return true }
            } else {
                let restored = max(volumeBeforeMute[device] ?? 0.75, 0.1)
                if writeVolume(device, restored) { return false }
            }
        }

        return nil
    }

    // MARK: - CoreAudio helpers

    private func defaultInputDevice() -> AudioObjectID {
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : AudioObjectID(kAudioObjectUnknown)
    }

    private func inputAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func isSettable(_ device: AudioObjectID, selector: AudioObjectPropertySelector) -> Bool {
        var address = inputAddress(selector)
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(device, &address, &settable)
        return status == noErr && settable.boolValue
    }

    private func readMute(_ device: AudioObjectID) -> Bool? {
        var address = inputAddress(kAudioDevicePropertyMute)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value != 0 : nil
    }

    private func writeMute(_ device: AudioObjectID, muted: Bool) -> Bool {
        var address = inputAddress(kAudioDevicePropertyMute)
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr
    }

    private func readVolume(_ device: AudioObjectID) -> Float32? {
        var address = inputAddress(kAudioDevicePropertyVolumeScalar)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private func writeVolume(_ device: AudioObjectID, _ volume: Float32) -> Bool {
        var address = inputAddress(kAudioDevicePropertyVolumeScalar)
        var value = max(0, min(1, volume))
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr
    }
}
