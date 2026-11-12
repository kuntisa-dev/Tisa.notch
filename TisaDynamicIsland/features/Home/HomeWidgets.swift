//
//  HomeWidgets.swift
//  TisaDynamicIsland
//
//  What Home's boxes show. Each widget adapts to its box size and to what's
//  going on: Now playing keeps the last song and its controls when nothing plays,
//  Up next lights up with a countdown and Join before a meeting, and Quick's
//  live bar shows a running download, else the last thing you copied.
//  One-row tiles use HomeCompactWidgets.swift, Tall tiles HomePortraitWidgets.swift.
//

import AppKit
import Defaults
import SwiftUI

struct HomeWidgetView: View {
    let box: HomeBox

    var body: some View {
        if box.size.isCompact {
            CompactWidgetView(box: box)
        } else if box.size == .tall {
            PortraitWidgetView(box: box)
        } else {
            fullSize
        }
    }

    @ViewBuilder
    private var fullSize: some View {
        switch box.widget {
        case .nowPlaying: NowPlayingBox(size: box.size)
        case .upNext: UpNextBox(size: box.size)
        case .today: TodayBox()
        case .recentApps: RecentAppsBox()
        case .quick: QuickBox()
        case .clipboard: ClipboardBox()
        case .downloads: DownloadsBox()
        case .battery: BatteryBox()
        case .fans: FansBox(size: box.size)
        case .aiUsage: AIUsageBox(size: box.size)
        case .dropZone: DropZoneBox()
        case .mirror: MirrorBox()
        }
    }
}

// MARK: - Now playing

private struct NowPlayingBox: View {
    let size: HomeBoxSize
    @ObservedObject private var music = MusicManager.shared
    @Default(.largeNotch) private var largeNotch
    @Default(.notchTheme) private var theme
    @Default(.themeGlowTiles) private var glowTiles

    /// Themes with glowing tiles put the controls on their own glass bar.
    private var glassControls: Bool { theme != .classic && glowTiles }

    private var isIdle: Bool { music.isPlayerIdle && !music.isPlaying }
    /// Something played earlier, so Play picks it up again.
    private var hasLastSong: Bool { music.bundleIdentifier != nil && !music.songTitle.isEmpty }

    /// The full player, even with nothing playing: the last song (or a note to press play)
    /// stays in place with its art and controls.
    var body: some View {
        player
            .padding(10)
            .homeCard()
    }

    private var artSize: CGFloat {
        let base: CGFloat
        switch size {
        case .large, .extraLarge: base = 58
        default: base = 50
        }
        return base + (largeNotch ? 12 : 0)
    }

    private var title: String {
        if isIdle && !hasLastSong { return "Nothing playing" }
        return music.songTitle
    }

    private var subtitle: String {
        if isIdle { return hasLastSong ? "Paused · \(music.artistName)" : "Press play to start your music" }
        return music.artistName
    }

