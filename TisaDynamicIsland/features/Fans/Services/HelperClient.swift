//
//  HelperClient.swift
//  Tisa Fan Studio
//
//  The app's side of the privileged-helper relationship (PROMPT.md §5.3, §6.8):
//  SMAppService registration/approval, the NSXPCConnection lifecycle, heartbeats, and
//  a dev-friendly diagnosis of exactly *why* the helper is unusable.
//

import Foundation
import SMCKit

/// Everything that can go wrong talking to the helper, phrased for the UI.
enum HelperError: LocalizedError, Equatable {
    case notInstalled
    case requiresApproval
    case appNotInApplications(String)
    case connectionFailed(String)
    case replyFailed
    case timedOut(seconds: Double)
    case daemonReported(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "The privileged helper is not installed, so fans cannot be commanded."
        case .requiresApproval:
            return "The helper needs your approval in System Settings → General → Login Items."
        case .appNotInApplications(let path):
            return "Fan control from \(path) needs a development daemon: "
                + "build with Scripts/build-release.sh and copy the setup command from Fan Studio's Settings. "
                + "(The bundled daemon only works from /Applications, because its launch path is fixed there.)"
        case .connectionFailed(let detail):
            return "Could not talk to the helper: \(detail)"
        case .replyFailed:
            return "The helper did not answer."
        case .timedOut(let seconds):
            return "The helper did not respond within \(Int(seconds)) s."
        case .daemonReported(let message):
            return message
        }
    }

    /// True when fan control is simply not set up yet, rather than a command having
    /// failed. Monitoring-only is a supported state (PROMPT.md N7) and must not be
    /// reported as a fan-control error.
    var isPreconditionFailure: Bool {
        switch self {
        case .notInstalled, .requiresApproval, .appNotInApplications:
            return true
        case .connectionFailed, .replyFailed, .timedOut, .daemonReported:
            return false
        }
    }
}

/// Registers, monitors and talks to the root helper daemon.
final class HelperClient: NSObject, ObservableObject {

    enum InstallationState: Equatable {
        case unknown
        case notInstalled
        case requiresApproval
        case installed
        case unavailable(String)

        /// Shared reason string so the UI can recognise the "not in /Applications" case.
        static let notInApplicationsReason = "app is not in /Applications"

        /// Shared reason string for "the system has this daemon registered, but launchd will
        /// not start it" — see `HelperClient.probe()` for the mechanism.
        static let registeredButNotRespondingReason = "the installed helper could not authenticate this build"

        /// True for the state above, which is the one the app can repair by itself.
        var isRegisteredButNotResponding: Bool {
            if case .unavailable(let reason) = self {
                return reason == Self.registeredButNotRespondingReason
            }
            return false
        }

        var displayName: String {
            switch self {
            case .unknown: return "Checking…"
            case .notInstalled: return "Not installed"
            case .requiresApproval: return "Waiting for approval"
            case .installed: return "Installed"
            case .unavailable(let reason): return "Unavailable — \(reason)"
            }
        }

        var isUsable: Bool { self == .installed }

        /// The error to report when a command is attempted in this state. These are
        /// preconditions, not command failures: see `HelperError.isPreconditionFailure`.
        func preconditionError(bundlePath: String) -> HelperError {
            switch self {
            case .requiresApproval:
                return .requiresApproval
            case .unavailable(let reason) where reason == Self.notInApplicationsReason:
                return .appNotInApplications(bundlePath)
            case .installed, .unknown, .notInstalled, .unavailable:
                return .notInstalled
            }
        }
    }

    // MARK: - Published state

    @Published private(set) var installationState: InstallationState = .unknown
    @Published private(set) var isConnected = false
    @Published private(set) var capabilities: HelperCapabilities?
    @Published private(set) var lastError: String?
    /// Set when a version mismatch was found and a re-register is required.
    @Published private(set) var needsReinstall = false

    // MARK: - Internals

    private var connection: NSXPCConnection?
    /// True once a daemon has answered. Until then, a failed lookup is the expected
    /// answer to "is fan control set up?", not a fault worth logging as one.
    private var everConnected = false
    private let stateQueue = DispatchQueue(label: "com.kuntisa.helperclient")
    private var heartbeatTimer: DispatchSourceTimer?
    private var reconnectAttempts = 0
    private var log: DiagnosticsLog?

