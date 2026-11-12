import Foundation

/// The transport seam telemetry is emitted through. Kept so the recorder's daily-rollup logic
/// compiles unchanged.
@MainActor
protocol TelemetrySink: AnyObject {
    func capture(_ event: String, _ properties: [String: Any])
    func setOptionalAnalyticsEnabled(_ enabled: Bool)
    func flush()
}

/// Tisa Dynamic Island sends no analytics or crash reports anywhere: every event is dropped here.
/// (The original edition reported to its author's PostHog project.)
@MainActor
final class NoTelemetrySink: TelemetrySink {
    nonisolated static func errorAutocaptureEnabled(optionalAnalyticsEnabled _: Bool) -> Bool { false }

    init(enabled _: Bool) {}
    func capture(_ event: String, _ properties: [String: Any]) {}
    func setOptionalAnalyticsEnabled(_ enabled: Bool) {}
    func flush() {}
}
