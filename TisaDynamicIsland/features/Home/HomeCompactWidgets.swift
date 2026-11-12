//
//  HomeCompactWidgets.swift
//  TisaDynamicIsland
//
//  The one-row versions of the Home widgets: Small (1×1) and Wide (2×1) tiles, half the
//  height of a full box, so two can stack in a column.
//

import AIUsageKit
import AppKit
import Defaults
import SwiftUI

struct CompactWidgetView: View {
    let box: HomeBox

    private var wide: Bool { box.size == .wide }

    var body: some View {
        Group {
            switch box.widget {
            case .nowPlaying: CompactNowPlaying(wide: wide)
            case .upNext: CompactUpNext()
            case .recentApps: CompactRecentApps()
            case .quick: CompactQuick(wide: wide)
            case .clipboard: CompactClipboard()
            case .downloads: CompactDownloads()
            case .battery: CompactBattery(wide: wide)
            case .fans: CompactFans(wide: wide)
            case .aiUsage: CompactAIUsage(wide: wide)
            case .dropZone: CompactDropZone(wide: wide)
            case .today, .mirror: CompactPlaceholder(widget: box.widget)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The card every compact tile sits on.
private struct CompactCard<Content: View>: View {
    var highlight: Color?
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .homeCard(highlight: highlight)
    }
}

/// A small label above a big value, the shape most compact tiles use.
private struct CompactReadout: View {
    let symbol: String
    let title: String
    let value: String
    var tint: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.system(size: 9.5, weight: .semibold))
                .lineLimit(1)
                .ink(HomeStyle.secondary, Ink.cool)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .ink(tint == .white ? Ink.title : tint)
        }
    }
}

// MARK: - Now playing

private struct CompactNowPlaying: View {
    let wide: Bool
    @ObservedObject private var music = MusicManager.shared

    var body: some View {
        CompactCard {
            HStack(spacing: 8) {
                Image(nsImage: music.albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onTapGesture { music.openMusicApp() }
                    .help("Open the music app")
                if wide {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(music.songTitle.isEmpty ? "Nothing playing" : music.songTitle)
                            .font(.system(size: 11.5, weight: .semibold))
                            .ink(Ink.title)
                        Text(music.artistName)
                            .font(.system(size: 10, weight: Ink.active ? .semibold : .regular))
                            .ink(HomeStyle.secondary, Ink.detail)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 2)
                }
                playButton
                if wide {
                    Button { music.nextTrack() } label: {
                        Image(systemName: "forward.fill").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Ink.control)
                    }
                    .buttonStyle(GlassPressStyle())
                    .help("Next")
                }
            }
        }
    }

    private var playButton: some View {
        Button { music.togglePlay() } label: {
            Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Ink.playIcon)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Ink.playFill))
        }
        .buttonStyle(GlassPressStyle())
        .help(music.isPlaying ? "Pause" : "Play")
    }
}

// MARK: - Up next

private struct CompactUpNext: View {
    @ObservedObject private var feed = TodayFeed.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let next = feed.upcoming.first { $0.end > context.date }
            let startsIn = next.map { $0.start.timeIntervalSince(context.date) } ?? 0
            let soon = next != nil && startsIn <= 5 * 60
            CompactCard(highlight: soon ? Color.effectiveAccent : nil) {
                if !feed.hasAccess {
                    CompactReadout(symbol: "calendar", title: "Up next", value: "Allow access")
                        .onTapGesture { feed.requestAccess() }
                } else if let next {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(startsIn <= 0 ? "NOW" : "IN \(UpNextBox.relative(startsIn).uppercased())")
                                .font(.system(size: 9.5, weight: .semibold))
                                .ink(Color.effectiveAccent, Ink.detail)
                            Text(next.title)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .ink(Ink.title)
                            Text(next.start.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 10))
                                .ink(HomeStyle.secondary, Ink.reset)
                        }
                        Spacer(minLength: 2)
                        if let url = next.meetingURL {
                            Button("Join") { NSWorkspace.shared.open(url) }
                                .buttonStyle(HomePillButtonStyle(prominent: soon))
                        }
                    }
                } else {
                    CompactReadout(symbol: "calendar", title: "Up next", value: "Nothing today")
                }
            }
        }
        .onAppear { feed.begin() }
        .onDisappear { feed.end() }
    }
}

