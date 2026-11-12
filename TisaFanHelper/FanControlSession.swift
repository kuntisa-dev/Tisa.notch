//
//  FanControlSession.swift
//  TisaFanStudioHelper
//
//  The daemon's brain: holds the single SMC connection, applies desired fan state
//  through `UnlockSequencer`, and keeps control alive across the many ways macOS takes
//  it back (PROMPT.md §5.3, §6.7).
//
//  Responsibilities
//    * apply a batched desired fan vector atomically
//    * watchdog every 5 s: `thermalmonitord` reclaims control when `Ftst` is not held
//      (polling ~4 s idle / ~250 ms under load), so mode/target are re-asserted
//    * dead-man switch: no heartbeat for 60 s while awake and manual → reset to auto
//    * sleep/wake: the firmware resets `Ftst` across sleep, so re-unlock + re-apply
//      ~2 s after wake
//    * crash recovery: a stale state file means the previous run died dirty → reset
//    * SIGTERM/SIGINT: best-effort reset before exiting
//

import Foundation
import IOKit
import IOKit.pwr_mgt
import SMCKit

/// IOKit system-power messages.
///
/// `kIOMessageCanSystemSleep` and friends are C *macros* in `<IOKit/IOMessage.h>`
/// (`#define kIOMessageSystemWillSleep iokit_common_msg(0x280)`), and Swift cannot
/// import function-like macros — so the expanded values live here:
/// `iokit_common_msg(m) = sys_iokit | sub_iokit_common | m = 0xE0000000 | m`.
private enum IOPowerMessage {
    static let canSystemSleep: UInt32 = 0xE000_0270
    static let systemWillSleep: UInt32 = 0xE000_0280
    static let systemWillPowerOn: UInt32 = 0xE000_0320
    static let systemHasPoweredOn: UInt32 = 0xE000_0300
}

final class FanControlSession {

    // MARK: - State

    /// All SMC access and fan commands are serialised here. Fan writes have multi-second
    /// unlock paths, so nothing else may interleave with them.
    private let queue = DispatchQueue(label: "com.kuntisa.helper.session")

    private let smc = SMCConnection()
    private let stateStore = HelperStateStore()

    private(set) var snapshot: FanHardwareSnapshot
    private var sequencer: UnlockSequencer

    private var desired: [Int: FanCommandPayload] = [:]
    private var statuses: [Int: FanCommandStatus] = [:]
    private var pendingRelease: [Int: FanCommandPayload] = [:]
    private var temperatureKeys: [String]?
    private var thermalHold = false
    /// Any client call updates this, so a multi-second apply cannot look like the app
    /// going silent to the dead-man switch.
    private var lastHeartbeatStorage: Date?
    private let heartbeatLock = NSLock()

    var lastHeartbeat: Date? {
        get { heartbeatLock.lock(); defer { heartbeatLock.unlock() }; return lastHeartbeatStorage }
        set { heartbeatLock.lock(); lastHeartbeatStorage = newValue; heartbeatLock.unlock() }
    }

    private var isAsleep = false
    private var isShuttingDown = false

    private let startedAt = Date()
    private(set) var watchdogRuns = 0
    private(set) var wakeRecoveries = 0
    private(set) var resetReason: String?
    private(set) var recentEvents: [FanControlEvent] = []

    private var watchdogTimer: DispatchSourceTimer?
    private var powerNotifyPort: IONotificationPortRef?
    private var powerNotifier: io_object_t = 0
    private var powerRootPort: io_connect_t = 0

    /// Called when the daemon decides to release control on its own (dead-man, sleep
    /// hygiene) so the caller can log it.
    var onForcedReset: ((String) -> Void)?

    // MARK: - Init

    init() {
        let platform = Platform.current()
        let probe = FanHardware.probe(smc, platform: platform)
        self.snapshot = probe
        self.sequencer = UnlockSequencer(access: smc, snapshot: probe)
        installEventSink()
    }

    /// Routes sequencer events into the diagnostics ring (always on the session queue).
    private func installEventSink() {
        sequencer.onEvent = { [weak self] event in
            guard let self else { return }
            self.queue.async {
                self.recentEvents.append(event)
                if self.recentEvents.count > 500 {
                    self.recentEvents.removeFirst(self.recentEvents.count - 500)
                }
            }
            NSLog("[TisaFanHelper] \(event.formatted)")
        }
    }

    // MARK: - Lifecycle