    private var player: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                art
                    .onTapGesture { music.openMusicApp() }
                    .help("Open the music app")
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .ink(Ink.title)
                    Text(subtitle)
                        .font(.system(size: 11, weight: Ink.active ? .semibold : .regular))
                        .ink(HomeStyle.secondary, Ink.detail)
                    MusicWaveform(playing: music.isPlaying)
                        .frame(height: 14)
                        .padding(.top, 3)
                }
                .lineLimit(1)
            }
            Spacer(minLength: 6)
            MusicProgress(showTimes: true)
                .opacity(isIdle ? 0.5 : 1)
            Spacer(minLength: 6)
            controls
        }
    }

    @ViewBuilder
    private var art: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if isIdle && !hasLastSong {
            Image(systemName: "music.note")
                .font(.system(size: artSize * 0.36, weight: .semibold))
                .foregroundStyle(HomeStyle.secondary)
                .frame(width: artSize, height: artSize)
                .background(shape.fill(Color.white.opacity(0.08)))
        } else {
            Image(nsImage: music.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: artSize, height: artSize)
                .clipShape(shape)
                .opacity(isIdle ? 0.7 : 1)
                .shadow(color: Color(nsColor: music.avgColor).opacity(isIdle ? 0.25 : 0.55), radius: 10, y: 4)
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            if music.canFavoriteTrack {
                controlButton(music.isFavoriteTrack ? "heart.fill" : "heart", size: 13, help: "Favorite") {
                    music.toggleFavoriteTrack()
                }
                Spacer(minLength: 0)
            }
            controlButton("backward.fill", size: 15, help: "Previous") { music.previousTrack() }
            Spacer(minLength: 0)
            Button {
                if isIdle && !hasLastSong {
                    music.openMusicApp()
                } else {
                    music.togglePlay()
                }
            } label: {
                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Ink.playIcon)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Ink.playFill))
            }
            .buttonStyle(GlassPressStyle())
            .help(music.isPlaying ? "Pause" : isIdle && !hasLastSong ? "Open the music app" : "Play")
            Spacer(minLength: 0)
            controlButton("forward.fill", size: 15, help: "Next") { music.nextTrack() }
            Spacer(minLength: 0)
            controlButton("arrow.up.forward.app", size: 13, help: "Open the music app") { music.openMusicApp() }
        }
        .padding(.horizontal, glassControls ? 8 : 2)
        .padding(.vertical, glassControls ? 2 : 0)
        .background {
            if glassControls {
                Capsule().fill(Color.white.opacity(0.07))
                    .overlay(Capsule().strokeBorder(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                                                                   startPoint: .top, endPoint: .bottom), lineWidth: 1))
            }
        }
    }

    private func controlButton(_ symbol: String, size: CGFloat, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(symbol.hasPrefix("heart") && Ink.colorIcons ? Ink.quick(.mic) : Ink.control)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressStyle())
        .help(help)
    }
}

