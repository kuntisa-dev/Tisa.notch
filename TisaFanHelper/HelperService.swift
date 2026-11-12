//
//  HelperService.swift
//  TisaFanStudioHelper
//
//  XPC listener delegate + `HelperProtocol` implementation, and — critically — the
//  client authentication that stops *any* local process from spinning this machine's
//  fans as root (PROMPT.md §5.3, pitfall #16).
//
//  The listener's code-signing requirement is configured before it starts.

import Foundation
import SMCKit

final class HelperService: NSObject, NSXPCListenerDelegate, HelperProtocol {

    let session = FanControlSession()

    /// Number of live client connections. The daemon exits when the last one drops and
    /// no fan is manual — there is nothing to keep running for.
    private let connectionLock = NSLock()
    private var activeConnections = 0
    private var exitWhenIdle = false

    // MARK: - Listener

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = self

        newConnection.invalidationHandler = { [weak self] in
            self?.connectionClosed()
        }
        newConnection.interruptionHandler = { [weak self] in
            self?.connectionClosed()
        }

        connectionLock.lock()
        activeConnections += 1
        connectionLock.unlock()

        newConnection.resume()
        NSLog("[TisaFanHelper] accepted connection from pid \(newConnection.processIdentifier)")
        return true
    }

    private func connectionClosed() {
        connectionLock.lock()
        activeConnections = max(0, activeConnections - 1)
        let shouldExit = exitWhenIdle && activeConnections == 0 && session.manualFanIndices.isEmpty
        connectionLock.unlock()

        if shouldExit {
            NSLog("[TisaFanHelper] last client disconnected and no fan is manual — exiting")
            exit(EXIT_SUCCESS)
        }
    }

    /// Ask the daemon to quit once the last client disconnects (used by uninstall).
    func exitWhenIdleAfterUninstall() {
        connectionLock.lock()
        exitWhenIdle = true
        let shouldExit = activeConnections == 0
        connectionLock.unlock()
        if shouldExit { exit(EXIT_SUCCESS) }
    }

    // MARK: - HelperProtocol

    func version(reply: @escaping (String) -> Void) {
        session.noteClientActivity()
        reply(HelperConstants.helperVersion)
    }

    func capabilities(reply: @escaping (Data) -> Void) {
        session.noteClientActivity()
        reply(HelperCoding.encode(session.capabilities()))
    }

    func applyFanStates(_ statesJSON: Data, reply: @escaping (Bool, String?, Data?) -> Void) {
        // Recorded before the work starts: unlocking a fan can take seconds, and the app is
        // very much alive while it waits.
        session.noteClientActivity()
        guard statesJSON.count <= 8_192,
              let payloads = HelperCoding.decode([FanCommandPayload].self, from: statesJSON),
              payloads.count <= 16, Set(payloads.map(\.index)).count == payloads.count else {
            reply(false, "The fan state payload was not valid JSON.", nil)
            return
        }
        let result = session.applyFanStates(payloads)
        reply(result.success, result.error, HelperCoding.encode(result.statuses))
    }

    func resetAllToAuto(reply: @escaping (Bool, String?) -> Void) {
        session.noteClientActivity()
        let result = session.resetAllToAuto(reason: "Requested by the app")
        reply(result.success, result.error)
    }

    func heartbeat(reply: @escaping (Bool) -> Void) {
        reply(session.heartbeat())
    }

    func status(reply: @escaping (Data) -> Void) {
        session.noteClientActivity()
        reply(HelperCoding.encode(session.status()))
    }

    func recentEvents(reply: @escaping (Data) -> Void) {
        session.noteClientActivity()
        reply(HelperCoding.encode(session.eventLog()))
    }

    func uninstall(reply: @escaping (Bool, String?) -> Void) {
        let result = session.resetAllToAuto(reason: "Helper uninstall requested by the app")
        guard result.success else { reply(false, result.error); return }
        let reset = session.shutdown(reason: "uninstall")
        reply(reset, reset ? nil : "Automatic recovery is pending.")
        guard reset else { return }
        // Give the reply a moment to flush before launchd reaps us.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.exitWhenIdleAfterUninstall()
        }
    }
}