    /// Opens the SMC connection, re-probes hardware and recovers from a dirty previous
    /// run. MUST run before the XPC listener starts serving.
    func start() {
        queue.sync {
            guard smc.connect() else {
                NSLog("[TisaFanHelper] FATAL: could not open AppleSMC — \(smc.snapshotStatistics().lastError ?? "unknown")")
                return
            }
            refreshHardware()
            recoverFromPreviousRun()
        }

        registerPowerNotifications()
        startWatchdog()
    }

    /// Re-probes fan keys (also used after wake).
    private func refreshHardware() {
        smc.invalidateCaches()
        let probe = FanHardware.probe(smc, platform: Platform.current())
        snapshot = probe
        sequencer = UnlockSequencer(access: smc, snapshot: probe)
        installEventSink()
        NSLog("[TisaFanHelper] hardware: \(probe.fanCount) fan(s), mode key "
              + "\(probe.modeKeyIsLowercase ? "lowercase" : "uppercase"), Ftst=\(probe.hasFtst), "
              + "style=\(probe.unlockStyle.rawValue)")
    }

    /// A state file left behind by a previous run means that run did not exit cleanly:
    /// reset the hardware before doing anything else.
    private func recoverFromPreviousRun() {
        guard let stale = stateStore.load() else { return }
        pendingRelease = Dictionary(stale.desiredState.map { ($0.index, $0) }, uniquingKeysWith: { first, _ in first })
        _ = performReset(reason: "Recovering an interrupted cooling session")
    }

    /// Always runs on a regular dispatch queue, never inside a POSIX signal handler.
    func shutdown(reason: String) -> Bool {
        stopWatchdog()
        return queue.sync {
            isShuttingDown = true
            return performReset(reason: reason).success
        }
    }

    // MARK: - Desired state

    /// Applies a full fan vector. Returns per-fan statuses.
    func applyFanStates(_ payloads: [FanCommandPayload]) -> (success: Bool, error: String?, statuses: [FanCommandStatus]) {
        queue.sync {
            guard !isAsleep, !isShuttingDown, pendingRelease.isEmpty else {
                return (false, "The helper is restoring Automatic or the Mac is sleeping.", [])
            }
            if payloads.contains(where: { $0.mode == .manual }), shouldDeferToSystemCooling() {
                _ = performReset(reason: "macOS resumed cooling because the Mac is hot or sensor data is unavailable")
                return (false, "macOS is managing cooling until temperatures recover.", [])
            }
            var firstError: String?
            var results: [FanCommandStatus] = []

            for payload in payloads {
                guard let fan = snapshot.fans.first(where: { $0.index == payload.index }) else {
                    results.append(FanCommandStatus(
                        index: payload.index, state: .failed,
                        message: "Fan \(payload.index) is not present on this Mac."
                    ))
                    firstError = firstError ?? "Fan \(payload.index) is not present on this Mac."
                    continue
                }

                switch payload.mode {
                case .manual:
                    let minimum = max(500, fan.minRPM)
                    guard let rpm = payload.targetRPM, rpm.isFinite,
                          minimum.isFinite, fan.maxRPM.isFinite,
                          rpm >= minimum, rpm <= fan.maxRPM else {
                        let message = "The requested target is outside this fan's rated range."
                        results.append(.init(index: payload.index, state: .failed, message: message))
                        firstError = firstError ?? message
                        continue
                    }
                    if desired[fan.index] == nil,
                       smc.readInt(fan.modeKey) == 1 || (snapshot.hasFtst && smc.readInt("Ftst") == 1) && !sequencer.isFtstHeld {
                        let message = "Another utility already controls cooling. Return its fans to Automatic before continuing."
                        results.append(.init(index: payload.index, state: .failed, message: message))
                        firstError = firstError ?? message
                        continue
                    }
                    let previous = desired.updateValue(payload, forKey: fan.index)
                    guard persistState() else {
                        desired[fan.index] = previous
                        let message = "The helper could not save its cooling recovery state."
                        results.append(.init(index: payload.index, state: .failed, message: message))
                        firstError = firstError ?? message
                        continue
                    }
                    statuses[payload.index] = FanCommandStatus(
                        index: payload.index, state: .applying, targetRPM: rpm, actualRPM: fan.currentRPM,
                        hardwareMode: fan.hardwareMode
                    )
                    switch sequencer.setTarget(fan: fan, rpm: rpm) {
                    case .success(let outcome):
                        // A fan that is still spinning up is NOT a failure. Reporting it as
                        // one produced an error banner while the fan was visibly
                        // accelerating to the requested speed.
                        let state: FanCommandStatus.State
                        let message: String?
                        switch outcome.response {
                        case .atTarget:
                            state = .active
                            message = nil
                        case .converging:
                            state = .applying
                            message = "Spinning up toward \(Int(rpm)) RPM (at \(Int(outcome.actualRPM)) RPM)."
                        case .stalled:
                            state = .unresponsive
                            message = "The fan did not move after a \(Int(rpm)) RPM command."
                        }
                        let status = FanCommandStatus(
                            index: payload.index,
                            state: state,
                            targetRPM: rpm,
                            actualRPM: outcome.actualRPM,
                            hardwareMode: .manual,
                            message: message
                        )
                        statuses[payload.index] = status
                        results.append(status)
                        // Neither case fails the batch: the command was accepted. A stalled
                        // fan is surfaced on its own card (PROMPT.md pitfall #13), and the
                        // sequencer already logged a warning for it.
                    case .failure(let failure):
                        if let attempted = desired.removeValue(forKey: fan.index) {
                            pendingRelease[fan.index] = attempted
                            _ = releasePending()
                        }
                        let status = FanCommandStatus(
                            index: payload.index, state: .failed, targetRPM: rpm,
                            actualRPM: smc.readDouble(fan.actualKey) ?? fan.currentRPM,
                            hardwareMode: .unknown, message: failure.localizedDescription
                        )
                        statuses[payload.index] = status
                        results.append(status)
                        firstError = firstError ?? failure.localizedDescription
                    }

                case .auto:
                    if let owned = desired.removeValue(forKey: fan.index) {
                        pendingRelease[fan.index] = owned
                    }
                    switch releasePending() {
                    case nil:
                        let status = FanCommandStatus(
                            index: payload.index, state: .idle,
                            actualRPM: smc.readDouble(fan.actualKey) ?? fan.currentRPM,
                            hardwareMode: .auto
                        )
                        statuses[payload.index] = status
                        results.append(status)
                    case .some(let message):
                        let status = FanCommandStatus(index: payload.index, state: .failed, message: message)
                        statuses[payload.index] = status
                        results.append(status)
                        firstError = firstError ?? message
                    }
                }
            }

            persistState()
            return (firstError == nil, firstError, results)
        }
    }

