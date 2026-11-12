//
//  FanAppSettings.swift
//  Tisa Fan Studio
//
//  Preference keys and defaults (PROMPT.md §6.6).
//
//  Simple preferences live in UserDefaults and are bound directly with `@AppStorage`
//  in the Settings pane; services read the same keys through this enum so there is one
//  spelling of each key. Profiles (the larger, structured state) are JSON on disk
//  instead — see ProfileStore.
//

import Foundation
import SMCKit

enum FanSettingsKey {
    // General
    static let temperatureUnit = "fan.temperatureUnit"
    static let pollingInterval = "fan.pollingInterval"
    static let preciseTemperatures = "fan.preciseTemperatures"

    // Fan control
    static let restoreFansOnQuit = "fan.restoreFansOnQuit"
    static let allowUnsafeFanTargets = "fan.allowUnsafeFanTargets"
    static let minimumRPMDelta = "fan.minimumRPMDelta"

    // Safety (§6.7.2)
    static let thermalFloorEnabled = "fan.thermalFloorEnabled"
    static let thermalFloorCelsius = "fan.thermalFloorCelsius"
    static let thermalStateOverrideEnabled = "fan.thermalStateOverrideEnabled"

    // Sensors
    static let showUnknownSensors = "fan.showUnknownSensors"
    static let extendedHIDSensors = "fan.extendedHIDSensors"

    // Helper history
    /// Set the first time the daemon answers this app; cleared by an explicit uninstall.
    /// See `FanAppSettings.helperHasWorkedBefore`.
    static let helperHasWorkedBefore = "fan.helperHasWorkedBefore"

    // Lifecycle bookkeeping
    static let hasCompletedOnboarding = "fan.hasCompletedOnboarding"
    /// Written on launch, cleared on a clean exit: a set flag at startup means the
    /// previous run died with fans possibly pinned (§6.7.5).
    static let runInProgress = "fan.runInProgress"
}

enum PollingInterval: Double, CaseIterable, Identifiable {
    case half = 0.5
    case one = 1.0
    case two = 2.0
    case five = 5.0

    var id: Double { rawValue }
    var displayName: String {
        rawValue < 1 ? "0.5 s" : "\(Int(rawValue)) s"
    }
}

/// Bounds for the safety thresholds, shared by the UI and the monitor.
enum SafetyBounds {
    static let thermalFloorRange: ClosedRange<Double> = 85...110
    static let defaultThermalFloor: Double = 95
    /// The floor releases once every hot sensor is this far below the threshold.
    static let thermalFloorHysteresis: Double = 10
    /// Never command below this, whatever the profile says (§6.7.1).
    static let absoluteMinimumRPM: Double = 500
    /// Published sensor sanity window.
    static let maximumPlausibleTemperature: Double = 110
}

enum FanAppSettings {

    /// Registers defaults so `UserDefaults` reads are correct before the Settings pane
    /// has ever been opened.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            FanSettingsKey.temperatureUnit: TemperatureUnit.celsius.rawValue,
            FanSettingsKey.pollingInterval: PollingInterval.one.rawValue,
            FanSettingsKey.restoreFansOnQuit: true,
            FanSettingsKey.allowUnsafeFanTargets: false,
            FanSettingsKey.minimumRPMDelta: 50.0,
            FanSettingsKey.thermalFloorEnabled: true,
            FanSettingsKey.thermalFloorCelsius: SafetyBounds.defaultThermalFloor,
            FanSettingsKey.thermalStateOverrideEnabled: true,
            FanSettingsKey.showUnknownSensors: true,
            FanSettingsKey.extendedHIDSensors: false,
            FanSettingsKey.helperHasWorkedBefore: false,
            FanSettingsKey.hasCompletedOnboarding: false,
            FanSettingsKey.runInProgress: false,
        ])
    }

    static func temperatureText(_ celsius: Double, unit: TemperatureUnit, precise: Bool) -> String {
        String(format: precise ? "%.1f %@" : "%.0f %@", unit.convert(celsius), unit.symbol)
    }

    static var temperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: FanSettingsKey.temperatureUnit) ?? "")
            ?? .celsius
    }

    static var pollingInterval: TimeInterval {
        let raw = UserDefaults.standard.double(forKey: FanSettingsKey.pollingInterval)
        return raw > 0 ? raw : 1.0
    }

    static var minimumRPMDelta: Double {
        let raw = UserDefaults.standard.double(forKey: FanSettingsKey.minimumRPMDelta)
        return raw > 0 ? raw : 50
    }

    static var thermalFloorCelsius: Double {
        let raw = UserDefaults.standard.double(forKey: FanSettingsKey.thermalFloorCelsius)
        return SafetyBounds.thermalFloorRange.contains(raw) ? raw : SafetyBounds.defaultThermalFloor
    }

    static var thermalFloorEnabled: Bool {
        UserDefaults.standard.bool(forKey: FanSettingsKey.thermalFloorEnabled)
    }

    static var thermalStateOverrideEnabled: Bool {
        UserDefaults.standard.bool(forKey: FanSettingsKey.thermalStateOverrideEnabled)
    }

    static var restoreFansOnQuit: Bool {
        UserDefaults.standard.bool(forKey: FanSettingsKey.restoreFansOnQuit)
    }

    static var allowUnsafeFanTargets: Bool {
        UserDefaults.standard.bool(forKey: FanSettingsKey.allowUnsafeFanTargets)
    }

    static var showUnknownSensors: Bool {
        UserDefaults.standard.bool(forKey: FanSettingsKey.showUnknownSensors)
    }

    /// True once the privileged daemon has answered this app at least once in the past.
    ///
    /// This is the app's only evidence that a *missing* registration is a registration that
    /// was lost — by replacing the app bundle, which invalidates the record — rather than a
    /// helper that was never installed. Registering a root daemon on a machine that never
    /// had one is not something the app may decide by itself, so the distinction matters:
    /// this flag is what makes the difference between repairing and presuming.
    static var helperHasWorkedBefore: Bool {
        UserDefaults.standard.bool(forKey: FanSettingsKey.helperHasWorkedBefore)
    }

    static func markHelperWorked() {
        UserDefaults.standard.set(true, forKey: FanSettingsKey.helperHasWorkedBefore)
    }

    /// An explicit uninstall must stay uninstalled.
    static func clearHelperHistory() {
        UserDefaults.standard.removeObject(forKey: FanSettingsKey.helperHasWorkedBefore)
    }


    // MARK: Dirty-exit bookkeeping

    static func markRunStarted() {
        UserDefaults.standard.set(true, forKey: FanSettingsKey.runInProgress)
    }

    static func markRunEndedCleanly() {
        UserDefaults.standard.set(false, forKey: FanSettingsKey.runInProgress)
    }

    /// True when the previous run did not exit cleanly.
    static var previousRunWasUnclean: Bool {
        UserDefaults.standard.bool(forKey: FanSettingsKey.runInProgress)
    }
}
