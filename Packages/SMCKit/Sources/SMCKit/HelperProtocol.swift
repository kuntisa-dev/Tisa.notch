//
//  HelperProtocol.swift
//  SMCKit (linked by BOTH Tisa Dynamic Island and its privileged fan helper)
//
//  The XPC contract between TisaFanStudio.app and its root launchd daemon
//  (PROMPT.md §5.3). It lives in `Shared/` on purpose: the interface must be
//  byte-identical on both sides, so there is exactly one source of truth.
//
//  Payloads travel as JSON `Data` rather than `@objc` classes so the wire format is
//  inspectable, versionable and identical to the on-disk profile schema.
//

import Foundation

// MARK: - Identifiers

public enum HelperConstants {
    /// Mach service name. MUST equal the helper bundle id and the `MachServices` key
    /// in the LaunchDaemon plist.
    public static let machServiceName = "com.kuntisa.tisadynamicisland.fanhelper"
    public static let helperBundleIdentifier = "com.kuntisa.tisadynamicisland.fanhelper"
    public static let helperPlistName = "com.kuntisa.tisadynamicisland.fanhelper.plist"
    public static let helperExecutableName = "TisaFanHelper"

    /// Bumped on every release; the app compares it over XPC and re-registers the
    /// daemon when it differs (Stats-proven update flow).
    ///
    /// Kept equal to the app's own `MARKETING_VERSION`, because the two ship together:
    /// both are 1.0.0. The comparison is on inequality, not on ordering, so a daemon left
    /// over from an earlier numbering (1.0.1) is still replaced.
    public static let helperVersion = "1.0.0"

    /// The daemon must live here inside the app bundle for `SMAppService.daemon`.
    public static let helperBundleSubpath = "Contents/Library/LaunchDaemons"

    public static let defaultAppBundleIdentifier = "com.kuntisa.tisadynamicisland"
    public static let clientHashKey = "TISA_FAN_CLIENT_CDHASH"
    /// Set by install-helper.sh: the signing team the app must come from.
    public static let clientTeamKey = "TISA_FAN_CLIENT_TEAM"

    /// Seconds without a heartbeat before the daemon returns fans to macOS control.
    public static let heartbeatTimeout: TimeInterval = 60
    /// The app pings this often while any fan is manual.
    public static let heartbeatInterval: TimeInterval = 15
    /// Watchdog re-assert cadence while any fan is manual.
    public static let watchdogInterval: TimeInterval = 5
}

// MARK: - Client requirement

public enum HelperClientRequirement {
    /// Any build of the app signed by this Apple developer team, except one that allows
    /// debugging (get-task-allow), since another process could take that one over.
    /// Rebuilding keeps working without reinstalling the helper.
    public static func teamPinned(_ team: String) -> String? {
        let bytes = team.utf8
        guard bytes.count == 10, bytes.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) }) else {
            return nil
        }
        return "anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.1] exists"
            + " and certificate leaf[subject.OU] = \"\(team)\""
            + " and identifier \"\(HelperConstants.defaultAppBundleIdentifier)\""
            + " and !entitlement[\"com.apple.security.get-task-allow\"] exists"
    }

    /// Only the exact build the helper was installed from (older installs).
    public static func hashPinned(_ hash: String) -> String? {
        let bytes = hash.utf8
        guard bytes.count == 40, bytes.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            return nil
        }
        return "cdhash H\"\(hash)\" and identifier \"\(HelperConstants.defaultAppBundleIdentifier)\""
    }
}

// MARK: - DTOs

/// One fan's desired state, as sent by the app in an `applyFanStates` batch.
public struct FanCommandPayload: Codable, Sendable, Equatable {
    public enum Mode: String, Codable, Sendable {
        case auto
        case manual
    }

    public var index: Int
    public var mode: Mode
    /// Absolute RPM when `mode == .manual`.
    public var targetRPM: Double?

    public init(index: Int, mode: Mode, targetRPM: Double? = nil) {
        self.index = index
        self.mode = mode
        self.targetRPM = targetRPM
    }

    public static func auto(_ index: Int) -> FanCommandPayload {
        FanCommandPayload(index: index, mode: .auto, targetRPM: nil)
    }

    public static func manual(_ index: Int, rpm: Double) -> FanCommandPayload {
        FanCommandPayload(index: index, mode: .manual, targetRPM: rpm)
    }
}

/// Per-fan result of an `applyFanStates` call — what the UI shows as the badge.
public struct FanCommandStatus: Codable, Sendable, Equatable, Identifiable {
    public enum State: String, Codable, Sendable {
        case idle
        case applying
        case active
        case failed
        /// The write succeeded but `F%dAc` never followed (pitfall #13).
        case unresponsive
    }