    /// Returns every fan to macOS control and clears `Ftst`. Also used by the dead-man
    /// switch and by uninstall.
    @discardableResult
    func resetAllToAuto(reason: String) -> (success: Bool, error: String?) {
        queue.sync { performReset(reason: reason) }
    }

    /// The on-queue implementation. Watchdog ticks already run on `queue`, so they must
    /// call this directly — calling `resetAllToAuto` from there would deadlock.
    private func performReset(reason: String) -> (success: Bool, error: String?) {
        resetReason = reason
        pendingRelease.merge(desired) { existing, _ in existing }
        desired.removeAll()
        let failure = releasePending()
        _ = persistState()
        if failure == nil { markAllAuto(message: reason) }
        return (failure == nil, failure)
    }

    /// A failed handoff is retained and retried. Only release fans this daemon acquired.
    private func releasePending() -> String? {
        guard !pendingRelease.isEmpty else { return nil }
        var failure: String?
        var released: [Int] = []
        for index in pendingRelease.keys.sorted() {
            guard let fan = snapshot.fans.first(where: { $0.index == index }) else {
                failure = "A fan is temporarily unavailable."
                continue
            }
            if !snapshot.hasForceMask, let mode = smc.readInt(fan.modeKey),
               FanHardwareMode(rawValue: mode)?.isAutomatic == true {
                released.append(index)
                continue
            }
            switch sequencer.releaseAuto(fan: fan, isLastManualFan: false) {
            case .success: released.append(index)
            case .failure(let error): failure = error.localizedDescription
            }
        }
        if desired.isEmpty, snapshot.hasFtst {
            guard sequencer.clearFtstIfHeld() else {
                return "The firmware did not release its manual-control state."
            }
            if smc.readInt("Ftst") == 1, !smc.writeRaw("Ftst", bytes: [0]).isSuccess {
                return "The firmware did not release its manual-control state."
            }
        }
        for index in released { pendingRelease[index] = nil }
        return failure
    }