/// Bars that dance while music plays, tallest in the middle; still and faint when paused.
/// It's a lively pattern rather than the real sound, so it needs no permissions.
struct MusicWaveform: View {
    let playing: Bool
    var bars = 22

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !playing)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                let gap: CGFloat = 2
                let width = max(1.5, (geometry.size.width - gap * CGFloat(bars - 1)) / CGFloat(bars))
                HStack(alignment: .center, spacing: gap) {
                    ForEach(0..<bars, id: \.self) { index in
                        bar(index, time: time, width: width, maxHeight: geometry.size.height)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private func bar(_ index: Int, time: TimeInterval, width: CGFloat, maxHeight: CGFloat) -> some View {
        Capsule()
            .fill(color(index))
            .frame(width: width, height: max(width, maxHeight * CGFloat(level(index, time: time))))
    }

    /// 0…1: taller toward the middle, moving while it plays.
    private func level(_ index: Int, time: TimeInterval) -> Double {
        let position = Double(index) / Double(bars - 1) * 2 - 1
        let envelope = 0.25 + 0.75 * (1 - abs(position))
        guard playing else { return envelope * 0.3 }
        let speed = 3.1 + Double(index % 5) * 0.9
        let wobble = abs(sin(time * speed + Double(index) * 1.7))
        return envelope * (0.35 + 0.65 * wobble)
    }

    private func color(_ index: Int) -> Color {
        let opacity = playing ? 0.95 : 0.4
        return abs(index - bars / 2) <= 2 ? Color.white.opacity(opacity) : Color.effectiveAccent.opacity(opacity)
    }
}

private struct MusicProgress: View {
    let showTimes: Bool
    @ObservedObject private var music = MusicManager.shared
    @State private var dragFraction: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = max(music.songDuration, 0)
            let position = min(duration, music.estimatedPlaybackPosition(at: context.date))
            let fraction = dragFraction ?? (duration > 0 ? position / duration : 0)
            HStack(spacing: 7) {
                if showTimes {
                    Text(Self.time(fraction * duration))
                        .ink(Ink.time)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.14))
                        Capsule().fill(Defaults[.notchTheme] == .classic ? Color.white : Color.effectiveAccent)
                            .frame(width: max(4, geometry.size.width * fraction))
                    }
                    .frame(height: dragFraction == nil ? 4 : 6)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragFraction = min(1, max(0, value.location.x / max(1, geometry.size.width)))
                            }
                            .onEnded { _ in
                                if let dragFraction, duration > 0 {
                                    music.seek(to: dragFraction * duration)
                                }
                                dragFraction = nil
                            }
                    )
                }
                .frame(height: 12)
                if showTimes {
                    Text("-" + Self.time(max(0, duration - fraction * duration)))
                        .ink(Ink.time)
                }
            }
            .font(.system(size: 10, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(HomeStyle.secondary)
        }
    }

    static func time(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return total >= 3600
            ? String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
            : String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Up next

struct UpNextBox: View {
    let size: HomeBoxSize
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
            CalendarAccessPrompt()
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .homeCard()
        } else if let next = feed.upcoming.first(where: { $0.end > now }) {
            let startsIn = next.start.timeIntervalSince(now)
            let live = startsIn <= 0
            let soon = !live && startsIn <= 5 * 60
            let highlight = (soon || (live && next.meetingURL != nil)) ? Color.effectiveAccent : nil
            VStack(alignment: .leading, spacing: 0) {
                HomeLabel(title: live ? "Now" : soon ? "Starts in" : "Up next",
                          trailing: live ? "until \(next.end.formatted(date: .omitted, time: .shortened))" : Self.relative(startsIn))
                if soon {
                    Text(Self.countdown(startsIn))
                        .font(.system(size: 24, weight: .bold))
                        .monospacedDigit()
                        .ink(Ink.reset)
                        .padding(.top, 1)
                }
                Text(next.title)
                    .font(.system(size: soon ? 13 : 14, weight: .semibold))
                    .lineLimit(1)
                    .ink(Ink.title)
                    .padding(.top, soon ? 0 : 5)
                Text(Self.details(next))
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .ink(HomeStyle.secondary, Ink.detail)
                    .padding(.top, 2)
                actions(next, prominent: soon || live)
                    .padding(.top, 8)
                if !soon && size != .small {
                    Spacer(minLength: 6)
                    later(after: next)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .homeCard(highlight: highlight)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HomeLabel(title: "Up next", trailing: now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                Spacer(minLength: 0)
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 20))
                    .foregroundStyle(HomeStyle.secondary)
                Text("Nothing else today")
                    .font(.system(size: 12, weight: .semibold))
                Text("Your calendar is clear until tomorrow.")
                    .font(.system(size: 10))
                    .foregroundStyle(HomeStyle.secondary)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .homeCard()
        }
    }

    private func actions(_ event: EventModel, prominent: Bool) -> some View {
        HStack(spacing: 6) {
            if let meeting = event.meetingURL {
                Button {
                    NSWorkspace.shared.open(meeting)
                } label: {
                    Label("Join", systemImage: "video.fill")
                }
                .buttonStyle(HomePillButtonStyle(prominent: true))
                .help(meeting.host ?? "Join the call")
            }
            if let open = event.calendarAppURL() {
                Button("Open") { NSWorkspace.shared.open(open) }
                    .buttonStyle(HomePillButtonStyle(prominent: event.meetingURL == nil && prominent))
                    .help("Open in Calendar")
            }
        }
    }

    private func later(after next: EventModel) -> some View {
        let rest = feed.upcoming.drop { $0.id != next.id }.dropFirst().prefix(size == .medium ? 2 : 3)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(rest), id: \.id) { event in
                HStack(spacing: 7) {
                    Circle().fill(Color(nsColor: event.calendar.color)).frame(width: 6, height: 6)
                    Text(Calendar.current.isDateInToday(event.start)
                         ? event.start.formatted(date: .omitted, time: .shortened)
                         : "Tmrw")
                        .inkColor(HomeStyle.secondary, Ink.reset)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .leading)
                    Text(event.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .font(.system(size: 11))
                .inkPlate()
            }
        }
    }

    static func details(_ event: EventModel) -> String {
        let time = "\(event.start.formatted(date: .omitted, time: .shortened))–\(event.end.formatted(date: .omitted, time: .shortened))"
        if let host = event.meetingURL?.host {
            return "\(time) · \(Self.service(host))"
        }
        if let location = event.location, !location.isEmpty {
            return "\(time) · \(location)"
        }
        return time
    }

    private static func service(_ host: String) -> String {
        if host.contains("zoom") { return "Zoom" }
        if host.contains("meet.google") { return "Google Meet" }
        if host.contains("teams") { return "Teams" }
        if host.contains("webex") { return "Webex" }
        if host.contains("facetime") { return "FaceTime" }
        return "Video call"
    }

    static func relative(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 { return "in \(minutes) min" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "in \(hours) h" : "in \(hours) h \(rest) min"
    }

    static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct CalendarAccessPrompt: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeLabel(title: "Up next")
            Text("See your next meeting here")
                .font(.system(size: 12, weight: .semibold))
            Text("Allow calendar access to show events and a Join button.")
                .font(.system(size: 10))
                .foregroundStyle(HomeStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Allow") { TodayFeed.shared.requestAccess() }
                .buttonStyle(HomePillButtonStyle(prominent: true))
        }
    }
}

