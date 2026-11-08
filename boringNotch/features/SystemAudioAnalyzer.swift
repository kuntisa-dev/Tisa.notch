//
//  SystemAudioAnalyzer.swift
//  boringNotch
//
//  Captures system audio with ScreenCaptureKit and turns it into four
//  frequency-band levels (0...1) for the music visualizer.
//  Requires Screen & System Audio Recording permission. While capture runs,
//  macOS shows its screen-recording indicator in the menu bar.
//

import Accelerate
import AppKit
import CoreMedia
import ScreenCaptureKit

final class SystemAudioAnalyzer: NSObject, SCStreamOutput, SCStreamDelegate {
    static let shared = SystemAudioAnalyzer()

    static let bandCount = 4

    // MARK: Permission

    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows the system prompt (first time) or adds the app to the list in System Settings.
    @discardableResult
    static func requestPermission() -> Bool { CGRequestScreenCaptureAccess() }

    static func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: State (main thread)

    private var stream: SCStream?
    private var isStarting = false
    private var clients = 0
    private var stopTask: Task<Void, Never>?

    // MARK: Analysis (audio queue)

    private let audioQueue = DispatchQueue(label: "boringNotch.systemAudioAnalyzer")
    private let fftSize = 1024
    private let sampleRate: Double = 48_000
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]
    private var buffer: [Float] = []

    /// Band edges in Hz: bass, low-mid, high-mid, treble.
    private let bandEdges: [Double] = [40, 160, 600, 2_500, 10_000]

    // Shared between the audio queue and the main thread.
    private let lock = NSLock()
    private var _levels = [Float](repeating: 0, count: SystemAudioAnalyzer.bandCount)
    private var lastUpdate = Date.distantPast

    private override init() {
        let size = 1024
        var hann = [Float](repeating: 0, count: size)
        vDSP_hann_window(&hann, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        window = hann
        fftSetup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(size), .FORWARD)
        super.init()
    }

    deinit {
        if let fftSetup { vDSP_DFT_DestroySetup(fftSetup) }
    }

    /// Latest band levels (0...1), or nil when nothing fresh has arrived for half a second.
    func currentLevels() -> [Float]? {
        lock.lock()
        defer { lock.unlock() }
        guard Date().timeIntervalSince(lastUpdate) < 0.5 else { return nil }
        return _levels
    }

    // MARK: - Lifecycle (call on the main thread)

    /// Each visualizer that wants real levels calls acquire(); capture runs while any hold it.
    @MainActor
    func acquire() {
        clients += 1
        stopTask?.cancel()
        stopTask = nil
        Task { @MainActor in await self.startIfNeeded() }
    }

    @MainActor
    func release() {
        clients = max(0, clients - 1)
        guard clients == 0 else { return }
        stopTask?.cancel()
        // Short grace period so pausing and resuming quickly doesn't restart capture.
        stopTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, self.clients == 0 else { return }
            await self.stopCapture()
        }
    }

    @MainActor
    private func startIfNeeded() async {
        guard stream == nil, !isStarting, clients > 0, Self.hasPermission else { return }
        isStarting = true
        defer { isStarting = false }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return }

            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true
            config.sampleRate = Int(sampleRate)
            config.channelCount = 1
            // Video can't be turned off, so ask for the smallest, slowest frames possible.
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            config.showsCursor = false

            let newStream = SCStream(filter: filter, configuration: config, delegate: self)
            try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: audioQueue)
            try await newStream.startCapture()

            // Released while we were starting.
            if clients == 0 {
                try? await newStream.stopCapture()
                return
            }
            stream = newStream
        } catch {
            print("SystemAudioAnalyzer: could not start capture: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func stopCapture() async {
        guard let current = stream else { return }
        stream = nil
        try? await current.stopCapture()
        audioQueue.async { [weak self] in self?.buffer.removeAll(keepingCapacity: true) }
        lock.lock()
        _levels = [Float](repeating: 0, count: Self.bandCount)
        lock.unlock()
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("SystemAudioAnalyzer: stream stopped: \(error.localizedDescription)")
        Task { @MainActor in
            if self.stream === stream { self.stream = nil }
        }
    }

    // MARK: - SCStreamOutput (audio queue)

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }

        try? sampleBuffer.withAudioBufferList { audioBufferList, _ in
            // ScreenCaptureKit delivers 32-bit float PCM; with one channel there is one buffer.
            guard let first = audioBufferList.first, let raw = first.mData else { return }
            let count = Int(first.mDataByteSize) / MemoryLayout<Float>.size
            let samples = UnsafeBufferPointer(start: raw.assumingMemoryBound(to: Float.self), count: count)
            buffer.append(contentsOf: samples)
        }

        while buffer.count >= fftSize {
            let frame = Array(buffer[0..<fftSize])
            buffer.removeFirst(fftSize)
            analyze(frame)
        }
    }

    private func analyze(_ frame: [Float]) {
        guard let fftSetup else { return }
        let half = fftSize / 2

        // Window the frame, then split into even/odd samples as the real-input DFT expects.
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        var evens = [Float](repeating: 0, count: half)
        var odds = [Float](repeating: 0, count: half)
        for i in 0..<half {
            evens[i] = windowed[2 * i]
            odds[i] = windowed[2 * i + 1]
        }

        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        vDSP_DFT_Execute(fftSetup, evens, odds, &real, &imag)

        // Magnitude per bin, scaled back to roughly 0...1 of full-scale amplitude.
        let binWidth = sampleRate / Double(fftSize)
        let scale = Float(1.0 / Double(fftSize))
        var newLevels = [Float](repeating: 0, count: Self.bandCount)

        for band in 0..<Self.bandCount {
            let lo = max(1, Int(bandEdges[band] / binWidth))
            let hi = min(half - 1, Int(bandEdges[band + 1] / binWidth))
            guard hi > lo else { continue }
            var peak: Float = 0
            for bin in lo...hi {
                let magnitude = sqrtf(real[bin] * real[bin] + imag[bin] * imag[bin]) * scale
                peak = max(peak, magnitude)
            }
            // Map -60 dB...-6 dB onto 0...1.
            let db = 20 * log10f(max(peak, 1e-7))
            newLevels[band] = min(1, max(0, (db + 60) / 54))
        }

        lock.lock()
        for i in 0..<Self.bandCount {
            // Rise immediately, fall back gently.
            _levels[i] = max(newLevels[i], _levels[i] * 0.82)
        }
        lastUpdate = Date()
        lock.unlock()
    }
}
