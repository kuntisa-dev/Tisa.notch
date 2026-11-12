//
//  FanStudio.swift
//  TisaDynamicIsland
//
//  Tisa Fan Studio inside Tisa Dynamic Island. The engine (FanEnvironment: sensor
//  polling, fan curves, the safety monitor and the privileged helper) starts with
//  the app; the notch shows temperatures and quick modes, and the full Fan Studio
//  window holds curves, profiles, sensors, settings and diagnostics.
//
//  Fan Studio is MIT licensed (built on AutoFansMac by Gary Hooi and the Stats
//  sensor table by Serhiy Mytrovtsiy); see Packages/SMCKit/LICENSE and LICENSES.md.
//

import AppKit
import SMCKit
import SwiftUI

@MainActor
final class FanStudio: NSObject, NSWindowDelegate {
    static let shared = FanStudio()

    let environment = FanEnvironment()
    private var window: NSWindow?
    private var started = false
    private var stopping = false

    private override init() {}

    /// Starts reading sensors and re-applies the active profile, like the standalone app at launch.
    func start() {
        guard !started else { return }
        started = true
        Task { await environment.start() }
    }

    /// Hands the fans back to macOS before the app quits. `done` is called once, within 5 s.
    func stop(then done: @escaping () -> Void) {
        guard started, !stopping else { return done() }
        stopping = true
        var finished = false
        let finish = {
            guard !finished else { return }
            finished = true
            done()
        }
        Task { @MainActor in
            await environment.shutdown()
            finish()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { finish() }
    }

    func showWindow(_ page: FanEnvironment.SidebarItem? = nil) {
        if let page { environment.selection = page }
        NSApp.setActivationPolicy(.regular)
        let window = self.window ?? makeWindow()
        self.window = window
        if window.isMiniaturized { window.deminiaturize(nil) }
        environment.setWatching("fan-studio", true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1130, height: 710),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tisa Fan Studio"
        window.contentViewController = NSHostingController(rootView: FanStudioRoot(environment: environment))
        window.contentMinSize = NSSize(width: 960, height: 540)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("TisaFanStudio")
        return window
    }

    func windowWillClose(_ notification: Notification) {
        // Let go of the window's views: a closed window that is kept around still redraws
        // on every sensor reading. It is rebuilt (at its saved frame) the next time it opens.
        environment.setWatching("fan-studio", false)
        let closing = window
        window = nil
        DispatchQueue.main.async { closing?.contentViewController = nil }
        // Back to a notch-only app, unless Settings is still open.
        if SettingsWindowController.shared.window?.isVisible != true {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

/// The standalone app's window content, with its first-run sheet.
private struct FanStudioRoot: View {
    @ObservedObject var environment: FanEnvironment

    var body: some View {
        FanStudioView()
            .environmentObject(environment)
            .frame(minWidth: 960, minHeight: 540)
            .sheet(isPresented: $environment.showOnboarding) {
                FanOnboardingView(onFinish: { environment.showOnboarding = false })
                    .environmentObject(environment)
            }
    }
}

// MARK: - Readings for the notch

extension FanEnvironment {
    /// The hottest CPU core, falling back to the hottest chip sensor (°C).
    var cpuTemperature: Double? {
        sensors.temperature(forKey: SensorScanner.ComputedKey.cpuHottest)
            ?? sensors.temperature(forKey: SensorScanner.ComputedKey.socHottest)
    }

    var gpuTemperature: Double? {
        sensors.temperature(forKey: SensorScanner.ComputedKey.gpuHottest)
    }

    var fastestFanRPM: Double? {
        fans.states.map(\.descriptor.currentRPM).max()
    }

    var canControlFans: Bool {
        helper.installationState.isUsable
    }

    /// The active profile, or that macOS is in charge while fan control isn't set up.
    var modeSummary: String {
        canControlFans ? profiles.activeProfileName : "macOS in control"
    }

    /// The two one-click modes in the notch.
    enum QuickMode: CaseIterable {
        case fullBlast, automatic

        var title: String {
            switch self {
            case .fullBlast: return "Full Blast"
            case .automatic: return "Automatic"
            }
        }

        var symbol: String {
            switch self {
            case .fullBlast: return "wind"
            case .automatic: return "arrow.triangle.2.circlepath"
            }
        }

        var help: String {
            switch self {
            case .fullBlast: return "Every fan at full speed"
            case .automatic: return "macOS decides the fan speed"
            }
        }
    }

    var quickMode: QuickMode? {
        switch profiles.activeProfile.id {
        case Profile.fullBlastID: return .fullBlast
        case Profile.automaticID: return .automatic
        default: return nil
        }
    }

    func apply(_ mode: QuickMode) async {
        switch mode {
        case .fullBlast: await setFullBlast()
        case .automatic: await setAutomatic()
        }
    }

    func temperatureText(_ celsius: Double?) -> String {
        guard let celsius else { return "—" }
        return FanAppSettings.temperatureText(celsius, unit: FanAppSettings.temperatureUnit, precise: false)
    }
}

enum FanHeat {
    /// Green when cool, amber when warm, red when hot.
    static func color(_ celsius: Double?) -> Color {
        guard let celsius else { return HomeStyle.secondary }
        if celsius >= 85 { return HomeStyle.alert }
        if celsius >= 70 { return HomeStyle.warning }
        return Color(red: 0.29, green: 0.87, blue: 0.5)
    }
}