// MARK: - Today

struct TodayBox: View {
    @ObservedObject private var feed = TodayFeed.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeLabel(title: "Today", trailing: Date().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
            if !feed.hasAccess {
                CalendarAccessPrompt()
            } else if feed.today.isEmpty && feed.reminders.isEmpty {
                Spacer(minLength: 0)
                Text("Nothing on today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HomeStyle.secondary)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(feed.today, id: \.id) { event in
                            Button {
                                if let url = event.calendarAppURL() { NSWorkspace.shared.open(url) }
                            } label: {
                                HStack(spacing: 7) {
                                    Circle().fill(Color(nsColor: event.calendar.color)).frame(width: 6, height: 6)
                                    Text(event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened))
                                        .inkColor(HomeStyle.secondary, Ink.reset)
                                        .monospacedDigit()
                                        .frame(width: 44, alignment: .leading)
                                    Text(event.title)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                }
                                .font(.system(size: 11))
                                .opacity(event.end < Date() ? 0.45 : 1)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        if !feed.reminders.isEmpty && !feed.today.isEmpty {
                            Divider().overlay(Color.white.opacity(0.08))
                        }
                        ForEach(feed.reminders, id: \.id) { reminder in
                            Button {
                                feed.complete(reminder)
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(nsColor: reminder.calendar.color))
                                    Text(reminder.title)
                                        .lineLimit(1)
                                }
                                .font(.system(size: 11))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Mark as done")
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .homeCard()
        .onAppear { feed.begin() }
        .onDisappear { feed.end() }
    }
}

// MARK: - Recent apps

private struct RecentAppsBox: View {
    @ObservedObject private var manager = RecentAppsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HomeLabel(title: "Recent apps")
                .padding(.horizontal, 2)
            GeometryReader { geometry in
                let columns = max(2, Int(geometry.size.width / 46))
                let rows = max(1, Int(geometry.size.height / 54))
                let apps = manager.apps(limit: columns * rows)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: columns), spacing: 2) {
                    ForEach(apps) { app in
                        AppIconButton(app: app, iconSize: 34)
                    }
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 8)
        .homeCard()
    }
}

struct AppIconButton: View {
    let app: RecentApp
    let iconSize: CGFloat
    var showsName = true
    @State private var hovering = false

