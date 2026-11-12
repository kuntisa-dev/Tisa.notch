//
//  FanEnvironment.swift
//  Tisa Fan Studio
//
//  Composition root and the single owner of the polling loop.
//
//  One `SMCConnection` is shared by the sensor and fan services (reads only — every
//  write goes through the helper). The environment owns the tick that:
//    1. refreshes fan readings and sensor values,
//    2. evaluates the safety monitor (which can force maximum RPM),
//    3. otherwise runs the curve engine for sensor-based fans.
//
//  It also owns the lifecycle duties from §6.7: restore-on-quit, the dirty-exit flag,
//  wake re-sync, and starting/stopping the helper heartbeat.
//

import Foundation
import AppKit
import Combine
import SMCKit

@MainActor
final class FanEnvironment: ObservableObject {

    // MARK: - Services

    let smc: SMCConnection
    let log: DiagnosticsLog
    let helper: HelperClient
    let sensors: SensorService
    let fans: FanService
    let profiles: ProfileStore
    let curveEngine: CurveEngine
    let safety: SafetyMonitor

    @Published private(set) var platform: PlatformInfo

    // MARK: - Published UI state

    @Published var selection: SidebarItem = .fans
    /// Drives the first-run sheet and the unclean-exit recovery prompt.
    @Published var showOnboarding = false
    /// Set when the previous run ended without cleaning up (§6.7.5).
    @Published private(set) var uncleanExitDetected = false
    @Published private(set) var lastCurveWrite: [Int: Double] = [:]
    /// Transient banner text (helper missing, thermal override, mismatched profile…).
    @Published var banner: Banner?

    struct Banner: Identifiable, Equatable {
        enum Kind: Equatable { case warning, error, info }
        let id = UUID()
        let kind: Kind
        let title: String
        let message: String
        var actionTitle: String?
        var action: (() -> Void)?

        static func == (lhs: Banner, rhs: Banner) -> Bool { lhs.id == rhs.id }
    }

    enum SidebarItem: String, CaseIterable, Identifiable {
        case fans, sensors, profiles, settings, diagnostics

        var id: String { rawValue }
        var title: String {
            switch self {
            case .fans: return "Overview"
            case .sensors: return "Sensors"
            case .profiles: return "Profiles"
            case .settings: return "Settings"
            case .diagnostics: return "Diagnostics"
            }
        }
        var symbol: String {
            switch self {
            case .fans: return "fan"
            case .sensors: return "thermometer.medium"
            case .profiles: return "square.stack.3d.up"
            case .settings: return "gearshape"
            case .diagnostics: return "stethoscope"
            }
        }
    }

    // MARK: - Private

    /// Subscriptions that re-emit each child service's changes through this object.
    ///
    /// Nested `ObservableObject`s do NOT propagate: a view holding `@EnvironmentObject var env`
    /// is invalidated only by `FanEnvironment.objectWillChange`. Since every screen reads its
    /// data from a child (`env.fans.states`, `env.sensors.samples`,
    /// `env.helper.installationState`, `env.profiles.document`…), without this the UI simply
    /// stops updating — it showed "Checking…" forever and an empty Fans page until an
    /// unrelated environment property changed, which is what switching pages did.
    private var childObservers: [AnyCancellable] = []

    private var tickTimer: DispatchSourceTimer?
    private var tickInterval: TimeInterval = 1.0
    /// The interval the timers are running at now (`tickInterval`, or slower while idle).
    private var pacedInterval: TimeInterval = 1.0
    /// What is showing fan data right now: the open notch, the Fan Studio window, Settings.
    private var watchers: Set<String> = []
    /// Seconds between readings while nothing shows them and macOS is driving the fans.
    private static let idleInterval: TimeInterval = 5
    private var isApplyingProfile = false
    private let tickQueue = DispatchQueue(label: "com.kuntisa.tick", qos: .utility)
    private var wakeObserver: NSObjectProtocol?
    private var helperPollCounter = 0
    /// Last re-applied fan command, to catch a view re-applying in a loop.
    private var lastReapplySignature: (signature: String, at: Date)?
    /// One-shot: the "registered, but macOS will not start it" state is stable, so its banner
    /// must not come back every 30 s after the user dismisses it.
    private var reportedStuckHelper = false

    // MARK: - Init