    /// True when this build can plausibly use SMAppService at all.
    var isInApplicationsFolder: Bool {
        Bundle.main.bundlePath.hasPrefix("/Applications/")
    }

    /// True when a LaunchDaemon plist is present in the system location.
    ///
    /// A registered-but-silent daemon is a different problem from an uninstalled one: it
    /// usually means launchd cannot start it (most often a dyld failure because the
    /// binary depends on something that is not part of the system). Saying "not installed"
    /// there sends the user down the wrong path, so it gets its own message.
    var hasRegisteredDaemonPlist: Bool {
        FileManager.default.fileExists(
            atPath: "/Library/LaunchDaemons/\(HelperConstants.helperPlistName)"
        )
    }

    var bundlePath: String { Bundle.main.bundlePath }

    func attach(log: DiagnosticsLog) {
        self.log = log
    }

    // MARK: - Installation

    @discardableResult
    func refreshInstallationState() -> InstallationState {
        let state: InstallationState = hasRegisteredDaemonPlist && !FanTestEnvironment.isRunningTests
            ? .unknown : .notInstalled
        publish { self.installationState = state }
        return state
    }

    @discardableResult
    func probe() async -> InstallationState {
        let state: InstallationState
        if !hasRegisteredDaemonPlist || FanTestEnvironment.isRunningTests {
            state = .notInstalled
        } else if let caps = await fetchCapabilities(), caps.isRoot, caps.version == HelperConstants.helperVersion {
            state = .installed
        } else {
            state = .unavailable(InstallationState.registeredButNotRespondingReason)
        }
        publish { self.installationState = state }
        return state
    }

    static func terminalCommand(bundlePath: String, action: String) -> String {
        func quote(_ path: String) -> String {
            "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        let script = quote(bundlePath + "/Contents/Resources/install-helper.sh")
        return "sudo /bin/bash \(script) \(action) \(quote(bundlePath))"
    }

    // MARK: - Connection

    /// Guards the cached connection. XPC invalidation arrives on its own queue, so the
    /// cache cannot be cleared unsynchronised.
    private let connectionLock = NSLock()

    /// Builds a connection, wired so that a dead one is also *forgotten*.
    ///
    /// This is the fix for "registered but not answering XPC" after installing the helper.
    /// A connection created while the daemon does not exist yet is permanently invalid:
    /// XPC invalidation is terminal, and reusing the object fails every subsequent call
    /// with "Couldn't communicate with a helper application". The app kept that dead object
    /// cached, so nothing recovered until it was restarted. Now the next call builds a
    /// fresh connection and launchd starts the daemon on demand.
    private func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(
            machServiceName: HelperConstants.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)

        // Captured weakly: the connection retains its handlers, so a strong capture here
        // would keep every dead connection alive forever.
        connection.interruptionHandler = { [weak self, weak connection] in
            guard let self else { return }
            let hadDaemon = self.everConnected
            if let connection { self.discardConnection(connection) }
            self.publish { self.isConnected = false }
            if hadDaemon {
                self.log?.warning("helper", "XPC connection interrupted — the daemon went away")
            }
        }
        connection.invalidationHandler = { [weak self, weak connection] in
            guard let self else { return }
            let hadDaemon = self.everConnected
            if let connection { self.discardConnection(connection) }
            self.publish { self.isConnected = false }
            if hadDaemon {
                self.log?.warning("helper", "XPC connection invalidated — the daemon went away")
            }
        }
        connection.resume()
        return connection
    }

    /// Forgets a dead connection while it is still the cached one. Identity-checked, so a
    /// handler firing late cannot throw away a newer, working connection.
    private func discardConnection(_ dead: NSXPCConnection) {
        connectionLock.lock()
        if connection === dead { connection = nil }
        connectionLock.unlock()
    }

    private func currentConnection() -> NSXPCConnection {
        connectionLock.lock()
        if let connection {
            connectionLock.unlock()
            return connection
        }
        connectionLock.unlock()

        // Built outside the lock: resume() can reach a handler synchronously.
        let fresh = makeConnection()

        connectionLock.lock()
        if let existing = connection {
            connectionLock.unlock()
            fresh.invalidate()
            return existing
        }
        connection = fresh
        connectionLock.unlock()

        publish { self.isConnected = true }
        return fresh
    }