    private func markAllAuto(message: String?) {
        statuses.removeAll()
        for fan in snapshot.fans {
            statuses[fan.index] = FanCommandStatus(
                index: fan.index, state: .idle,
                actualRPM: smc.readDouble(fan.actualKey) ?? fan.currentRPM,
                hardwareMode: .auto, message: message
            )
        }
    }

    @discardableResult
    private func persistState() -> Bool {
        let manualFans = Array(desired.merging(pendingRelease) { _, pending in pending }.values)
        guard !manualFans.isEmpty else {
            stateStore.clear()
            return true
        }
        return stateStore.save(HelperPersistedState(
            manualActive: true, desiredState: manualFans, timestamp: Date(),
            helperVersion: HelperConstants.helperVersion, ftstHeld: sequencer.isFtstHeld
        ))
    }

    private func shouldDeferToSystemCooling() -> Bool {
        let systemState = ProcessInfo.processInfo.thermalState
        if systemState == .serious || systemState == .critical { thermalHold = true; return true }
        if temperatureKeys == nil {
            temperatureKeys = smc.allKeys().filter { SensorScanner.classify($0) == .temperature }
        }
        var options = SensorScanner.Options()
        options.includeComputed = false
        let samples = SensorScanner.scan(smc, platform: snapshot.platform, options: options,
                                         keys: temperatureKeys).temperatureSamples
        let critical = samples.filter { [.cpu, .gpu, .hid].contains($0.criticalGroup) }
        guard let hottest = critical.map(\.rawValue).max() else { return true }
        thermalHold = hottest >= (thermalHold ? 85 : 95)
        return thermalHold
    }

    // MARK: - Heartbeat / dead-man

    /// Evidence that the app is alive. Called at the start of every XPC entry point, not
    /// just `heartbeat`, because an `applyFanStates` that spends seconds unlocking a fan is
    /// itself proof the app is talking to us.
    func noteClientActivity() {
        lastHeartbeat = Date()
    }

    /// Records an app heartbeat. A `false` reply means the daemon is no longer willing
    /// to hold fans (shutting down), so the app should stop expecting manual control.
    @discardableResult
    func heartbeat() -> Bool {
        noteClientActivity()
        return queue.sync { !isShuttingDown }
    }

    var manualFanIndices: [Int] {
        queue.sync { desired.values.filter { $0.mode == .manual }.map(\.index).sorted() }
    }

    // MARK: - Watchdog

