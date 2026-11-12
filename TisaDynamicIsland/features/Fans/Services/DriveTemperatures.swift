import Foundation

struct DriveTemperature: Identifiable, Equatable, Sendable {
    let id: String
    let celsius: Double?
}

enum DriveTemperatures {
    struct Result: Sendable {
        let drives: [DriveTemperature]
        let message: String
    }

    static func scan(includeExternal: Bool) -> Result {
        let candidates = ["/opt/homebrew/sbin/smartctl", "/opt/homebrew/bin/smartctl",
                          "/usr/local/sbin/smartctl", "/usr/local/bin/smartctl"]
        guard let tool = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) else {
            return Result(drives: [], message: "SMART readings require an installed smartctl. SMC storage sensors remain available in the sensor list.")
        }
        do {
            var arguments = ["list", "-plist"]
            if !includeExternal { arguments.append("internal") }
            arguments.append("physical")
            let plist = try run("/usr/sbin/diskutil", arguments)
            let diskList = try PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any]
            let rows = diskList?["AllDisksAndPartitions"] as? [[String: Any]] ?? []
            let names = rows.compactMap { $0["DeviceIdentifier"] as? String }.filter {
                $0.range(of: #"^disk[0-9]+$"#, options: .regularExpression) != nil
            }
            let drives = names.map { name in
                let response = try? run(tool, ["--json", "--attributes", "--nocheck=standby", "/dev/\(name)"])
                return DriveTemperature(id: name, celsius: response.flatMap(decodeTemperature))
            }
            return Result(drives: drives, message: drives.isEmpty ? "No physical drives were found." : "Drives that do not expose a temperature show Unavailable.")
        } catch {
            return Result(drives: [], message: "Could not enumerate physical drives.")
        }
    }

    static func decodeTemperature(_ data: Data) -> Double? {
        guard let values = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let standard = (values["temperature"] as? [String: Any])?["current"] as? Double
        let nvme = (values["nvme_smart_health_information_log"] as? [String: Any])?["temperature"] as? Double
        guard let value = standard ?? nvme, value.isFinite, (0...120).contains(value) else { return nil }
        return value
    }

    private static func run(_ executable: String, _ arguments: [String]) throws -> Data {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let timeLimit = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 4, execute: timeLimit)
        defer { timeLimit.cancel() }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data
    }
}
