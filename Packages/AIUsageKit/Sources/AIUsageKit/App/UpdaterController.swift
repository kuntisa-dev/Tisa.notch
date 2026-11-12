import Foundation
import Observation

/// Stand-in for the original edition's Sparkle updater. Tisa Dynamic Island updates itself,
/// so this engine never checks for, offers or installs updates; the update rows and banner stay
/// hidden because `isActive` is false and no version is ever available.
@MainActor
@Observable
final class UpdaterController {
    let isActive = false
    let canCheckForUpdates = false
    var automaticallyChecksForUpdates = false
    var betaChannelEnabled = false
    private(set) var availableUpdateVersion: String?

    func checkForUpdates() {}
    func installAvailableUpdate() {}
    func dismissAvailableUpdate() {}
    func resetToDefaults() {}
}