    var body: some View {
        Button {
            RecentAppsManager.shared.open(app)
        } label: {
            VStack(spacing: 3) {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: iconSize, height: iconSize)
                    .scaleEffect(hovering ? 1.08 : 1)
                if showsName {
                    Text(app.name)
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .ink(Color(white: 0.85), Ink.title)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .overlay(alignment: .topLeading) {
                if app.isKept {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(HomeStyle.onAccent)
                        .frame(width: 13, height: 13)
                        .background(Circle().fill(Color.effectiveAccent))
                        .overlay(Circle().strokeBorder(Color.black, lineWidth: 1.5))
                        .offset(x: 2, y: -1)
                }
            }
            .overlay(alignment: .bottom) {
                if app.isRunning {
                    Circle().fill(Color(white: 0.85)).frame(width: 3, height: 3).offset(y: 2)
                }
            }
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(hovering ? 0.1 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressStyle())
        .help(app.name)
        .onHover { inside in
            withAnimation(.smooth(duration: 0.15)) { hovering = inside }
        }
        .contextMenu {
            Button("Open \(app.name)") { RecentAppsManager.shared.open(app) }
            Button(app.isKept ? "Stop keeping in Recent apps" : "Keep in Recent apps") {
                RecentAppsManager.shared.toggleKeep(app)
            }
            Button("Hide from Recent apps") { RecentAppsManager.shared.hide(app) }
            if app.isRunning {
                Divider()
                Button("Quit \(app.name)") { RecentAppsManager.shared.quit(app) }
            }
        }
    }
}

// MARK: - Quick

private struct QuickBox: View {
    @EnvironmentObject private var vm: TisaViewModel
    @Default(.homeQuickTiles) private var tiles

    var body: some View {
        VStack(spacing: 6) {
            if !tiles.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(tiles) { tile in
                        QuickTileButton(tile: tile)
                    }
                }
            }
            if vm.isCameraExpanded && tiles.contains(.mirror) {
                MirrorPreview()
            } else {
                LiveBar()
            }
        }
    }
}

struct QuickTileButton: View {
    let tile: HomeQuickTile
    /// Icon only, filling the space it is given (compact Quick tiles).
    var compact = false
    @EnvironmentObject private var vm: TisaViewModel
    @ObservedObject private var coordinator = TisaViewCoordinator.shared
    @ObservedObject private var shelf = ShelfStateViewModel.shared
    @State private var micMuted = MicrophoneManager.shared.isMuted

