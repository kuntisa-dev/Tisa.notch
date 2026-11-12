//
//  FanSettingsView.swift
//  Tisa Fan Studio
//
//  PROMPT.md §6.6. General preferences, the helper install/uninstall flow, and the
//  expert section (collapsed by default) that holds the genuinely dangerous switches.
//

import SwiftUI
import SMCKit

struct FanSettingsView: View {
    @EnvironmentObject private var env: FanEnvironment
    @AppStorage(FanSettingsKey.temperatureUnit) private var temperatureUnitRaw = TemperatureUnit.celsius.rawValue
    @AppStorage(FanSettingsKey.pollingInterval) private var pollingInterval = PollingInterval.one.rawValue
    @AppStorage(FanSettingsKey.preciseTemperatures) private var preciseTemperatures = false
    @AppStorage(FanSettingsKey.minimumRPMDelta) private var minimumRPMDelta = 50.0
    @AppStorage(FanSettingsKey.thermalFloorCelsius) private var thermalFloorCelsius = SafetyBounds.defaultThermalFloor
    @AppStorage(FanSettingsKey.showUnknownSensors) private var showUnknownSensors = true

    @State private var isWorkingOnHelper = false
    @State private var helperMessage: String?

    var body: some View {
        TabView {
            general.tabItem { Label("General", systemImage: "gearshape") }
            fanControl.tabItem { Label("Fan Control", systemImage: "fan") }
            about.tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 460)
        .navigationTitle("Settings")
        .onChange(of: pollingInterval) { newValue in
            deferToNextRunLoop { env.setPollingInterval(newValue) }
        }
    }

    // MARK: - General

    private var general: some View {
        Form {
            Section("Appearance") {
                Picker("Temperature unit", selection: $temperatureUnitRaw) {
                    Text("Celsius (°C)").tag(TemperatureUnit.celsius.rawValue)
                    Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit.rawValue)
                }
                Toggle("Show decimal temperatures", isOn: $preciseTemperatures)
            }

            Section("Polling") {
                Picker("Refresh interval", selection: $pollingInterval) {
                    ForEach(PollingInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval.rawValue)
                    }
                }
                Text("The full sensor sweep runs at launch and on demand; each tick refreshes the "
                     + "sensors a curve tracks plus every fan, which keeps idle CPU use around 1 %.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Sensors") {
                Toggle("Show sensors that are not in the catalog", isOn: $showUnknownSensors)
                Text("Unknown keys appear in the Sensors view under “Unknown” with their raw SMC key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Fan control

    private var fanControl: some View {
        Form {
            Section("Privileged helper") {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(env.helper.installationState.isUsable ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(env.helper.installationState.displayName)
                    }
                }
                LabeledContent("Details") {
                    Text(env.helperStatusSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Text("Enable fan control by installing the helper for this exact app build. Monitoring works without installation.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Copy install command") { copyHelperCommand("install") }
                    if env.helper.hasRegisteredDaemonPlist {
                        Button("Copy removal command") { copyHelperCommand("uninstall") }
                    }
                    Button("Reconnect") { reconnectHelper() }
                        .disabled(isWorkingOnHelper)
                    if isWorkingOnHelper { ProgressView().controlSize(.small) }
                }
                if let helperMessage {
                    Text(helperMessage).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Cooling safeguards") {
                Text("Fan targets stay within the firmware's reported range. The helper returns control to macOS when it loses contact with the app, and the app restores Automatic on quit.")
                    .font(.callout)
                LabeledContent("Maximum temperature", value: "95 °C")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About

    private var about: some View {
        Form {
            Section("Tisa Fan Studio") {
                LabeledContent("Version") {
                    Text("\(Bundle.main.shortVersion) (\(Bundle.main.buildVersion))")
                }
                LabeledContent("Helper") {
                    Text(HelperConstants.helperVersion)
                }
                LabeledContent("Hardware") {
                    Text("\(env.platform.modelIdentifier) · \(env.platform.chipName)")
                }
                LabeledContent("Unlock style") {
                    Text(env.fans.snapshot.unlockStyle.rawValue)
                }
                LabeledContent("Source") {
                    Button {
                        _ = NSWorkspace.shared.open(FanStudioLinks.repository)
                    } label: {
                        Label("AutoFansMac on GitHub", systemImage: "arrow.up.right.square")
                    }
                    .help("Open \(FanStudioLinks.repository.absoluteString) in the browser")
                }
            }

            Section("Privacy") {
                Text("Monitoring and fan control work locally. Diagnostics are saved only when you export them.")
                    .font(.callout)
            }

            Section("Credits") {
                Text("Built on AutoFansMac by Gary Hooi and the Stats sensor catalog by Serhiy Mytrovtsiy (MIT).")
                    .font(.callout)
                Text("Fan-control behaviour is based on public reverse-engineering research "
                     + "(macos-smc-fan) and the documented AppleSMC interface.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Files") {
                LabeledContent("Profiles") {
                    Text(ProfileStore.profilesURL.path).font(.caption).textSelection(.enabled)
                }
                LabeledContent("Diagnostics") {
                    Button("Export Diagnostics…") { exportDiagnostics() }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions

    private func copyHelperCommand(_ action: String) {
        let command = HelperClient.terminalCommand(bundlePath: env.helper.bundlePath, action: action)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        helperMessage = "Command copied. Run it in Terminal, then click Reconnect."
    }

    private func reconnectHelper() {
        isWorkingOnHelper = true
        helperMessage = nil
        Task { @MainActor in
            await env.reconnectHelper()
            isWorkingOnHelper = false
            helperMessage = env.helper.installationState.isUsable
                ? "Connected: \(env.helperStatusSummary)"
                : "Still no daemon answering — \(env.helper.installationState.displayName)."
        }
    }

    private func exportDiagnostics() {
        Task { @MainActor in
            do {
                if let url = try await DiagnosticsArchive.export(from: env) {
                    env.log.info("diagnostics", "Exported \(url.lastPathComponent)")
                }
            } catch {
                env.log.failure("diagnostics", error.localizedDescription)
            }
        }
    }
}