    init() {
        FanAppSettings.registerDefaults()

        let platform = Platform.current()
        self.platform = platform

        let log = DiagnosticsLog()
        let smc = SMCConnection()
        let helper = HelperClient()
        helper.attach(log: log)

        self.log = log
        self.smc = smc
        self.helper = helper
        self.sensors = SensorService(smc: smc, platform: platform, log: log)
        self.fans = FanService(smc: smc, helper: helper, log: log)
        self.profiles = ProfileStore(fanCount: { [weak smc] in
            guard let smc else { return 2 }
            return smc.readInt("FNum") ?? 0
        })
        self.curveEngine = CurveEngine(log: log)
        self.safety = SafetyMonitor(log: log)

        observeChildServices()
    }

    /// Re-emits every child service's changes as this environment's own.
    ///
    /// A child publishing *during* a view update would still warn, which is why the views
    /// never mutate observable state from a lifecycle hook or an `onChange` handler —
    /// those go through `deferToNextRunLoop`.
    private func observeChildServices() {
        subscribe(fans.objectWillChange, service: "FanService")
        subscribe(sensors.objectWillChange, service: "SensorService")
        subscribe(profiles.objectWillChange, service: "ProfileStore")
        subscribe(safety.objectWillChange, service: "SafetyMonitor")
        subscribe(helper.objectWillChange, service: "HelperClient")
        subscribe(log.objectWillChange, service: "DiagnosticsLog")
    }

    /// Names of services that have published observable state off the main thread. Reported
    /// once each, because the log line is the only clue to a bug that otherwise presents as
    /// "the entire application is not responding".
    private static var offMainReported: Set<String> = []

    private func subscribe(_ publisher: ObservableObjectPublisher, service: String) {
        publisher
            .sink { [weak self] in
                guard let self else { return }
                guard Thread.isMainThread else {
                    // Forwarding this synchronously would push a cross-thread change into
                    // SwiftUI, which is what hangs the app. Hop instead, and say loudly that
                    // it happened: the service should be @MainActor (or hop before it writes).
                    if !Self.offMainReported.contains(service) {
                        Self.offMainReported.insert(service)
                        NSLog("[TisaFanStudio] BUG: \(service) published observable state off the main "
                              + "thread; hopping to main. Mark the type @MainActor, or route the "
                              + "mutation through the main queue — this freezes the UI otherwise.")
                    }
                    DispatchQueue.main.async { self.objectWillChange.send() }
                    return
                }
                self.objectWillChange.send()
            }
            .store(in: &childObservers)
    }

    // MARK: - Lifecycle

    func start() async {
        guard !FanTestEnvironment.isRunningTests else {
            log.warning("app", "start() ignored: running under XCTest")
            return
        }
        FanAppSettings.markRunStarted()
        uncleanExitDetected = FanAppSettings.previousRunWasUnclean

        // The expert override that disables RPM clamping is per-session by design
        // (§6.7.1) and the Settings pane says so — enforce it here.
        UserDefaults.standard.set(false, forKey: FanSettingsKey.allowUnsafeFanTargets)

        guard smc.connect() else {
            banner = Banner(
                kind: .error,
                title: "Cannot read the SMC",
                message: "Tisa Fan Studio could not open the AppleSMC user client. "
                    + "Make sure the app is not sandboxed and try again. (\(smc.snapshotStatistics().lastError ?? "unknown error"))"
            )
            log.failure("app", "could not connect to AppleSMC")
            return
        }

        log.info("app", "started on \(platform.summary)")
        safety.start()

        sensors.setPollingInterval(FanAppSettings.pollingInterval)
        sensors.start()

        fans.refreshReadings()
        sensors.updateFanSnapshot(fans.snapshot)

        await helper.connect()
        fans.setControlAvailable(helper.installationState.isUsable)
        refreshHelperBanner()

        if profiles.applyAtLaunch && !uncleanExitDetected {
            await applyActiveProfile(reason: "apply at launch")
        }

        observeWake()
        startTicking()
        log.info("app", "reading sensors every \(Int(pacedInterval)) s at launch, watchers: \(watchers.sorted()), manual fans: \(fans.manualFanIndices)")
    }