    public var index: Int
    public var state: State
    public var targetRPM: Double?
    public var actualRPM: Double?
    public var hardwareMode: FanHardwareMode
    public var message: String?

    public var id: Int { index }

    public init(
        index: Int,
        state: State,
        targetRPM: Double? = nil,
        actualRPM: Double? = nil,
        hardwareMode: FanHardwareMode = .unknown,
        message: String? = nil
    ) {
        self.index = index
        self.state = state
        self.targetRPM = targetRPM
        self.actualRPM = actualRPM
        self.hardwareMode = hardwareMode
        self.message = message
    }
}

/// What the daemon reports about itself and the hardware it can see.
public struct HelperCapabilities: Codable, Sendable, Equatable {
    public var version: String
    public var isRoot: Bool
    public var platform: PlatformInfo
    public var fanCount: Int
    public var hasFtst: Bool
    public var hasForceMask: Bool
    public var modeKeyIsLowercase: Bool
    public var unlockStyle: UnlockStyle
    /// Fans the daemon can actually command (some may be missing `F%dTg`).
    public var controllableFans: [Int]

    public init(
        version: String,
        isRoot: Bool,
        platform: PlatformInfo,
        fanCount: Int,
        hasFtst: Bool,
        hasForceMask: Bool,
        modeKeyIsLowercase: Bool,
        unlockStyle: UnlockStyle,
        controllableFans: [Int]
    ) {
        self.version = version
        self.isRoot = isRoot
        self.platform = platform
        self.fanCount = fanCount
        self.hasFtst = hasFtst
        self.hasForceMask = hasForceMask
        self.modeKeyIsLowercase = modeKeyIsLowercase
        self.unlockStyle = unlockStyle
        self.controllableFans = controllableFans
    }
}

/// Full daemon status, polled by the Settings pane and used by diagnostics.
public struct HelperStatus: Codable, Sendable, Equatable {
    public var version: String
    public var isRoot: Bool
    public var startedAt: Date
    public var lastHeartbeat: Date?
    public var desiredState: [FanCommandPayload]
    public var fanStatus: [FanCommandStatus]
    public var ftstHeld: Bool
    public var watchdogRuns: Int
    public var wakeRecoveries: Int
    public var resetReason: String?

    public init(
        version: String,
        isRoot: Bool,
        startedAt: Date,
        lastHeartbeat: Date?,
        desiredState: [FanCommandPayload],
        fanStatus: [FanCommandStatus],
        ftstHeld: Bool,
        watchdogRuns: Int,
        wakeRecoveries: Int,
        resetReason: String?
    ) {
        self.version = version
        self.isRoot = isRoot
        self.startedAt = startedAt
        self.lastHeartbeat = lastHeartbeat
        self.desiredState = desiredState
        self.fanStatus = fanStatus
        self.ftstHeld = ftstHeld
        self.watchdogRuns = watchdogRuns
        self.wakeRecoveries = wakeRecoveries
        self.resetReason = resetReason
    }
}

// MARK: - XPC protocol

/// The daemon's public interface. Every method is asynchronous with a reply block
/// because a fan command can block for seconds (the M3/M4 unlock waits for the
/// thermal daemon to yield).
@objc(TisaFanHelperProtocol)
public protocol HelperProtocol {

    /// The helper's own version string.
    func version(reply: @escaping (String) -> Void)

    /// JSON-encoded `HelperCapabilities` — what this machine can do.
    func capabilities(reply: @escaping (Data) -> Void)

    /// Applies a complete desired fan vector atomically.
    ///
    /// - Parameters:
    ///   - statesJSON: JSON array of `FanCommandPayload`.
    ///   - reply: success, an error message when not successful, and JSON-encoded
    ///     `[FanCommandStatus]` describing each fan.
    func applyFanStates(_ statesJSON: Data, reply: @escaping (Bool, String?, Data?) -> Void)

    /// Returns every fan to macOS control and clears `Ftst`. Never fails silently.
    func resetAllToAuto(reply: @escaping (Bool, String?) -> Void)

    /// Dead-man ping. A `false` reply means the daemon is about to reset fans.
    func heartbeat(reply: @escaping (Bool) -> Void)

    /// Full JSON-encoded `HelperStatus`.
    func status(reply: @escaping (Data) -> Void)

    /// JSON-encoded `[FanControlEvent]` — the daemon's recent fan-control history.
    func recentEvents(reply: @escaping (Data) -> Void)

    /// Clears `Ftst` and stops managing fans, then exits. The app unregisters the
    /// daemon afterwards.
    func uninstall(reply: @escaping (Bool, String?) -> Void)
}

// MARK: - JSON helpers

public enum HelperCoding {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public static func encode<T: Encodable>(_ value: T) -> Data {
        (try? encoder.encode(value)) ?? Data()
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? decoder.decode(type, from: data)
    }
}