    func closeConnection() {
        connectionLock.lock()
        let dead = connection
        connection = nil
        connectionLock.unlock()
        dead?.invalidate()
        publish { self.isConnected = false }
    }

    /// Connects (if needed) and verifies the daemon answers.
    ///
    /// Always probes over XPC first (see `probe()`), so a development daemon installed
    /// with `Scripts/dev-install-helper.sh` works from an Xcode-run build.
    ///
    /// A daemon that is registered but which launchd refuses to start is repaired here,
    /// once per run. That is the state every replacement of the app bundle lands in (the
    /// LWCR mechanism is described in `probe()`), and the repair is the same thing the
    /// Install button does — re-registering makes the system record a requirement that
    /// matches the executable again. Without this the user has to press that button after
    /// every install, which is exactly what they had to do before.
    @discardableResult
    func connect() async -> Bool {
        let state = await probe()
        publish { self.isConnected = state.isUsable }
        return state.isUsable
    }

    // MARK: - Typed calls

    private final class ReplyBox<T> {
        private let lock = NSLock()
        private var done = false
        private let continuation: CheckedContinuation<T, Error>

        init(_ continuation: CheckedContinuation<T, Error>) {
            self.continuation = continuation
        }

        func finish(_ result: Result<T, Error>) {
            lock.lock()
            defer { lock.unlock() }
            guard !done else { return }
            done = true
            continuation.resume(with: result)
        }
    }

