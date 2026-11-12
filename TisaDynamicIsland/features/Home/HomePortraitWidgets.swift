//
//  HomePortraitWidgets.swift
//  TisaDynamicIsland
//
//  The portrait versions of the Home widgets, for Tall (1×2) tiles: one column wide and
//  the full height of Home. Everything is stacked top to bottom: album art over the song,
//  a battery gauge standing up, events as a short list under the date.
//

import AIUsageKit
import AppKit
import Defaults
import SwiftUI

struct PortraitWidgetView: View {
    let box: HomeBox

    var body: some View {
        Group {
            switch box.widget {
            case .nowPlaying: PortraitNowPlaying()
            case .upNext: PortraitUpNext()
            case .today: PortraitToday()
            case .recentApps: PortraitRecentApps()
            case .quick: PortraitQuick()
            case .clipboard: PortraitClipboard()
            case .downloads: PortraitDownloads()
            case .battery: PortraitBattery()
            case .fans: PortraitFans()
            case .aiUsage: PortraitAIUsage()
            case .dropZone: DropZoneBox()
            case .mirror: MirrorBox()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The card every portrait tile sits on.
private struct PortraitCard<Content: View>: View {
    var highlight: Color?
    var alignment: HorizontalAlignment = .leading
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            content
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment == .center ? .top : .topLeading)
        .homeCard(highlight: highlight)
    }
}

/// The small colored caption at the top of a tile.
private struct PortraitCaption: View {
    let title: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 3) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(title.uppercased())
                .tracking(0.5)
        }
        .font(.system(size: 9, weight: .semibold))
        .lineLimit(1)
        .ink(Color.effectiveAccent, Ink.detail)
    }
}

// MARK: - Now playing

private struct PortraitNowPlaying: View {
    @ObservedObject private var music = MusicManager.shared

    var body: some View {
        if music.isPlayerIdle && !music.isPlaying {
            idle
        } else {
            playing
        }
    }

    /// Album art fills the top, the song sits under it, controls at the bottom.
    private var playing: some View {
        GeometryReader { geometry in
            let art = max(28, min(geometry.size.width, geometry.size.height - 76))
            VStack(spacing: 5) {
                Image(nsImage: music.albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: art, height: art)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .shadow(color: Color(nsColor: music.avgColor).opacity(0.5), radius: 8, y: 3)
                    .onTapGesture { music.openMusicApp() }
                    .help("Open the music app")
                VStack(spacing: 0) {
                    Text(music.songTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .ink(Ink.title)
                    Text(music.artistName)
                        .font(.system(size: 9.5, weight: Ink.active ? .semibold : .regular))
                        .ink(HomeStyle.secondary, Ink.detail)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                PortraitProgress()
                HStack(spacing: 0) {
                    control("backward.fill", help: "Previous") { music.previousTrack() }
                    Spacer(minLength: 0)
                    Button {
                        music.togglePlay()
                    } label: {
                        Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Ink.playIcon)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Ink.playFill))
                    }
                    .buttonStyle(GlassPressStyle())
                    .help(music.isPlaying ? "Pause" : "Play")
                    Spacer(minLength: 0)
                    control("forward.fill", help: "Next") { music.nextTrack() }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(8)
        .background(
            LinearGradient(colors: [Color(nsColor: music.avgColor).opacity(0.28), .clear],
                           startPoint: .top, endPoint: .bottom)
        )
        .homeCard()
    }

    private func control(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.control)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressStyle())
        .help(help)
    }

    private var idle: some View {
        PortraitCard(alignment: .center) {
            Spacer(minLength: 0)
            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .semibold))
                .inkColor(HomeStyle.secondary, Ink.detail)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.08)))
            Text("Nothing playing")
                .font(.system(size: 10.5, weight: .semibold))
                .multilineTextAlignment(.center)
            if music.bundleIdentifier != nil {
                Text(music.songTitle)
                    .font(.system(size: 9))
                    .ink(HomeStyle.secondary, Ink.detail)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                if music.bundleIdentifier != nil { music.togglePlay() } else { music.openMusicApp() }
            } label: {
                Label("Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(HomePillButtonStyle(prominent: true))
        }
    }
}

/// A thin playback bar without times, for narrow tiles.
private struct PortraitProgress: View {
    @ObservedObject private var music = MusicManager.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = max(music.songDuration, 0)
            let position = min(duration, music.estimatedPlaybackPosition(at: context.date))
            let fraction = duration > 0 ? position / duration : 0
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule().fill(Color.white)
                        .frame(width: max(3, geometry.size.width * fraction))
                }
            }
            .frame(height: 3)
        }
    }
}

