import AppKit
import Foundation
import UniformTypeIdentifiers

enum DiagnosticsArchive {
    @MainActor
    static func export(from environment: FanEnvironment) async throws -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "TisaFanStudio-diagnostics.zip"
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let destination = panel.url else { return nil }
        let report = await environment.buildDiagnosticsReport()
        try await Task.detached(priority: .utility) {
            try write(report, to: destination)
        }.value
        return destination
    }

    static func write(_ report: String, to destination: URL) throws {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: staging) }

        let input = staging.appendingPathComponent("diagnostics.txt")
        let zip = staging.appendingPathComponent("diagnostics.zip")
        try report.write(to: input, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--norsrc", "--keepParent", input.path, zip.path]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
        try Data(contentsOf: zip).write(to: destination, options: .atomic)
    }
}