    private func startWatchdog() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + HelperConstants.watchdogInterval,
                       repeating: HelperConstants.watchdogInterval)
        timer.setEventHandler { [weak self] in
            self?.watchdogTick()
        }
        timer.resume()
        watchdogTimer = timer
    }

    private func stopWatchdog() {
        watchdogTimer?.cancel()
        watchdogTimer = nil
    }

    /// One watchdog pass: re-assert manual fans, then enforce the dead-man timeout.
    private func watchdogTick() {
        guard !isShuttingDown, !isAsleep else { return }
        if !pendingRelease.isEmpty {
            _ = releasePending()
            _ = persistState()
        }
        let manualFans = desired.values.filter { $0.mode == .manual }
        guard !manualFans.isEmpty else { return }
        if shouldDeferToSystemCooling() {
            _ = performReset(reason: "Thermal safeguard")
            return
        }

        watchdogRuns += 1

        // Dead-man: the app stopped talking to us.
        if let last = lastHeartbeat,
           Date().timeIntervalSince(last) > HelperConstants.heartbeatTimeout {
            NSLog("[TisaFanHelper] dead-man: no heartbeat for \(Int(Date().timeIntervalSince(last)))s — releasing fans")
            _ = performReset(reason: "The app stopped responding (dead-man switch)")
            onForcedReset?("dead-man")
            return
        }

        // Re-assert: thermalmonitord reclaims control when Ftst is not held.
        for payload in manualFans {
            guard let rpm = payload.targetRPM,
                  let fan = snapshot.fans.first(where: { $0.index == payload.index }) else { continue }

            let currentMode = smc.readInt(fan.modeKey)
            let actual = smc.readDouble(fan.actualKey) ?? 0
            let tolerance = max(150, rpm * 0.05)

            // Settled: nothing to write, but the badge may still be showing "Applying…"
            // from the moment the command was sent. Refresh it so the UI converges.
            if currentMode == 1, abs(actual - rpm) <= tolerance {
                statuses[fan.index] = FanCommandStatus(
                    index: fan.index, state: .active, targetRPM: rpm,
                    actualRPM: actual, hardwareMode: .manual
                )
                continue
            }

            if currentMode != 1 {
                NSLog("[TisaFanHelper] watchdog: fan \(fan.index) fell back to mode \(currentMode ?? -1) — re-asserting")
            }
            switch sequencer.setTarget(fan: fan, rpm: rpm) {
            case .success(let outcome):
                statuses[fan.index] = FanCommandStatus(
                    index: fan.index,
                    state: outcome.unresponsive ? .unresponsive : .active,
                    targetRPM: rpm,
                    actualRPM: outcome.actualRPM,
                    hardwareMode: .manual,
                    message: outcome.unresponsive ? "The fan did not respond to the commanded RPM." : nil
                )
            case .failure(let failure):
                pendingRelease[fan.index] = desired.removeValue(forKey: fan.index)
                _ = releasePending()
                _ = persistState()
                statuses[fan.index] = FanCommandStatus(
                    index: fan.index, state: .failed, targetRPM: rpm,
                    actualRPM: actual, hardwareMode: .unknown, message: failure.localizedDescription
                )
                NSLog("[TisaFanHelper] watchdog: re-assert failed for fan \(fan.index): \(failure.localizedDescription)")
            }
        }
    }

    // MARK: - Power notifications

    /// Sleep resets `Ftst` in firmware, so manual control is ALWAYS lost on wake; the
    /// daemon re-unlocks and re-applies ~2 s after power-on (ThermalForge pattern).
    private func registerPowerNotifications() {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceInterestCallback = { refcon, _, message, argument in
            guard let refcon else { return }
            let session = Unmanaged<FanControlSession>.fromOpaque(refcon).takeUnretainedValue()
            session.handlePowerMessage(message, argument: argument)
        }
        powerRootPort = IORegisterForSystemPower(refcon, &powerNotifyPort, callback, &powerNotifier)
        guard powerRootPort != 0, let port = powerNotifyPort else {
            NSLog("[TisaFanHelper] WARNING: IORegisterForSystemPower failed; wake re-apply disabled")
            return
        }
        let source = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func handlePowerMessage(_ message: UInt32, argument: UnsafeMutableRawPointer?) {
        let notificationID = Int(bitPattern: argument)

        if message == IOPowerMessage.canSystemSleep {
            IOAllowPowerChange(powerRootPort, notificationID)

        } else if message == IOPowerMessage.systemWillSleep {
            queue.sync {
                _ = performReset(reason: "Mac is going to sleep")
                isAsleep = true
            }
            NSLog("[TisaFanHelper] system will sleep — manual fan control will be lost")
            IOAllowPowerChange(powerRootPort, notificationID)

        } else if message == IOPowerMessage.systemHasPoweredOn {
            queue.sync { isAsleep = false }
            queue.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self, !self.isShuttingDown else { return }
                self.refreshHardware()
                self.temperatureKeys = nil
                self.watchdogTick()
            }
        }
    }

    // MARK: - Status

    func status() -> HelperStatus {
        queue.sync {
            HelperStatus(
                version: HelperConstants.helperVersion,
                isRoot: getuid() == 0,
                startedAt: startedAt,
                lastHeartbeat: lastHeartbeat,
                desiredState: desired.values.sorted { $0.index < $1.index },
                fanStatus: statuses.values.sorted { $0.index < $1.index },
                ftstHeld: sequencer.isFtstHeld,
                watchdogRuns: watchdogRuns,
                wakeRecoveries: wakeRecoveries,
                resetReason: resetReason
            )
        }
    }

    func capabilities() -> HelperCapabilities {
        queue.sync {
            HelperCapabilities(
                version: HelperConstants.helperVersion,
                isRoot: getuid() == 0,
                platform: snapshot.platform,
                fanCount: snapshot.fanCount,
                hasFtst: snapshot.hasFtst,
                hasForceMask: snapshot.hasForceMask,
                modeKeyIsLowercase: snapshot.modeKeyIsLowercase,
                unlockStyle: snapshot.unlockStyle,
                controllableFans: snapshot.fans.filter { smc.exists($0.targetKey) }.map(\.index)
            )
        }
    }

    func eventLog() -> [FanControlEvent] {
        queue.sync { recentEvents }
    }
}