// MARK: - Up next

private struct PortraitUpNext: View {
    @ObservedObject private var feed = TodayFeed.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(now: context.date)
        }
        .onAppear { feed.begin() }
        .onDisappear { feed.end() }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if !feed.hasAccess {
            PortraitCard {
                PortraitCaption(title: "Up next")
                Text("Show your next meeting here")
                    .font(.system(size: 10.5, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Allow") { feed.requestAccess() }
                    .buttonStyle(HomePillButtonStyle(prominent: true))
            }
        } else if let next = feed.upcoming.first(where: { $0.end > now }) {
            let startsIn = next.start.timeIntervalSince(now)
            let live = startsIn <= 0
            let soon = !live && startsIn <= 5 * 60
            PortraitCard(highlight: (soon || (live && next.meetingURL != nil)) ? Color.effectiveAccent : nil) {
                PortraitCaption(title: live ? "Now" : soon ? "Starts in" : "Up next")
                Text(soon ? UpNextBox.countdown(startsIn)
                     : live ? "until \(next.end.formatted(date: .omitted, time: .shortened))"
                     : next.start.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: live ? 12 : 19, weight: .bold))
                    .monospacedDigit()
                    .ink(Ink.reset)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !live && !soon {
                    Text(UpNextBox.relative(startsIn))
                        .font(.system(size: 9.5))
                        .ink(HomeStyle.secondary, Ink.detail)
                }
                Text(next.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(3)
                    .ink(Ink.title)
                    .padding(.top, 2)
                Spacer(minLength: 0)
                if let meeting = next.meetingURL {
                    Button {
                        NSWorkspace.shared.open(meeting)
                    } label: {
                        Label("Join", systemImage: "video.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HomePillButtonStyle(prominent: true))
                    .help(meeting.host ?? "Join the call")
                } else if let open = next.calendarAppURL() {
                    Button {
                        NSWorkspace.shared.open(open)
                    } label: {
                        Text("Open").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HomePillButtonStyle(prominent: soon || live))
                    .help("Open in Calendar")
                }
            }
        } else {
            PortraitCard(alignment: .center) {
                PortraitCaption(title: "Up next")
                Spacer(minLength: 0)
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 20))
                    .inkColor(HomeStyle.secondary, Ink.detail)
                Text("All clear")
                    .font(.system(size: 11, weight: .semibold))
                Text("Nothing else today")
                    .font(.system(size: 9.5))
                    .ink(HomeStyle.secondary, Ink.detail)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Today

private struct PortraitToday: View {
    @ObservedObject private var feed = TodayFeed.shared

    var body: some View {
        let now = Date()
        PortraitCard {
            Text(now.formatted(.dateTime.weekday(.wide)).uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .lineLimit(1)
                .ink(HomeStyle.alert, HomeStyle.alert)
            Text(now.formatted(.dateTime.day()))
                .font(.system(size: 28, weight: .bold))
                .monospacedDigit()
                .ink(Ink.title)
                .padding(.top, -4)
            if !feed.hasAccess {
                Spacer(minLength: 0)
                Button("Allow") { feed.requestAccess() }
                    .buttonStyle(HomePillButtonStyle(prominent: true))
            } else {
                let events = feed.today.filter { $0.end > now }
                if events.isEmpty {
                    Text("No more events")
                        .font(.system(size: 10))
                        .ink(HomeStyle.secondary, Ink.detail)
                } else {
                    // As many events as fit.
                    ViewThatFits(in: .vertical) {
                        eventList(events, count: 3)
                        eventList(events, count: 2)
                        eventList(events, count: 1)
                    }
                }
                Spacer(minLength: 0)
                if !feed.reminders.isEmpty {
                    Label("\(feed.reminders.count) to do", systemImage: "checklist")
                        .font(.system(size: 9.5, weight: .medium))
                        .ink(HomeStyle.secondary, Ink.detail)
                        .lineLimit(1)
                }
            }
        }
        .onAppear { feed.begin() }
        .onDisappear { feed.end() }
    }

    private func eventList(_ events: [EventModel], count: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(events.prefix(count), id: \.id) { event in
                Button {
                    if let url = event.calendarAppURL() { NSWorkspace.shared.open(url) }
                } label: {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(nsColor: event.calendar.color))
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(event.title)
                                .font(.system(size: 10, weight: .semibold))
                                .ink(Ink.title)
                            Text(event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 9))
                                .ink(HomeStyle.secondary, Ink.reset)
                                .monospacedDigit()
                        }
                        .lineLimit(1)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(event.title)
            }
        }
    }
}

// MARK: - Recent apps

private struct PortraitRecentApps: View {
    @ObservedObject private var manager = RecentAppsManager.shared

    var body: some View {
        GeometryReader { geometry in
            let rows = max(1, Int((geometry.size.height + 4) / 40))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)], spacing: 4) {
                ForEach(manager.apps(limit: rows * 2)) { app in
                    AppIconButton(app: app, iconSize: 30, showsName: false)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .padding(6)
        .homeCard()
    }
}

// MARK: - Quick

private struct PortraitQuick: View {
    @Default(.homeQuickTiles) private var tiles

    var body: some View {
        if tiles.isEmpty {
            PortraitCard(alignment: .center) {
                Spacer(minLength: 0)
                Text("Tap in Edit Home to pick buttons")
                    .font(.system(size: 9.5))
                    .ink(HomeStyle.secondary, Ink.detail)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: 6) {
                ForEach(tiles) { tile in
                    QuickTileButton(tile: tile, compact: true)
                }
            }
        }
    }
}

// MARK: - Recent copies

private struct PortraitClipboard: View {
    @ObservedObject private var clipboard = ClipboardHistoryManager.shared
    @State private var copiedID: UUID?

    var body: some View {
        PortraitCard {
            PortraitCaption(title: "Copies", symbol: "doc.on.doc")
            if !Defaults[.enableClipboardHistory] {
                Text("Clipboard history is off in Settings")
                    .font(.system(size: 9.5))
                    .ink(HomeStyle.secondary, Ink.detail)
            } else if clipboard.entries.isEmpty {
                Text("Things you copy show up here")
                    .font(.system(size: 9.5))
                    .ink(HomeStyle.secondary, Ink.detail)
            } else {
                ViewThatFits(in: .vertical) {
                    entries(4)
                    entries(3)
                    entries(2)
                    entries(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func entries(_ count: Int) -> some View {
        VStack(spacing: 4) {
            ForEach(clipboard.entries.prefix(count)) { entry in
                Button {
                    clipboard.copy(entry)
                    copiedID = entry.id
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.2))
                        if copiedID == entry.id { copiedID = nil }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if copiedID == entry.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.effectiveAccent)
                        }
                        Text(entry.previewText)
                            .font(.system(size: 10))
                            .lineLimit(1)
                            .ink(Ink.title)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6)
                    .frame(height: 22)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Copy again: \(entry.previewText)")
            }
        }
    }
}

// MARK: - Downloads

private struct PortraitDownloads: View {
    @ObservedObject private var downloads = DownloadMonitor.shared
    @ObservedObject private var feed = DownloadsFolderFeed.shared

    var body: some View {
        Group {
            if let download = downloads.primary {
                PortraitCard(alignment: .center) {
                    PortraitCaption(title: "Downloading")
                    Spacer(minLength: 0)
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: download.progress ?? 0.08)
                            .stroke(Color.effectiveAccent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(download.progress.map { "\(Int($0 * 100))%" } ?? "…")
                            .font(.system(size: 12, weight: .bold))
                            .monospacedDigit()
                    }
                    .frame(width: 54, height: 54)
                    Text(download.name)
                        .font(.system(size: 9.5, weight: .medium))
                        .lineLimit(2)
                        .ink(Ink.title)
                        .truncationMode(.middle)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 0)
                }
                .onTapGesture { NSWorkspace.shared.open(feed.folder) }
            } else {
                PortraitCard {
                    PortraitCaption(title: "Downloads", symbol: "arrow.down.circle")
                    if feed.files.isEmpty {
                        Text("New downloads show up here")
                            .font(.system(size: 9.5))
                            .ink(HomeStyle.secondary, Ink.detail)
                    } else {
                        ViewThatFits(in: .vertical) {
                            files(4)
                            files(3)
                            files(2)
                            files(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .task {
            while !Task.isCancelled {
                feed.refresh()
                try? await Task.sleep(for: .seconds(8))
            }
        }
    }

    private func files(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(feed.files.prefix(count)) { file in
                Button {
                    NSWorkspace.shared.open(file.url)
                } label: {
                    HStack(spacing: 5) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(file.name)
                            .font(.system(size: 10))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .ink(Ink.title)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onDrag { NSItemProvider(contentsOf: file.url) ?? NSItemProvider() }
                .help(file.name)
            }
        }
    }
}

// MARK: - Battery

/// A battery standing on its end, filled to the charge.
private struct PortraitBattery: View {
    @ObservedObject private var battery = BatteryStatusViewModel.shared

    var body: some View {
        let level = Double(battery.levelBattery) / 100
        let low = battery.levelBattery <= 20 && !battery.isCharging
        let tint: Color = low ? HomeStyle.alert : battery.isCharging ? Color(red: 0.29, green: 0.87, blue: 0.5) : .white
        PortraitCard(alignment: .center) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.25))
                .frame(width: 14, height: 3)
            GeometryReader { geometry in
                let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
                ZStack(alignment: .bottom) {
                    shape.fill(Color.white.opacity(0.07))
                    shape.fill(tint.opacity(battery.isCharging || low ? 0.85 : 0.75))
                        .frame(height: max(6, geometry.size.height * level))
                    VStack(spacing: 1) {
                        if battery.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text("\(Int(battery.levelBattery))%")
                            .font(.system(size: 15, weight: .bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(level > 0.45 && !low ? Color.black : Color.white)
                    .frame(maxHeight: .infinity)
                }
                .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            }
            .frame(maxWidth: 52)
            .padding(.top, -3)
            Text(status)
                .font(.system(size: 9))
                .ink(HomeStyle.secondary, Ink.detail)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .animation(.smooth, value: battery.levelBattery)
    }

    private var status: String {
        if battery.isInLowPowerMode { return "Low Power" }
        if battery.isCharging {
            if battery.timeToFullCharge > 0 {
                let hours = battery.timeToFullCharge / 60, minutes = battery.timeToFullCharge % 60
                return hours > 0 ? "Full in \(hours)h \(minutes)m" : "Full in \(minutes) min"
            }
            return "Charging"
        }
        return battery.isPluggedIn ? "Plugged in" : "On battery"
    }
}

// MARK: - Fans

private struct PortraitFans: View {
    @ObservedObject private var env = FanStudio.shared.environment
    @ObservedObject private var coordinator = TisaViewCoordinator.shared

    var body: some View {
        PortraitCard(highlight: (env.cpuTemperature ?? 0) >= 85 ? HomeStyle.alert : nil) {
            PortraitCaption(title: "CPU", symbol: "cpu")
            Text(env.temperatureText(env.cpuTemperature))
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(FanHeat.color(env.cpuTemperature))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .ink(FanHeat.color(env.cpuTemperature))
            VStack(alignment: .leading, spacing: 1) {
                if env.gpuTemperature != nil {
                    Text("GPU \(env.temperatureText(env.gpuTemperature))")
                }
                if let rpm = env.fastestFanRPM {
                    Label("\(Int(rpm.rounded())) rpm", systemImage: "fan")
                }
            }
            .font(.system(size: 9.5, weight: .medium))
            .monospacedDigit()
            .lineLimit(1)
            .ink(HomeStyle.secondary, Ink.cool)
            Spacer(minLength: 0)
            FanModeControl(style: .stacked)
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.smooth) { coordinator.currentView = .fans } }
    }
}

// MARK: - AI usage

private struct PortraitAIUsage: View {
    private let center = AIUsageCenter.shared
    @ObservedObject private var coordinator = TisaViewCoordinator.shared

    var body: some View {
        let providers = center.providers.filter { $0.tightestMeter != nil }
        PortraitCard {
            PortraitCaption(title: "AI Usage", symbol: "sparkles")
            if providers.isEmpty {
                Spacer(minLength: 0)
                Text(center.isReady ? "No limits found" : "Loading…")
                    .font(.system(size: 9.5))
                    .ink(HomeStyle.secondary, Ink.detail)
                Spacer(minLength: 0)
            } else {
                ViewThatFits(in: .vertical) {
                    rows(providers, 3)
                    rows(providers, 2)
                    rows(providers, 1)
                }
                Spacer(minLength: 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.smooth) { coordinator.currentView = .aiUsage } }
        .onAppear { center.start() }
    }

    private func rows(_ providers: [AIUsageProvider], _ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(providers.prefix(count)) { provider in
                let meter = provider.mainMeter
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        AIProviderBadge(provider: provider, size: 11)
                        Text(provider.name)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .ink(Ink.provider(provider.name))
                        Spacer(minLength: 2)
                        Text(meter.map { $0.fraction == nil ? $0.leftText : "\($0.leftText) left" } ?? "—")
                            .font(.system(size: 10, weight: .bold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .ink(Ink.title)
                    }
                    if let fraction = meter?.fraction {
                        AIUsageBar(used: fraction)
                    }
                    if let reset = AIUsageStyle.resetShort(meter?.resetsAt) {
                        Label("Resets in \(reset)", systemImage: "arrow.clockwise")
                            .font(.system(size: 9))
                            .ink(HomeStyle.secondary, Ink.reset)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .help(AIUsageStyle.resetText(meter?.resetsAt) ?? "")
                    }
                }
            }
        }
    }
}
