//
//  main.swift
//  TisaFanStudioHelper
//
//  The privileged root launchd daemon.
//
//  Started on demand by launchd (the LaunchDaemon plist has RunAtLoad = false) as soon
//  as the app opens an `NSXPCConnection(machServiceName:options:.privileged)`, and kept
//  alive while any fan is manual. It exits once the last client disconnects and no fan
//  needs it any more.
//
//  Safety contract (PROMPT.md §6.7): whatever happens — SIGTERM, SIGINT, a crash, or the
//  app vanishing — the machine must not be left with `Ftst = 1` or a pinned fan that
//  nobody is driving. Three mechanisms cover it: this signal handler, the crash-recovery
//  state file read at startup, and the dead-man heartbeat in FanControlSession.
//

import Foundation
import SMCKit
import Security

if getuid() != 0 {
    // Reads would still work, but writes cannot: refuse loudly instead of pretending.
    FileHandle.standardError.write(
        Data("TisaFanHelper must run as root (launchd does this). Use Tools/afmctl for unprivileged reads.\n".utf8)
    )
    exit(EXIT_FAILURE)
}

// Installs from now on trust the developer team; older ones pinned one exact build.
let environment = ProcessInfo.processInfo.environment
guard let clientRequirement = environment[HelperConstants.clientTeamKey].flatMap(HelperClientRequirement.teamPinned)
        ?? environment[HelperConstants.clientHashKey].flatMap(HelperClientRequirement.hashPinned) else {
    NSLog("[TisaFanHelper] missing or invalid client team or hash")
    exit(EXIT_FAILURE)
}
var validatedRequirement: SecRequirement?
guard SecRequirementCreateWithString(clientRequirement as CFString, [], &validatedRequirement) == errSecSuccess else {
    NSLog("[TisaFanHelper] invalid code-signing requirement")
    exit(EXIT_FAILURE)
}

let helper = HelperService()
let signals = [SIGTERM, SIGINT, SIGHUP].map { number in
    signal(number, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
    source.setEventHandler {
        let recovered = helper.session.shutdown(reason: "signal \(number)")
        exit(recovered ? EXIT_SUCCESS : EXIT_FAILURE)
    }
    source.resume()
    return source
}
signal(SIGPIPE, SIG_IGN)

NSLog("[TisaFanHelper] starting v\(HelperConstants.helperVersion) as uid \(getuid())")

// Crash recovery + hardware probe happen before the listener serves anything.
helper.session.start()

let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
listener.setConnectionCodeSigningRequirement(clientRequirement)
listener.delegate = helper
listener.resume()

NSLog("[TisaFanHelper] listening on mach service \(HelperConstants.machServiceName)")

// The main run loop drives both the XPC listener and the IOKit power-notification
// source registered by the session.
withExtendedLifetime(signals) { RunLoop.main.run() }
