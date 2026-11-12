//
//  AIUsageNotch.swift
//  TisaDynamicIsland
//
//  AI Usage in the notch: how much of your Claude, Codex, Cursor… limits you've used.
//  The engine (Packages/AIUsageKit) is adapted from OpenUsage by Robin Ebers (MIT); it
//  reads the logins those tools already keep on this Mac and asks each provider for usage.
//  Nothing else leaves the Mac: the original's analytics and crash reports are removed.
//

import AIUsageKit
import AppKit
import Defaults
import SwiftUI

@MainActor
final class AIUsageWindow: NSObject, NSWindowDelegate {
    static let shared = AIUsageWindow()

    private var window: NSWindow?

    func show() {
        AIUsageCenter.shared.start()
        NSApp.setActivationPolicy(.regular)
        let window = self.window ?? makeWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AI Usage"
        window.contentViewController = NSHostingController(rootView: AIUsageWindowContent())
        window.contentMinSize = NSSize(width: 340, height: 420)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("AIUsage")
        return window
    }

    func windowWillClose(_ notification: Notification) {
        if SettingsWindowController.shared.window?.isVisible != true {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

/// Swaps the spinner for the dashboard once the engine is ready.
private struct AIUsageWindowContent: View {
    private let center = AIUsageCenter.shared

    var body: some View {
        if center.isReady {
            center.dashboardView()
        } else {
            ProgressView("Looking for your AI tools…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

enum AIUsageStyle {
    /// Accent when there's room, amber past 75 %, red past 90 %.
    static func tint(_ fraction: Double?) -> Color {
        guard let fraction else { return Color.effectiveAccent }
        if fraction >= 0.9 { return HomeStyle.alert }
        if fraction >= 0.75 { return HomeStyle.warning }
        return Color.effectiveAccent
    }

    /// "2h 14m", "45m", "3d 4h": time left until a limit resets, short enough for a tile.
    static func resetShort(_ date: Date?, now: Date = .now) -> String? {
        guard let date, date > now else { return nil }
        let minutes = Int((date.timeIntervalSince(now) / 60).rounded(.up))
        let days = minutes / 1440, hours = minutes / 60 % 24, rest = minutes % 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return rest > 0 ? "\(hours)h \(rest)m" : "\(hours)h" }
        return "\(rest)m"
    }

    static func resetText(_ date: Date?) -> String? {
        guard let date, date > .now else { return nil }
        return "Resets " + date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}

// MARK: - AI tab

struct AIUsageTabView: View {
    private let center = AIUsageCenter.shared

    var body: some View {
        Group {
            if !center.isReady {
                ProgressView("Looking for your AI tools…")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .homeCard()
            } else if center.providers.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(center.providers) { provider in
                            AIProviderCard(provider: provider)
                                .frame(width: 214)
                        }
                        openCard
                    }
                }
            }
        }
        .padding(.top, 2)
        .onAppear { center.start() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 22))
                .foregroundStyle(Color.effectiveAccent)
            Text("No AI tools found on this Mac")
                .font(.system(size: 13, weight: .semibold))
            Text("Sign in to Claude Code, Codex, Cursor or another supported tool, or turn providers on in AI Usage › Customize.")
                .font(.system(size: 11))
                .foregroundStyle(HomeStyle.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Open AI Usage") { AIUsageWindow.shared.show() }
                .buttonStyle(HomePillButtonStyle(prominent: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .homeCard()
    }

    private var openCard: some View {
        Button {
            AIUsageWindow.shared.show()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 18, weight: .semibold))
                Text("Details,\nspend and settings")
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Color(white: 0.85))
            .frame(width: 110)
            .frame(maxHeight: .infinity)
            .homeCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressStyle())
    }
}

/// One provider: its mark, name and plan, then each limit as a bar.
private struct AIProviderCard: View {
    let provider: AIUsageProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                AIProviderBadge(provider: provider, size: 16)
                Text(provider.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .ink(Ink.provider(provider.name))
                Spacer(minLength: 4)
                if let plan = provider.plan {
                    Text(plan)
                        .font(.system(size: 9.5, weight: .medium))
                        .lineLimit(1)
                        .ink(HomeStyle.secondary, Ink.detail)
                }
            }
            if let error = provider.error, provider.meters.isEmpty {
                Text(error)
                    .font(.system(size: 10.5))
                    .foregroundStyle(HomeStyle.warning)
                    .lineLimit(4)
                Spacer(minLength: 0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(provider.meters.prefix(5)) { meter in
                            AIMeterRow(meter: meter)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .homeCard()
    }
}

private struct AIMeterRow: View {
    let meter: AIUsageMeter

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(meter.label)
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
                    .ink(Color(white: 0.85), Ink.cool)
                Spacer(minLength: 4)
                Text(meter.fraction == nil ? meter.leftText : "\(meter.leftText) left")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .ink(Ink.title)
            }
            if let fraction = meter.fraction {
                AIUsageBar(used: fraction)
                if let reset = AIUsageStyle.resetText(meter.resetsAt) {
                    Text(reset)
                        .font(.system(size: 9))
                        .ink(HomeStyle.tertiary, Ink.reset)
                }
            }
        }
    }
}

/// A provider's mark. Over the picture themes it sits on a small square in the tool's own
/// color (Claude orange, Codex green…), so it shows on a bright picture; elsewhere it's the plain mark.
struct AIProviderBadge: View {
    let provider: AIUsageProvider
    var size: CGFloat = 12
    @Default(.notchTheme) private var theme

    var body: some View {
        if theme.usesPicture {
            AIUsageCenter.shared.icon(for: provider.id)
                .frame(width: size * 0.78, height: size * 0.78)
                .foregroundStyle(.white)
                .frame(width: size + 4, height: size + 4)
                .background(
                    RoundedRectangle(cornerRadius: (size + 4) * 0.3, style: .continuous)
                        .fill(Ink.provider(provider.name).mix(with: .black, by: 0.15))
                )
                .shadow(color: Ink.provider(provider.name).opacity(0.55), radius: 4)
        } else {
            AIUsageCenter.shared.icon(for: provider.id)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Home box

struct AIUsageBox: View {
    let size: HomeBoxSize
    private let center = AIUsageCenter.shared
    @ObservedObject private var coordinator = TisaViewCoordinator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeLabel(title: "AI Usage", trailing: "Left · resets in")
            if !center.isReady {
                Spacer(minLength: 0)
                ProgressView().controlSize(.small).frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else if center.providers.isEmpty {
                Spacer(minLength: 0)
                Text("No AI tools found")
                    .font(.system(size: 11))
                    .foregroundStyle(HomeStyle.secondary)
                Spacer(minLength: 0)
            } else {
                // Refresh the "resets in" times every minute.
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    ViewThatFits(in: .vertical) {
                        providers(3, now: context.date)
                        providers(2, now: context.date)
                        providers(1, now: context.date)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .homeCard()
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.smooth) { coordinator.currentView = .aiUsage }
        }
        .onAppear { center.start() }
    }

    private func providers(_ count: Int, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(center.providers.prefix(count)) { provider in
                section(provider, now: now)
            }
        }
    }

    /// The provider's name, then its 5-hour and weekly limits with when each resets.
    /// Providers without those show their tightest limit instead.
    private func section(_ provider: AIUsageProvider, now: Date) -> some View {
        let windows = [provider.sessionMeter.map { ("5-hour", $0) }, provider.weeklyMeter.map { ("Weekly", $0) }]
            .compactMap { $0 }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                AIProviderBadge(provider: provider, size: 12)
                Text(provider.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .ink(Ink.provider(provider.name))
                Spacer(minLength: 4)
                if windows.isEmpty, provider.tightestMeter == nil {
                    Text(provider.error == nil ? "—" : "!")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(provider.error == nil ? .white : HomeStyle.warning)
                }
            }
            if windows.isEmpty, let meter = provider.tightestMeter {
                meterRow(meter.label, meter, now: now)
            } else {
                ForEach(windows, id: \.0) { name, meter in
                    meterRow(name, meter, now: now)
                }
            }
        }
    }

    private func meterRow(_ name: String, _ meter: AIUsageMeter, now: Date) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 9.5, weight: .medium))
                .lineLimit(1)
                .inkColor(HomeStyle.secondary, Ink.cool)
                .frame(width: 40, alignment: .leading)
                .ink(Ink.cool)
            AIUsageBar(used: meter.fraction ?? 0)
            Text(meter.leftText)
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .frame(minWidth: 30, alignment: .trailing)
                .ink(Ink.title)
            Label(AIUsageStyle.resetShort(meter.resetsAt, now: now) ?? "—", systemImage: "arrow.clockwise")
                .font(.system(size: 9.5))
                .monospacedDigit()
                .lineLimit(1)
                .inkColor(HomeStyle.secondary, Ink.reset)
                .frame(width: 58, alignment: .leading)
                .ink(Ink.reset)
                .help(AIUsageStyle.resetText(meter.resetsAt) ?? "No reset time")
        }
    }
}

/// A thin bar of what's left: full after a reset, emptying as you use it, and turning
/// amber then red as it runs low.
struct AIUsageBar: View {
    /// How much is used, 0…1.
    let used: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(AIUsageStyle.tint(used))
                    .frame(width: max(3, geometry.size.width * (1 - used)))
            }
        }
        .frame(height: 4)
    }
}

extension AIUsageProvider {
    /// The five-hour window Claude and Codex call a session.
    var sessionMeter: AIUsageMeter? {
        meters.first { $0.fraction != nil && $0.label.localizedCaseInsensitiveContains("session") }
    }

    var weeklyMeter: AIUsageMeter? {
        meters.first { $0.fraction != nil && $0.label.localizedCaseInsensitiveContains("week") }
    }

    /// The one limit small tiles show: the 5-hour window, else whichever is closest to running out.
    var mainMeter: AIUsageMeter? { sessionMeter ?? tightestMeter }
}