    var body: some View {
        Button(action: tap) {
            Group {
                if compact {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Image(systemName: symbol)
                            .font(.system(size: 14, weight: .semibold))
                        Spacer(minLength: 2)
                        Text(label)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 44)
                }
            }
            .foregroundStyle(active ? activeColor : Ink.active ? Ink.quick(tile) : .white)
            .background {
                let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                shape.fill(active ? activeColor.opacity(0.18) : Ink.rowFill)
                    .overlay(shape.strokeBorder(active ? activeColor.opacity(0.55) : Color.white.opacity(0.07), lineWidth: 1))
            }
            .overlay(alignment: .topTrailing) {
                if tile == .shelf && !shelf.isEmpty {
                    Text("\(shelf.items.count)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .frame(height: 15)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                        .padding(6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressStyle())
        .help(help)
        .task(id: tile) {
            // The mic can also be muted with ⌃⌥M or elsewhere; keep the tile in step.
            guard tile == .mic else { return }
            while !Task.isCancelled {
                micMuted = MicrophoneManager.shared.isMuted
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    private var active: Bool {
        switch tile {
        case .mic: return micMuted
        case .mirror: return vm.isCameraExpanded
        default: return false
        }
    }

    private var activeColor: Color { tile == .mic ? HomeStyle.alert : Color.effectiveAccent }

    private var symbol: String {
        switch tile {
        case .mic: return micMuted ? "mic.slash.fill" : "mic"
        case .mirror: return vm.isCameraExpanded ? "web.camera.fill" : "web.camera"
        default: return tile.symbol
        }
    }

    private var label: String {
        switch tile {
        case .mic: return micMuted ? "Muted" : "Mic on"
        default: return tile.title
        }
    }

    private var help: String {
        switch tile {
        case .mic: return micMuted ? "Unmute the microphone" : "Mute the microphone"
        case .mirror: return vm.isCameraExpanded ? "Hide the mirror" : "Show the mirror"
        case .photoBooth: return "Open Photo Booth"
        case .shelf: return "Open the Shelf"
        }
    }

    private func tap() {
        switch tile {
        case .mic:
            if let muted = MicrophoneManager.shared.toggle() {
                micMuted = muted
            }
        case .mirror:
            vm.toggleCameraPreview()
        case .photoBooth:
            withAnimation(.smooth) { coordinator.currentView = .photoBooth }
        case .shelf:
            withAnimation(.smooth) { coordinator.currentView = .shelf }
        }
    }
}

/// One line that shows what matters now: a download, else the last copy, else the battery.
private struct LiveBar: View {
    @ObservedObject private var downloads = DownloadMonitor.shared
    @ObservedObject private var clipboard = ClipboardHistoryManager.shared
    @ObservedObject private var battery = BatteryStatusViewModel.shared
    @State private var copied = false

    var body: some View {
        Group {
            if let download = downloads.primary {
                barRow(symbol: "arrow.down", tint: Color.effectiveAccent,
                       caption: download.progress.map { "\(Int($0 * 100))%" } ?? "Downloading",
                       title: download.name, progress: download.progress) {
                    NSWorkspace.shared.open(DownloadsFolderFeed.shared.folder)
                }
                .help("Downloading \(download.name). Click to open Downloads")
            } else if let name = downloads.recentlyCompleted {
                barRow(symbol: "checkmark.circle.fill", tint: Color.effectiveAccent, caption: "Downloaded", title: name, progress: nil) {
                    NSWorkspace.shared.open(DownloadsFolderFeed.shared.folder)
                }
            } else if Defaults[.enableClipboardHistory], let entry = clipboard.entries.first {
                barRow(symbol: copied ? "checkmark" : "doc.on.doc", tint: HomeStyle.secondary,
                       caption: copied ? "Copied" : "Last copied · \(entry.date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))",
                       title: entry.previewText, progress: nil) {
                    clipboard.copy(entry)
                    copied = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.2))
                        copied = false
                    }
                }
                .help("Copy it again")
            } else {
                barRow(symbol: battery.isCharging ? "bolt.fill" : "battery.75percent",
                       tint: battery.levelBattery <= 20 && !battery.isCharging ? HomeStyle.alert : HomeStyle.secondary,
                       caption: battery.isCharging ? "Charging" : "Battery",
                       title: "\(Int(battery.levelBattery))%", progress: Double(battery.levelBattery) / 100) {}
            }
        }
    }

    private func barRow(symbol: String, tint: Color, caption: String, title: String, progress: Double?,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(caption)
                        .font(.system(size: 9))
                        .ink(HomeStyle.tertiary, Ink.detail)
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .ink(Ink.title)
                    if let progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(tint)
                            .controlSize(.mini)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .homeCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent copies

private struct ClipboardBox: View {
    @ObservedObject private var clipboard = ClipboardHistoryManager.shared
    @State private var copiedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HomeLabel(title: "Recent copies", trailing: copiedID == nil ? "Click to copy" : "Copied")
            if !Defaults[.enableClipboardHistory] {
                Text("Clipboard history is off. Turn it on in Settings › Clipboard.")
                    .font(.system(size: 10))
                    .foregroundStyle(HomeStyle.secondary)
            } else if clipboard.entries.isEmpty {
                Text("Things you copy show up here.")
                    .font(.system(size: 10))
                    .foregroundStyle(HomeStyle.secondary)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(clipboard.entries.prefix(8)) { entry in
                            Button {
                                clipboard.copy(entry)
                                copiedID = entry.id
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(1.2))
                                    if copiedID == entry.id { copiedID = nil }
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: copiedID == entry.id ? "checkmark" : symbol(entry))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(HomeStyle.secondary)
                                        .frame(width: 12)
                                    Text(entry.previewText)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 7)
                                .frame(height: 24)
                                .background(RoundedRectangle(cornerRadius: 7).fill(Ink.active ? Color.black.opacity(0.48) : Color.white.opacity(0.05)))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .homeCard()
    }

    private func symbol(_ entry: ClipboardEntry) -> String {
        if case .image = entry.content { return "photo" }
        return entry.previewText.hasPrefix("http") ? "link" : "doc.text"
    }
}

// MARK: - Downloads

private struct DownloadsBox: View {
    @ObservedObject private var downloads = DownloadMonitor.shared
    @ObservedObject private var feed = DownloadsFolderFeed.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HomeLabel(title: "Downloads", trailing: downloads.isActive ? "\(downloads.downloads.count) in progress" : nil)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(downloads.downloads) { download in
                        HStack(spacing: 7) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.effectiveAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(download.name).font(.system(size: 11, weight: .medium)).lineLimit(1).ink(Ink.title)
                                if let progress = download.progress {
                                    ProgressView(value: progress).progressViewStyle(.linear).controlSize(.mini).tint(Color.effectiveAccent)
                                }
                            }
                        }
                    }
                    ForEach(feed.files.prefix(6)) { file in
                        DownloadedFileRow(file: file)
                            .inkPlate()
                    }
                    if feed.files.isEmpty && !downloads.isActive {
                        Text("New downloads show up here.")
                            .font(.system(size: 10))
                            .foregroundStyle(HomeStyle.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .homeCard()
        .task {
            while !Task.isCancelled {
                feed.refresh()
                try? await Task.sleep(for: .seconds(8))
            }
        }
    }
}

struct DownloadedFileRow: View {
    let file: DownloadedFile

    var body: some View {
        Button {
            NSWorkspace.shared.open(file.url)
        } label: {
            HStack(spacing: 7) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(file.name)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                Text(file.added.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))
                    .font(.system(size: 9.5))
                    .inkColor(HomeStyle.tertiary, Ink.reset)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrag { NSItemProvider(contentsOf: file.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(file.url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
        }
        .help(file.name)
    }
}

// MARK: - Battery

private struct BatteryBox: View {
    @ObservedObject private var battery = BatteryStatusViewModel.shared

    var body: some View {
        let low = battery.levelBattery <= 20 && !battery.isCharging
        let tint: Color = low ? HomeStyle.alert : battery.isCharging ? Color(red: 0.29, green: 0.87, blue: 0.5) : .white
        VStack(alignment: .leading, spacing: 6) {
            HomeLabel(title: "Battery", trailing: battery.isInLowPowerMode ? "Low Power" : nil)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(battery.levelBattery))%")
                    .font(.system(size: 26, weight: .bold))
                    .monospacedDigit()
                    .ink(low ? HomeStyle.alert : Ink.good)
                if battery.isCharging {
                    Image(systemName: "bolt.fill").foregroundStyle(tint)
                }
            }
            ProgressView(value: Double(battery.levelBattery), total: 100)
                .progressViewStyle(.linear)
                .tint(tint)
            Text(status)
                .font(.system(size: 10.5))
                .lineLimit(1)
                .ink(HomeStyle.secondary, Ink.detail)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .homeCard()
    }

    private var status: String {
        if battery.isCharging {
            if battery.timeToFullCharge > 0 {
                let hours = battery.timeToFullCharge / 60, minutes = battery.timeToFullCharge % 60
                return hours > 0 ? "Full in \(hours) h \(minutes) min" : "Full in \(minutes) min"
            }
            return "Charging"
        }
        return battery.isPluggedIn ? "Plugged in, not charging" : "On battery"
    }
}

// MARK: - Drop zone

struct DropZoneBox: View {
    @ObservedObject private var coordinator = TisaViewCoordinator.shared
    @ObservedObject private var shelf = ShelfStateViewModel.shared

    var body: some View {
        Button {
            withAnimation(.smooth) { coordinator.currentView = .shelf }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 17))
                Text("Drop files to keep or AirDrop")
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
                if !shelf.isEmpty {
                    Text("\(shelf.items.count) on the Shelf")
                        .font(.system(size: 9.5))
                        .foregroundStyle(HomeStyle.tertiary)
                }
            }
            .foregroundStyle(HomeStyle.secondary)
            .padding(8)
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

// MARK: - Mirror

struct MirrorBox: View {
    @EnvironmentObject private var vm: TisaViewModel

    var body: some View {
        if vm.isCameraExpanded {
            MirrorPreview()
        } else {
            Button {
                vm.toggleCameraPreview()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "web.camera")
                        .font(.system(size: 18))
                    Text("Show mirror")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(HomeStyle.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .homeCard()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Check how you look before a call")
        }
    }
}

private struct MirrorPreview: View {
    @EnvironmentObject private var vm: TisaViewModel

    var body: some View {
        CameraPreviewView(webcamManager: WebcamManager.shared)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: HomeMetrics.cornerRadius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button {
                    vm.toggleCameraPreview()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.black.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .padding(5)
                .help("Hide the mirror")
            }
    }
}