    /// Runs one XPC call with an error handler and a timeout.
    ///
    /// The timeout has to **resume the continuation**, not merely cancel the call or race it
    /// against a sleeping task. A task group cannot return until every child has finished,
    /// and a checked continuation that nobody resumes never finishes — so the obvious
    /// "sleep 10 s, then throw" version does not time out at all: it hangs, and everything
    /// awaiting it hangs with it. A registered-but-unspawnable daemon produces exactly that
    /// shape, because the Mach service still exists, so the message is accepted and simply
    /// never answered.
    ///
    /// The symptom was expensive to find precisely because it looks like nothing at all:
    /// `connect()` never returned, so the installation state was never updated and the app
    /// sat on its initial "Checking…" — at launch, and for ever, because the poll loop that
    /// would have retried starts at the end of that same code path. The real fault (a stale
    /// SMAppService code requirement) could not be seen, let alone repaired.
    private func call<T>(
        timeout: TimeInterval,
        _ operation: @escaping (HelperProtocol, @escaping (T) -> Void) -> Void
    ) async throws -> T {
        let connection = currentConnection()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            let box = ReplyBox(continuation)

            // Detached, so nothing waits on it. ReplyBox ignores a second finish, which is
            // what makes a reply that arrives after the timeout harmless.
            Task.detached {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                box.finish(.failure(HelperError.timedOut(seconds: timeout)))
            }

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                box.finish(.failure(HelperError.connectionFailed(error.localizedDescription)))
            }) as? HelperProtocol else {
                box.finish(.failure(HelperError.replyFailed))
                return
            }
            operation(proxy) { value in box.finish(.success(value)) }
        }
    }

    /// - Parameter recordFailure: pass true only when a daemon is *expected* (i.e. right
    ///   after an install attempt). A routine probe of an uninstalled helper is normal.
    func fetchCapabilities(recordFailure: Bool = false) async -> HelperCapabilities? {
        do {
            // A live daemon answers this in milliseconds; the fan commands below are the
            // calls that legitimately need a long timeout. Keeping this short bounds the
            // launch-time registration repair, which may have to wait out several probes.
            let data = try await call(timeout: 5) { proxy, reply in
                proxy.capabilities(reply: reply)
            }
            let caps = HelperCoding.decode(HelperCapabilities.self, from: data)
            if caps != nil {
                everConnected = true
                // The daemon answered, so this machine has one installed. Remembered across
                // launches: see FanAppSettings.helperHasWorkedBefore.
                FanAppSettings.markHelperWorked()
            }
            publish {
                self.capabilities = caps
                self.isConnected = caps != nil
                if let caps, caps.version == HelperConstants.helperVersion {
                    self.needsReinstall = false
                }
            }
            return caps
        } catch {
            let hadDaemon = everConnected
            publish {
                self.isConnected = false
                self.lastError = error.localizedDescription
            }
            if recordFailure || hadDaemon {
                log?.failure("helper", "capabilities failed: \(error.localizedDescription)")
            } else {
                log?.info("helper", "no daemon answering — fan control is not set up")
            }
            return nil
        }
    }

    /// A three-value XPC reply collapsed into one value so it can flow through the
    /// generic `call` (an @objc reply with three parameters is not a single-value
    /// closure).
    private struct ApplyReply {
        var success: Bool
        var message: String?
        var statuses: Data?
    }

    private struct ResetReply {
        var success: Bool
        var message: String?
    }

    /// Sends a complete desired fan vector. Generous timeout: the M3/M4 unlock can
    /// legitimately take ~30 s.
    func applyFanStates(_ payloads: [FanCommandPayload]) async -> Result<[FanCommandStatus], HelperError> {
        guard installationState.isUsable else {
            return .failure(installationState.preconditionError(bundlePath: bundlePath))
        }
        let json = HelperCoding.encode(payloads)
        do {
            let reply: ApplyReply = try await call(timeout: 60) { proxy, done in
                proxy.applyFanStates(json) { success, message, statusData in
                    done(ApplyReply(success: success, message: message, statuses: statusData))
                }
            }
            let statuses: [FanCommandStatus] = reply.statuses.flatMap {
                HelperCoding.decode([FanCommandStatus].self, from: $0)
            } ?? []
            if reply.success {
                return .success(statuses)
            }
            return .failure(.daemonReported(reply.message ?? "The helper refused the fan command."))
        } catch let error as HelperError {
            return .failure(error)
        } catch {
            return .failure(.connectionFailed(error.localizedDescription))
        }
    }

    func resetAllToAuto() async -> Result<Void, HelperError> {
        guard installationState.isUsable else { return .success(()) }
        do {
            let reply: ResetReply = try await call(timeout: 30) { proxy, done in
                proxy.resetAllToAuto { success, message in
                    done(ResetReply(success: success, message: message))
                }
            }
            return reply.success
                ? .success(())
                : .failure(.daemonReported(reply.message ?? "The helper could not restore automatic control."))
        } catch let error as HelperError {
            return .failure(error)
        } catch {
            return .failure(.connectionFailed(error.localizedDescription))
        }
    }

    @discardableResult
    func sendHeartbeat() async -> Bool {
        guard installationState.isUsable else { return false }
        do {
            let alive: Bool = try await call(timeout: 10) { proxy, reply in
                proxy.heartbeat(reply: reply)
            }
            return alive
        } catch {
            log?.warning("helper", "heartbeat failed: \(error.localizedDescription)")
            return false
        }
    }

    func fetchStatus() async -> HelperStatus? {
        guard installationState.isUsable else { return nil }
        do {
            let data: Data = try await call(timeout: 10) { proxy, reply in
                proxy.status(reply: reply)
            }
            return HelperCoding.decode(HelperStatus.self, from: data)
        } catch {
            return nil
        }
    }

    func fetchEvents() async -> [FanControlEvent] {
        guard installationState.isUsable else { return [] }
        do {
            let data: Data = try await call(timeout: 10) { proxy, reply in
                proxy.recentEvents(reply: reply)
            }
            return HelperCoding.decode([FanControlEvent].self, from: data) ?? []
        } catch {
            return []
        }
    }

    // MARK: - Heartbeat

    /// Starts the 15 s dead-man ping. The helper resets fans after 60 s of silence
    /// (§6.7.4), so this must keep running while any fan is manual.
    func startHeartbeat() {
        guard heartbeatTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: stateQueue)
        timer.schedule(deadline: .now() + HelperConstants.heartbeatInterval,
                       repeating: HelperConstants.heartbeatInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.sendHeartbeat() }
        }
        timer.resume()
        heartbeatTimer = timer
    }

    func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    // MARK: - Helpers

    private func publish(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