// MARK: - Recent apps

private struct CompactRecentApps: View {
    @ObservedObject private var manager = RecentAppsManager.shared

    var body: some View {
        CompactCard {
            GeometryReader { geometry in
                let count = max(2, Int(geometry.size.width / 40))
                HStack(spacing: 0) {
                    ForEach(manager.apps(limit: count)) { app in
                        AppIconButton(app: app, iconSize: 30)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Quick

private struct CompactQuick: View {
    let wide: Bool
    @Default(.homeQuickTiles) private var tiles

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tiles.prefix(wide ? 4 : 2)) { tile in
                QuickTileButton(tile: tile, compact: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Clipboard

private struct CompactClipboard: View {
    @ObservedObject private var clipboard = ClipboardHistoryManager.shared
    @State private var copied = false

    var body: some View {
        CompactCard {
            if let entry = clipboard.entries.first, Defaults[.enableClipboardHistory] {
                Button {
                    clipboard.copy(entry)
                    copied = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.2))
                        copied = false
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(copied ? "Copied" : "Last copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(HomeStyle.secondary)
                        Text(entry.previewText)
                            .font(.system(size: 11.5))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .inkPlate()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Copy it again")
            } else {
                CompactReadout(symbol: "doc.on.doc", title: "Recent copies", value: "—")
            }
        }
    }
}

// MARK: - Downloads

private struct CompactDownloads: View {
    @ObservedObject private var downloads = DownloadMonitor.shared
    @ObservedObject private var feed = DownloadsFolderFeed.shared

    var body: some View {
        CompactCard {
            if let active = downloads.downloads.first {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Downloading", systemImage: "arrow.down.circle")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Color.effectiveAccent)
                    Text(active.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                        .ink(Ink.title)
                    if let progress = active.progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .controlSize(.mini)
                            .tint(Color.effectiveAccent)
                    }
                }
            } else if let file = feed.files.first {
                Button {
                    NSWorkspace.shared.open(file.url)
                } label: {
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                            .resizable()
                            .frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(file.name)
                                .font(.system(size: 11.5, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .ink(Ink.title)
                            Text(file.added.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))
                                .font(.system(size: 9.5))
                                .ink(HomeStyle.secondary, Ink.reset)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onDrag { NSItemProvider(contentsOf: file.url) ?? NSItemProvider() }
                .help("Open \(file.name)")
            } else {
                CompactReadout(symbol: "arrow.down.circle", title: "Downloads", value: "None yet")
            }
        }
    }
}

// MARK: - Battery

private struct CompactBattery: View {
    let wide: Bool
    @ObservedObject private var battery = BatteryStatusViewModel.shared

    var body: some View {
        let low = battery.levelBattery <= 20 && !battery.isCharging
        let tint: Color = low ? HomeStyle.alert : battery.isCharging ? Color(red: 0.29, green: 0.87, blue: 0.5) : .white
        CompactCard {
            HStack(spacing: 8) {
                CompactReadout(symbol: battery.isCharging ? "bolt.fill" : "battery.75percent",
                               title: "Battery", value: "\(Int(battery.levelBattery))%", tint: tint)
                if wide {
                    Spacer(minLength: 2)
                    Text(battery.isCharging ? "Charging" : battery.isPluggedIn ? "Plugged in" : "On battery")
                        .font(.system(size: 10.5))
                        .ink(HomeStyle.secondary, Ink.detail)
                }
            }
        }
    }
}

// MARK: - Fans

private struct CompactFans: View {
    let wide: Bool
    @ObservedObject private var env = FanStudio.shared.environment
    @ObservedObject private var coordinator = TisaViewCoordinator.shared

    var body: some View {
        CompactCard(highlight: (env.cpuTemperature ?? 0) >= 85 ? HomeStyle.alert : nil) {
            HStack(spacing: 8) {
                CompactReadout(symbol: "fan", title: "CPU",
                               value: env.temperatureText(env.cpuTemperature), tint: FanHeat.color(env.cpuTemperature))
                Spacer(minLength: 2)
                if wide {
                    VStack(alignment: .trailing, spacing: 4) {
                        if let rpm = env.fastestFanRPM {
                            Text("\(Int(rpm.rounded())) rpm")
                                .font(.system(size: 10.5, weight: .medium))
                                .monospacedDigit()
                                .ink(HomeStyle.secondary, Ink.cool)
                        }
                        FanModeControl(style: .pills)
                    }
                } else {
                    FanModeControl(style: .toggle)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.smooth) { coordinator.currentView = .fans } }
    }
}

// MARK: - AI usage

private struct CompactAIUsage: View {
    let wide: Bool
    private let center = AIUsageCenter.shared
    @ObservedObject private var coordinator = TisaViewCoordinator.shared

    var body: some View {
        CompactCard {
            let providers = center.providers.filter { $0.tightestMeter != nil }
            if providers.isEmpty {
                CompactReadout(symbol: "sparkles", title: "AI Usage", value: center.isReady ? "—" : "…")
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(providers.prefix(wide ? 2 : 1)) { provider in
                        row(provider)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.smooth) { coordinator.currentView = .aiUsage } }
        .onAppear { center.start() }
    }

    /// Name, when the 5-hour limit resets, and how much of it is left. When space runs out it
    /// drops the word "left", then the reset time, rather than cutting either short.
    private func row(_ provider: AIUsageProvider) -> some View {
        let meter = provider.mainMeter
        return VStack(alignment: .leading, spacing: 3) {
            ViewThatFits(in: .horizontal) {
                line(provider, meter, reset: true, leftWord: true)
                line(provider, meter, reset: true, leftWord: false)
                line(provider, meter, reset: false, leftWord: false)
            }
            if let fraction = meter?.fraction {
                AIUsageBar(used: fraction)
            }
        }
    }
}

// MARK: - Drop zone

extension CompactAIUsage {
    fileprivate func line(_ provider: AIUsageProvider, _ meter: AIUsageMeter?, reset: Bool, leftWord: Bool) -> some View {
        HStack(spacing: 4) {
            AIProviderBadge(provider: provider, size: 11)
            Text(provider.name)
                .font(.system(size: 10.5, weight: .semibold))
                .lineLimit(1)
                .ink(Ink.provider(provider.name))
            Spacer(minLength: 2)
            if reset, let text = AIUsageStyle.resetShort(meter?.resetsAt) {
                Label(text, systemImage: "arrow.clockwise")
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .fixedSize()
                    .ink(HomeStyle.secondary, Ink.reset)
                    .help(AIUsageStyle.resetText(meter?.resetsAt) ?? "")
            }
            Text(meter.map { $0.fraction == nil || !leftWord ? $0.leftText : "\($0.leftText) left" } ?? "—")
                .font(.system(size: 10.5, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .ink(Ink.title)
        }
    }
}

private struct CompactDropZone: View {
    let wide: Bool
    @ObservedObject private var coordinator = TisaViewCoordinator.shared
    @ObservedObject private var shelf = ShelfStateViewModel.shared

    var body: some View {
        Button {
            withAnimation(.smooth) { coordinator.currentView = .shelf }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down").font(.system(size: 15))
                if wide {
                    Text(shelf.isEmpty ? "Drop files here" : "\(shelf.items.count) on the Shelf")
                        .font(.system(size: 11, weight: .medium))
                        .ink(Ink.title)
                }
            }
            .foregroundStyle(HomeStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: HomeMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Drop files on the notch to put them on the Shelf. Click to open it")
    }
}

/// Today and Mirror have no one-row size; shown only if an old layout asks for one.
private struct CompactPlaceholder: View {
    let widget: HomeWidget

    var body: some View {
        CompactCard {
            CompactReadout(symbol: widget.symbol, title: widget.title, value: "Make bigger")
        }
    }
}
