//
//  AIUsageCenter.swift
//  AIUsageKit
//
//  The public face of the engine for Tisa Dynamic Island: it starts the providers (on a
//  first run it turns on the tools that are signed in on this Mac, instead of showing a
//  welcome window), exposes a small summary per provider for the notch, and hands out the
//  full dashboard view for the AI Usage window.
//

import AppKit
import Observation
import SwiftUI

/// One row for the notch: a limit window (session, weekly…), a spend figure or a status.
public struct AIUsageMeter: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    /// How much of the limit is used, 0…1. Nil for plain values such as spend.
    public let fraction: Double?
    public let valueText: String
    /// What's left of the limit: "16%", "$4.20" or "120 requests". Same as `valueText` for plain values.
    public let leftText: String
    public let resetsAt: Date?

    /// How much of the limit is left, 0…1: the other side of `fraction`.
    public var leftFraction: Double? { fraction.map { 1 - $0 } }
}

public struct AIUsageProvider: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let plan: String?
    public let meters: [AIUsageMeter]
    public let error: String?
    public let refreshedAt: Date?

    /// The limit closest to running out, for compact displays.
    public var tightestMeter: AIUsageMeter? {
        meters.filter { $0.fraction != nil }.max { ($0.fraction ?? 0) < ($1.fraction ?? 0) }
    }
}

@MainActor
@Observable
public final class AIUsageCenter {
    public static let shared = AIUsageCenter()

    public private(set) var isReady = false
    private var container: AppContainer?
    private var starting = false
    private let updater = UpdaterController()

    private init() {}

    public func start() {
        guard !starting else { return }
        starting = true
        AppLog.bootstrap()
        let isFresh = SettingsMigrator.isFreshInstall()
        SettingsMigrator.migrate()
        Task {
            if !LoginShellEnvironment.shared.capturedSuccessfully {
                await Task.detached(priority: .userInitiated) {
                    _ = LoginShellEnvironment.shared.ensureCaptured()
                }.value
            }
            let container = await AppContainer(isFreshInstall: isFresh)
            if isFresh {
                // No welcome window inside the notch: turn on the tools signed in on this Mac.
                let detected = await FirstRunSeeder.detectLocalProviders(container.providers)
                container.enablement.seedEnabledProviders(detected)
                container.onboarding.dismissCustomizeHint()
                AppLog.info(.config, "first run inside Tisa Dynamic Island: enabled \(detected.sorted())")
            }
            container.startRefreshing()
            self.container = container
            self.isReady = true
        }
    }

    /// Enabled providers in the user's order, with what the notch shows for each.
    public var providers: [AIUsageProvider] {
        guard let container else { return [] }
        let ids = container.layout.orderedProviderIDs().filter { container.enablement.isEnabled($0) }
        return ids.compactMap { id in
            let snapshot = container.dataStore.snapshots[id]
            let name = snapshot?.displayName
                ?? container.registry.providers.first { $0.id == id }?.displayName
                ?? id
            let meters = (snapshot?.lines ?? []).enumerated().compactMap { index, line in
                Self.meter(for: line, id: "\(id).\(index)")
            }
            return AIUsageProvider(
                id: id,
                name: name,
                plan: snapshot?.plan,
                meters: meters,
                error: container.dataStore.providerErrors[id],
                refreshedAt: snapshot?.refreshedAt
            )
        }
    }

    /// The provider's monochrome mark.
    public func icon(for providerID: String) -> some View {
        ProviderIcon(source: .providerMark(providerID))
    }

    /// The full dashboard (cards, customize, settings), for a window.
    public func dashboardView() -> AnyView {
        guard let container else {
            return AnyView(ProgressView().controlSize(.small).frame(width: 320, height: 200))
        }
        return AnyView(
            DashboardView()
                .reduceAnimationsWhenRequested()
                .environment(container)
                .environment(container.layout)
                .environment(container.dataStore)
                .environment(container.transparency)
                .environment(updater)
                .environment(\.resetClaims, container.resetClaims)
                .defaultAppStorage(.aiUsage)
        )
    }

    // MARK: - Summaries

    private static func meter(for line: MetricLine, id: String) -> AIUsageMeter? {
        switch line {
        case let .progress(label, used, limit, format, resetsAt, _, _):
            let fraction = limit > 0 ? min(1, max(0, used / limit)) : nil
            let text: String
            let left: String
            switch format {
            case .percent:
                text = "\(Int(((fraction ?? 0) * 100).rounded()))%"
                left = "\(Int(((1 - (fraction ?? 0)) * 100).rounded()))%"
            case .dollars:
                text = "\(money(used)) of \(money(limit))"
                left = money(max(0, limit - used))
            case .count(let suffix):
                text = "\(Int(used)) of \(Int(limit))\(suffix.isEmpty ? "" : " \(suffix)")"
                left = "\(Int(max(0, limit - used)))\(suffix.isEmpty ? "" : " \(suffix)")"
            }
            return AIUsageMeter(id: id, label: label, fraction: fraction, valueText: text, leftText: left, resetsAt: resetsAt)
        case let .values(label, values, _, _, _, _):
            guard let first = values.first else { return nil }
            let text: String
            switch first.kind {
            case .dollars: text = money(first.number)
            case .percent: text = "\(Int(first.number.rounded()))%"
            default: text = first.number.formatted(.number.notation(.compactName))
            }
            return AIUsageMeter(id: id, label: label, fraction: nil, valueText: text, leftText: text, resetsAt: nil)
        case let .text(label, value, _, _), let .badge(label, value, _, _):
            return AIUsageMeter(id: id, label: label, fraction: nil, valueText: value, leftText: value, resetsAt: nil)
        case .chart:
            return nil
        }
    }

    private static func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(value >= 100 ? 0 : 2)))
    }
}
