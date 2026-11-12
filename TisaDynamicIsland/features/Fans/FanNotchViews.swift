//
//  FanNotchViews.swift
//  TisaDynamicIsland
//
//  The Fans tab and the Fans box for Home: temperatures, fan speeds and one-click
//  profiles (Automatic, Full Blast and your own). Curves and everything else live in
//  the Fan Studio window.
//

import SMCKit
import SwiftUI

// MARK: - Fans tab

struct FansTabView: View {
    @ObservedObject private var env = FanStudio.shared.environment

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            temperatures
                .frame(width: 170)
            fanList
                .frame(maxWidth: .infinity)
            profiles
                .frame(width: 200)
        }
        .padding(.top, 2)
    }

    private var temperatures: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeLabel(title: "Temperature", trailing: nil)
            Spacer(minLength: 0)
            reading("CPU", env.cpuTemperature, big: true)
            reading("GPU", env.gpuTemperature, big: false)
            Spacer(minLength: 0)
            Button {
                FanStudio.shared.showWindow(.sensors)
            } label: {
                Label("All sensors", systemImage: "thermometer.medium")
            }
            .buttonStyle(HomePillButtonStyle(prominent: false))
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .homeCard()
    }

    private func reading(_ title: String, _ celsius: Double?, big: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(env.temperatureText(celsius))
                .font(.system(size: big ? 28 : 18, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(FanHeat.color(celsius))
                .contentTransition(.numericText())
                .ink(FanHeat.color(celsius))
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .ink(HomeStyle.secondary, Ink.cool)
        }
    }

    private var fanList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeLabel(title: "Fans", trailing: env.fans.states.isEmpty ? nil : env.modeSummary)
            if env.fans.states.isEmpty {
                Text("This Mac has no fans to show.")
                    .font(.system(size: 11))
                    .foregroundStyle(HomeStyle.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(env.fans.states) { fan in
                            FanRow(fan: fan, controlled: env.canControlFans)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .homeCard()
    }

    private var profiles: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeLabel(title: "Mode", trailing: nil)
            HStack(spacing: 5) {
                ForEach(FanEnvironment.QuickMode.allCases, id: \.self) { mode in
                    QuickModeTile(mode: mode, env: env)
                }
            }
            .frame(maxHeight: .infinity)
            if env.canControlFans {
                Button {
                    FanStudio.shared.showWindow(.fans)
                } label: {
                    Label("Open Fan Studio", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(HomePillButtonStyle(prominent: false))
            } else {
                Button("Set up fan control") {
                    FanStudio.shared.showWindow(.settings)
                }
                .buttonStyle(HomePillButtonStyle(prominent: true))
                .help("The buttons work after a one-time admin setup in Fan Studio")
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .homeCard()
    }
}

/// Full Blast or Automatic as a big button. Dimmed until fan control is set up.
private struct QuickModeTile: View {
    let mode: FanEnvironment.QuickMode
    @ObservedObject var env: FanEnvironment

    var body: some View {
        let active = env.canControlFans && env.quickMode == mode
        Button {
            Task { await env.apply(mode) }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(mode.title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(active ? HomeStyle.onAccent : Color(white: 0.9))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(active ? Color.effectiveAccent : Color.white.opacity(0.08)))
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(GlassPressStyle())
        .disabled(!env.canControlFans)
        .opacity(env.canControlFans ? 1 : 0.4)
        .help(mode.help)
    }
}

/// One fan: name, speed, and where the speed sits between its minimum and maximum.
private struct FanRow: View {
    let fan: FanState
    /// Without the helper the app can't command the fans, so profile states don't apply.
    let controlled: Bool

    private var status: String { controlled ? fan.statusText : "Auto (macOS)" }
    private var isProblem: Bool { controlled && fan.statusIsProblem }

    var body: some View {
        let descriptor = fan.descriptor
        let span = max(1, descriptor.maxRPM - descriptor.minRPM)
        let share = min(1, max(0, (descriptor.currentRPM - descriptor.minRPM) / span))
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "fan")
                    .font(.system(size: 11))
                Text(fan.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .ink(Ink.cool)
                Spacer(minLength: 4)
                Text("\(Int(descriptor.currentRPM.rounded())) rpm")
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .ink(Ink.title)
            }
            ProgressView(value: share)
                .progressViewStyle(.linear)
                .tint(isProblem ? HomeStyle.alert : Color.effectiveAccent)
            HStack {
                Text(status)
                    .foregroundStyle(isProblem ? HomeStyle.alert : HomeStyle.secondary)
                Spacer(minLength: 4)
                Text("\(Int(descriptor.minRPM))–\(Int(descriptor.maxRPM))")
                    .foregroundStyle(HomeStyle.tertiary)
                    .monospacedDigit()
            }
            .font(.system(size: 9.5))
            .inkPlate()
            .lineLimit(1)
        }
    }
}

// MARK: - Home box

struct FansBox: View {
    let size: HomeBoxSize
    @ObservedObject private var env = FanStudio.shared.environment
    @ObservedObject private var coordinator = TisaViewCoordinator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeLabel(title: "Fans", trailing: size == .small ? nil : env.modeSummary)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(env.temperatureText(env.cpuTemperature))
                    .font(.system(size: 26, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(FanHeat.color(env.cpuTemperature))
                    .contentTransition(.numericText())
                    .ink(FanHeat.color(env.cpuTemperature))
                Text("CPU")
                    .font(.system(size: 10.5, weight: .medium))
                    .ink(HomeStyle.secondary, Ink.cool)
            }
            HStack(spacing: 10) {
                if let rpm = env.fastestFanRPM {
                    Label("\(Int(rpm.rounded())) rpm", systemImage: "fan")
                }
                if size != .small, env.gpuTemperature != nil {
                    Label(env.temperatureText(env.gpuTemperature), systemImage: "cpu")
                }
            }
            .font(.system(size: 10.5, weight: .medium))
            .ink(HomeStyle.secondary, Ink.cool)
            .monospacedDigit()
            .lineLimit(1)
            Spacer(minLength: 0)
            FanModeControl(style: .labels)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .homeCard(highlight: (env.cpuTemperature ?? 0) >= 85 ? HomeStyle.alert : nil)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.smooth) { coordinator.currentView = .fans }
        }
    }
}

/// Full Blast and Automatic on a Home tile, always there. Until fan control is set up
/// (a one-time admin step) they're dimmed, and pressing one opens that setup in Fan Studio.
struct FanModeControl: View {
    enum Style {
        /// One round button for a Small tile: shows the mode, a press switches to the other.
        case toggle
        /// Two small pills side by side, for a Wide tile.
        case pills
        /// Two buttons with their names side by side.
        case labels
        /// Two full-width buttons, one above the other, for a Portrait tile.
        case stacked
    }

    let style: Style
    @ObservedObject private var env = FanStudio.shared.environment

    private var ready: Bool { env.canControlFans }

    var body: some View {
        switch style {
        case .toggle:
            let mode: FanEnvironment.QuickMode = ready && env.quickMode == .fullBlast ? .fullBlast : .automatic
            Button {
                press(mode == .fullBlast ? .automatic : .fullBlast)
            } label: {
                Image(systemName: mode.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(mode == .fullBlast ? HomeStyle.onAccent : .white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(mode == .fullBlast ? Color.effectiveAccent : Color.white.opacity(0.14)))
            }
            .buttonStyle(GlassPressStyle())
            .opacity(ready ? 1 : 0.6)
            .help(ready
                ? "\(mode.title). Click for \(mode == .fullBlast ? "Automatic" : "Full Blast")"
                : setupHelp)
        case .pills:
            // Names when there's room, else just the icons (their names show on hover).
            ViewThatFits(in: .horizontal) {
                pills(named: true)
                pills(named: false)
            }
        case .labels:
            HStack(spacing: 5) {
                ForEach(FanEnvironment.QuickMode.allCases, id: \.self) { mode in
                    button(mode) {
                        Label(mode.title, systemImage: mode.symbol)
                            .lineLimit(1)
                    }
                }
            }
        case .stacked:
            VStack(spacing: 4) {
                ForEach(FanEnvironment.QuickMode.allCases, id: \.self) { mode in
                    button(mode) {
                        Label(mode.title, systemImage: mode.symbol)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func pills(named: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(FanEnvironment.QuickMode.allCases, id: \.self) { mode in
                button(mode) {
                    if named {
                        Label(mode == .fullBlast ? "Blast" : "Auto", systemImage: mode.symbol)
                            .fixedSize()
                    } else {
                        Image(systemName: mode.symbol)
                    }
                }
            }
        }
        .font(.system(size: 10, weight: .semibold))
    }

    private func button<Content: View>(_ mode: FanEnvironment.QuickMode, @ViewBuilder label: () -> Content) -> some View {
        Button {
            press(mode)
        } label: {
            label()
        }
        .buttonStyle(HomePillButtonStyle(prominent: ready && env.quickMode == mode))
        .opacity(ready ? 1 : 0.6)
        .help(ready ? mode.help : setupHelp)
    }

    private var setupHelp: String { "Fan control isn't set up yet. Click to set it up in Fan Studio" }

    private func press(_ mode: FanEnvironment.QuickMode) {
        guard ready else {
            FanStudio.shared.showWindow(.settings)
            return
        }
        HomeHaptics.tap()
        Task { await env.apply(mode) }
    }
}