    /// Called from `applicationWillTerminate` (best effort, see §6.7.3).
    func shutdown() async {
        stopTicking()
        safety.stop()

        if FanAppSettings.restoreFansOnQuit {
            if helper.installationState.isUsable {
                log.info("app", "quitting — restoring automatic fan control")
                _ = await fans.restoreAllToAuto(reason: "app quit")
            }
        } else if !fans.manualFanIndices.isEmpty {
            log.warning("app", "quitting with fans still in custom mode (restore-on-quit is disabled)")
        }

        helper.stopHeartbeat()
        helper.closeConnection()
        sensors.stop()
        FanAppSettings.markRunEndedCleanly()
    }

    private func observeWake() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Hop to the main actor explicitly: the notification closure is Sendable and
            // must not touch main-actor state directly.
            Task { @MainActor in
                guard let self else { return }
                self.log.info("app", "system woke — re-enumerating keys and re-applying fan state")
                self.smc.invalidateCaches()
                // 2 s for SMC readiness, then re-sync (§6.7.6).
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self.sensors.rescanEverything()
                self.fans.refreshReadings()
                if !self.fans.manualFanIndices.isEmpty {
                    await self.reapplyDesiredState(reason: "wake re-sync")
                }
            }
        }
    }

    // MARK: - Tick loop

    /// Something on screen started or stopped showing fan data. With nothing watching and no
    /// fan under the app's control, sensors are read every few seconds instead of every tick.
    func setWatching(_ watcher: String, _ on: Bool) {
        if on { watchers.insert(watcher) } else { watchers.remove(watcher) }
        applyPacing()
    }

    private var wantedInterval: TimeInterval {
        let controlling = !fans.manualFanIndices.isEmpty || fans.isSafetyOverrideActive
        return watchers.isEmpty && !controlling ? max(tickInterval, Self.idleInterval) : tickInterval
    }

    private func applyPacing() {
        guard tickTimer != nil, wantedInterval != pacedInterval else { return }
        stopTicking()
        startTicking()
        log.info("app", "reading sensors every \(Int(pacedInterval)) s "
                 + (watchers.isEmpty ? "(nothing on screen shows them)" : "(shown by \(watchers.sorted().joined(separator: ", ")))"))
    }

    private func startTicking() {
        tickInterval = FanAppSettings.pollingInterval
        pacedInterval = wantedInterval
        sensors.setPollingInterval(pacedInterval)
        let timer = DispatchSource.makeTimerSource(queue: tickQueue)
        timer.schedule(deadline: .now() + min(pacedInterval, tickInterval), repeating: pacedInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in await self.tick() }
        }
        timer.resume()
        tickTimer = timer
    }

    func setPollingInterval(_ interval: TimeInterval) {
        tickInterval = interval
        stopTicking()
        startTicking()
    }

    private func stopTicking() {
        tickTimer?.cancel()
        tickTimer = nil
    }

    /// One control-loop iteration.
    private func tick() async {
        // 1. Refresh the hardware picture, and hand the fan readings to the sensor service
        //    (which polls on its own queue and must not call back into a main-actor service).
        fans.refreshReadings()
        sensors.updateFanSnapshot(fans.snapshot)
        // A fan going manual (or back to automatic) changes how often we need to look.
        applyPacing()

        // 2. Safety first: it can take the fans away from any profile.
        let samples = sensors.samples
        switch safety.evaluate(samples: samples) {
        case .engageMaximum(let trigger):
            _ = await fans.forceMaximumRPM(reason: trigger)
            banner = Banner(
                kind: .error,
                title: "Thermal override engaged",
                message: "\(trigger). All fans were commanded to maximum; the active profile returns "
                    + "once temperatures fall \(Int(SafetyBounds.thermalFloorHysteresis)) °C below the floor."
            )
            return

        case .releaseOverride:
            fans.endSafetyOverride()
            banner = nil
            await reapplyDesiredState(reason: "thermal override released")
            return

        case .none:
            break
        }

        if fans.isSafetyOverrideActive { return }

        // 3. Curves for sensor-based fans.
        let settings = fans.desiredSettings
        let tracked = curveEngine.trackedSensorKeys(settings: settings)
        sensors.setTrackedKeys(tracked)
        guard !tracked.isEmpty else { return }

        let written = await curveEngine.tick(
            settings: settings,
            fans: fans.snapshot.fans,
            temperatureProvider: { [weak self] key in
                self?.sensors.sample(forKey: key)?.rawValue
            },
            writer: { [weak self] fanIndex, rpm in
                guard let self else { return false }
                let sent = await self.fans.sendCurveTarget(
                    fanIndex: fanIndex,
                    rpm: rpm,
                    minimumDelta: FanAppSettings.minimumRPMDelta,
                    minimumInterval: 1.0
                )
                if sent { self.lastCurveWrite[fanIndex] = rpm }
                return sent
            },
            releaser: { [weak self] fanIndex in
                guard let self else { return false }
                return await self.fans.releaseCurveTarget(fanIndex: fanIndex)
            }
        )
        if !written.isEmpty {
            log.info("curve", "wrote targets for fan(s) \(written.map(String.init).joined(separator: ", "))")
        }

        // 4. Periodically re-check the helper so a dropped connection is visible.
        helperPollCounter += 1
        if helperPollCounter % 30 == 0 {
            await helper.connect()
            fans.setControlAvailable(helper.installationState.isUsable)
            refreshHelperBanner()
        }
    }

    // MARK: - Profile application

    /// Applies the active profile across every fan in one batched command.
    func applyActiveProfile(reason: String) async {
        guard !isApplyingProfile else { return }
        isApplyingProfile = true
        defer { isApplyingProfile = false }

        let (profile, warning) = profiles.reconciledActiveProfile()
        if let warning {
            banner = Banner(kind: .warning, title: "Profile adapted", message: warning)
        }

        // Without a daemon there is nothing to command — the fans are already under
        // macOS control, which is exactly what the Automatic profile asks for. Sending
        // the batch anyway would only produce a spurious failure at every launch.
        guard helper.installationState.isUsable else {
            log.info("profiles", "not applying “\(profile.name)” (\(reason)): "
                     + "fan control is unavailable, so the app is monitoring only")
            return
        }

        log.info("profiles", "applying “\(profile.name)” (\(reason))")
        fans.setDesiredSettings(profile.fans)
        curveEngine.resetAll()
        safety.reset()
        lastCurveWrite.removeAll()

        // Stage 1: mode changes and constant targets in one batch.
        var payloads: [FanCommandPayload] = []
        for setting in profile.fans {
            guard let fan = fans.snapshot.fans.first(where: { $0.index == setting.index }) else { continue }
            switch setting.mode {
            case .auto:
                payloads.append(.auto(setting.index))
            case .constant:
                let target = setting.rpm.resolved(maxRPM: fan.maxRPM)
                payloads.append(.manual(setting.index, rpm: fans.clamp(rpm: target, fan: fan)))
            case .sensor:
                // Only take the fan now if its sensor is already at or above the ramp's start.
                // Below that the fan stays with macOS, which idles it at 0 RPM — commanding the
                // fan's *minimum* there is what made switching to a sensor profile spin the
                // fans up immediately at a cold 40 °C.
                if curveIsActive(setting: setting) {
                    let floor = setting.startRPM ?? max(fan.minRPM, SafetyBounds.absoluteMinimumRPM)
                    payloads.append(.manual(setting.index, rpm: fans.clamp(rpm: floor, fan: fan)))
                } else {
                    payloads.append(.auto(setting.index))
                }
            }
        }

        let result = await fans.apply(payloads, reason: "profile “\(profile.name)”")
        if case .failure(let error) = result {
            banner = Banner(kind: .error, title: "Could not apply “\(profile.name)”", message: error.localizedDescription)
        }
    }

    /// Switches the active profile and applies it.
    func activateProfile(id: String) async {
        guard let (profile, warning) = profiles.setActive(id: id) else { return }
        if let warning {
            banner = Banner(kind: .warning, title: "Profile adapted", message: warning)
        }
        await applyActiveProfile(reason: "switched to “\(profile.name)”")
    }

    /// Re-sends the currently desired state (wake, thermal recovery, helper reconnect).
    ///
    /// Refuses an identical command repeated within a second. That is not a real request —
    /// nothing has changed and the helper's watchdog re-asserts anyway — and it is the
    /// signature of a view stuck re-applying: the "switching sensor keeps jumping" bug ran
    /// this path at ~30 Hz, one XPC round trip per iteration.
    func reapplyDesiredState(reason: String) async {
        let settings = fans.desiredSettings
        var payloads: [FanCommandPayload] = []
        for setting in settings where setting.mode != .auto {
            guard let fan = fans.snapshot.fans.first(where: { $0.index == setting.index }) else { continue }
            let target: Double
            switch setting.mode {
            case .constant:
                target = setting.rpm.resolved(maxRPM: fan.maxRPM)
            case .sensor:
                guard curveIsActive(setting: setting) else {
                    // Still below Tmin: this fan stays with macOS, not with us.
                    payloads.append(.auto(setting.index))
                    continue
                }
                target = curveEngine.lastAppliedRPM(fanIndex: setting.index)
                    ?? setting.startRPM
                    ?? max(fan.minRPM, SafetyBounds.absoluteMinimumRPM)
            case .auto:
                continue
            }
            payloads.append(.manual(setting.index, rpm: fans.clamp(rpm: target, fan: fan)))
        }
        guard !payloads.isEmpty else { return }

        let signature = payloads
            .map { "\($0.index):\($0.mode.rawValue):\(Int($0.targetRPM ?? -1))" }
            .joined(separator: ",")
        if let last = lastReapplySignature,
           last.signature == signature,
           Date().timeIntervalSince(last.at) < 1.0 {
            log.warning("fans", "ignoring a duplicate re-apply within 1 s (\(reason)) — "
                        + "a view is re-applying in a loop")
            return
        }
        lastReapplySignature = (signature, Date())

        log.info("fans", "re-applying desired state (\(reason))")
        curveEngine.resetAll()
        _ = await fans.apply(payloads, reason: reason)
    }

    // MARK: - Quick actions (menu bar)

    func setAutomatic() async {
        safety.reset()
        curveEngine.resetAll()
        _ = profiles.setActive(id: Profile.automaticID)
        fans.setDesiredSettings([FanSetting.auto(0), FanSetting.auto(1)])
        await applyActiveProfile(reason: "Automatic requested")
        banner = nil
    }

    func setFullBlast() async {
        _ = profiles.setActive(id: Profile.fullBlastID)
        await applyActiveProfile(reason: "Full Blast requested")
    }

    func setFanMode(_ mode: FanControlMode, fanIndex: Int) async {
        switch mode {
        case .auto:
            await fans.setAuto(fanIndex: fanIndex)
        case .constant:
            guard let fan = fans.snapshot.fans.first(where: { $0.index == fanIndex }) else { return }
            await fans.setConstant(fanIndex: fanIndex, rpm: fan.minRPM)
        case .sensor:
            let setting = fans.setting(for: fanIndex)
            let key = setting.sensorKey ?? defaultCurveSensor()?.key
            await fans.setCurve(
                fanIndex: fanIndex,
                sensorKey: key ?? SensorScanner.ComputedKey.cpuHottest,
                sensorName: defaultCurveSensor()?.name ?? "CPU hottest",
                minTemp: setting.minTemp > 0 ? setting.minTemp : 50,
                maxTemp: setting.maxTemp > setting.minTemp ? setting.maxTemp : 80
            )
        }
        persistCurrentSettingsIntoProfile()
    }

    /// Stores the current fan settings without editing either built-in profile.
    func persistCurrentSettingsIntoProfile() {
        let active = profiles.activeProfile
        let settings = fans.snapshot.fans.map { fans.setting(for: $0.index) }
        guard settings != active.fans else { return }
        if active.builtIn {
            profiles.setTemporaryProfile(fans: settings)
        } else {
            var updated = active
            updated.fans = settings
            profiles.replaceProfile(updated)
        }
    }

    /// True when a sensor curve should hold its fan right now: the tracked sensor is at or
    /// above the ramp's start temperature. An explicit `startRPM` always holds the fan.
    func curveIsActive(setting: FanSetting) -> Bool {
        if setting.startRPM != nil { return true }
        guard let key = setting.sensorKey,
              let temperature = sensors.sample(forKey: key)?.rawValue else {
            // No reading yet: leave the fan with macOS rather than guessing.
            return false
        }
        return temperature >= setting.minTemp
    }

    /// The sensor the curve editor/engine defaults to.
    func defaultCurveSensor() -> SensorSample? {
        sensors.sample(forKey: SensorScanner.ComputedKey.cpuHottest)
            ?? sensors.sample(forKey: SensorScanner.ComputedKey.cpuAverage)
            ?? sensors.temperatureSamples.first { !$0.isComputed }
    }

    // MARK: - Helper state

    func refreshHelperBanner() {
        if helper.installationState.isRegisteredButNotResponding, !reportedStuckHelper {
            reportedStuckHelper = true
            banner = Banner(
                kind: .warning,
                title: "Helper needs reconnecting",
                message: "Run the installation command from Settings, then Reconnect."
            )
        } else if helper.installationState.isUsable {
            reportedStuckHelper = false
            if banner?.title == "Helper needs reconnecting" { banner = nil }
        }
    }

    /// Re-probes the Mach service and re-syncs everything that depends on the answer.
    /// This is what the "Reconnect" button does after a development daemon is installed.
    func reconnectHelper() async {
        helper.closeConnection()
        let connected = await helper.connect()
        fans.setControlAvailable(helper.installationState.isUsable)
        log.info("helper", connected
                 ? "connected to the helper (\(helperStatusSummary))"
                 : "no helper is answering (\(helper.installationState.displayName))")

        if connected {
            if banner?.title == "Monitoring only" || banner?.title == "Fan control helper required" {
                banner = nil
            }
            // A daemon may have appeared while a profile with manual fans was waiting.
            if !fans.manualFanIndices.isEmpty {
                await reapplyDesiredState(reason: "helper connected")
            }
        } else {
            refreshHelperBanner()
        }
    }

    var helperStatusSummary: String {
        if !helper.installationState.isUsable { return helper.installationState.displayName }
        if let caps = helper.capabilities {
            return "v\(caps.version) · root \(caps.isRoot ? "yes" : "no") · "
                + "\(caps.unlockStyle.rawValue) · fans \(caps.controllableFans.map(String.init).joined(separator: ","))"
        }
        return helper.isConnected ? "Connected" : "Not connected"
    }

