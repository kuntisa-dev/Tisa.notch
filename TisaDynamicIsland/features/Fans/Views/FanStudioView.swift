//
//  FanStudioView.swift
//  Tisa Fan Studio
//
//  The main window: a sidebar of sections and the selected detail view.
//  Deliberately plain — the app is a menu-bar utility, so the window is a monitoring
//  and configuration surface rather than a dashboard (PROMPT.md §6.1-§6.6).
//

import SwiftUI
import SMCKit

struct FanStudioView: View {
    @EnvironmentObject private var env: FanEnvironment

    var body: some View {
        NavigationSplitView {
            // The selection write is deferred out of the List's update. Binding it straight
            // to `$env.selection` publishes `FanEnvironment` mid-update, which is the
            // "Publishing changes from within view updates" warning seen when switching
            // pages — and the undefined behaviour that comes with it.
            List(FanEnvironment.SidebarItem.allCases, selection: Binding(
                get: { env.selection },
                set: { newValue in deferToNextRunLoop { env.selection = newValue } }
            )) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 220)
            .safeAreaInset(edge: .bottom) {
                helperFooter
            }
        } detail: {
            detail
                .frame(minWidth: 780, minHeight: 460)
        }
        .overlay(alignment: .top) {
            if let banner = env.banner {
                FanBannerView(banner: banner)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch env.selection {
        case .fans:
            ThermalOverview()
        case .sensors:
            SensorsView()
        case .profiles:
            ProfilesView()
        case .settings:
            FanSettingsView()
        case .diagnostics:
            DiagnosticsView()
        }
    }

    private var helperFooter: some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider()
            HStack(spacing: 6) {
                Circle()
                    .fill(env.helper.installationState.isUsable ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(env.helper.installationState.isUsable ? "Fan control ready" : "Monitoring only")
                    .font(.caption)
                Spacer()
            }
            Text(env.helperStatusSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }
}

/// The overview keeps fan controls and the temperature table visible together.
struct ThermalOverview: View {
    @EnvironmentObject private var env: FanEnvironment
    @AppStorage(FanSettingsKey.temperatureUnit) private var unit = TemperatureUnit.celsius.rawValue
    @AppStorage(FanSettingsKey.preciseTemperatures) private var preciseTemperatures = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "fan.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.teal)
                    .frame(width: 46, height: 46)
                    .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tisa Fan Studio").font(.system(size: 23, weight: .semibold))
                    Text("Live cooling and temperature monitor")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(env.platform.chipName).font(.callout.weight(.semibold))
                    Text(env.platform.modelIdentifier).font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            Divider()

            HStack(spacing: 0) {
                FansView()
                    .frame(minWidth: 430, idealWidth: 520, maxWidth: .infinity)

                Divider()

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label("Temperatures", systemImage: "thermometer.medium")
                            .font(.headline)
                        Spacer()
                        Button("All sensors") { env.selection = .sensors }
                            .buttonStyle(.link)
                    }
                    .padding(14)

                    Divider()

                    if temperatures.isEmpty {
                        Text(env.sensors.isScanning ? "Scanning sensors…" : "No temperature readings available.")
                            .foregroundStyle(.secondary)
                            .padding()
                        Spacer()
                    } else {
                        Table(temperatures) {
                            TableColumn("Sensor", value: \.name)
                            TableColumn("Value") { sample in
                                Text(FanAppSettings.temperatureText(sample.rawValue, unit: temperatureUnit, precise: preciseTemperatures))
                                    .monospacedDigit()
                            }
                            .width(min: 58, ideal: 69)
                        }
                    }
                }
                .frame(minWidth: 310, idealWidth: 345, maxWidth: 390)
            }
        }
        .navigationTitle("Cooling Overview")
    }

    private var temperatures: [SensorSample] {
        env.sensors.temperatureSamples
            .filter { $0.isKnown || $0.isComputed }
            .sorted {
                if $0.isComputed != $1.isComputed { return $0.isComputed }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private var temperatureUnit: TemperatureUnit { TemperatureUnit(rawValue: unit) ?? .celsius }
}

/// A transient message bar (helper missing, thermal override, profile adapted…).
struct FanBannerView: View {
    @EnvironmentObject private var env: FanEnvironment
    let banner: FanEnvironment.Banner

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title).font(.headline)
                Text(banner.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let actionTitle = banner.actionTitle, let action = banner.action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
            Button {
                env.banner = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.35)))
        .shadow(radius: 6, y: 2)
        .frame(maxWidth: 620)
    }

    private var symbol: String {
        switch banner.kind {
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var tint: Color {
        switch banner.kind {
        case .warning: return .orange
        case .error: return .red
        case .info: return .accentColor
        }
    }
}