// MARK: - Diagnostics export

    func buildDiagnosticsReport() async -> String {
        let helperStatus = await helper.fetchStatus()
        let settingsSnapshot: [String: String] = [
            FanSettingsKey.temperatureUnit: FanAppSettings.temperatureUnit.rawValue,
            FanSettingsKey.pollingInterval: String(FanAppSettings.pollingInterval),
            FanSettingsKey.restoreFansOnQuit: String(FanAppSettings.restoreFansOnQuit),
            FanSettingsKey.allowUnsafeFanTargets: String(FanAppSettings.allowUnsafeFanTargets),
            FanSettingsKey.minimumRPMDelta: String(FanAppSettings.minimumRPMDelta),
            FanSettingsKey.thermalFloorEnabled: String(FanAppSettings.thermalFloorEnabled),
            FanSettingsKey.thermalFloorCelsius: String(FanAppSettings.thermalFloorCelsius),
            FanSettingsKey.thermalStateOverrideEnabled: String(FanAppSettings.thermalStateOverrideEnabled),
            FanSettingsKey.showUnknownSensors: String(FanAppSettings.showUnknownSensors),
            "safetyState": safety.state.displayName,
            "thermalState": SafetyMonitor.describe(safety.thermalState),
            "helperInstallation": helper.installationState.displayName,
            "inApplications": String(helper.isInApplicationsFolder),
        ]

        return DiagnosticsExporter.makeReport(
            platform: platform,
            fanSnapshot: fans.snapshot,
            scan: sensors.lastScan,
            entries: log.snapshot(),
            profiles: profiles.document,
            activeProfileName: profiles.activeProfileName,
            helperStatus: helperStatus,
            helperCapabilities: helper.capabilities,
            smcStatistics: smc.snapshotStatistics(),
            settings: settingsSnapshot
        )
    }
}

/// Runs a mutation on the next main-run-loop turn.
///
/// SwiftUI calls `onChange` handlers and binding setters as part of its update, so writing
/// observable state directly from one produces "Publishing changes from within view updates
/// is not allowed, this will cause undefined behavior" — and that undefined behaviour shows
/// up as stale or blank screens, and as internal framework exceptions such as
/// `-[__NSTaggedDate objectForKey:]` and `-[NSTaggedPointerString count]`.
///
/// Anything reachable from a view callback goes through here.
func deferToNextRunLoop(_ work: @escaping () -> Void) {
    DispatchQueue.main.async(execute: work)
}
