//
//  FeatureSettings.swift
//  TisaDynamicIsland
//
//  Settings pages for clipboard history, downloads and the audio-reactive visualizer.
//

import AIUsageKit
import Defaults
import KeyboardShortcuts
import SwiftUI

struct ClipboardSettings: View {
    @Default(.enableClipboardHistory) private var enabled
    @Default(.clipboardHistoryLimit) private var limit
    @ObservedObject private var manager = ClipboardHistoryManager.shared

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableClipboardHistory) {
                    Text("Keep clipboard history")
                }
                Defaults.Toggle(key: .clipboardIncludeImages) {
                    Text("Include images")
                }
                .disabled(!enabled)
                Stepper(value: $limit, in: 5...100, step: 5) {
                    HStack {
                        Text("Items to keep")
                        Spacer()
                        Text("\(limit)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .disabled(!enabled)
            } header: {
                Text("History")
            } footer: {
                Text("History stays in memory only and is cleared when the app quits. Passwords copied from password managers that mark them as concealed are never saved.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                KeyboardShortcuts.Recorder("Open clipboard history:", name: .clipboardHistoryPanel)
                Button("Clear history (\(manager.entries.count) items)") {
                    manager.clear()
                }
                .disabled(manager.entries.isEmpty)
            } footer: {
                Text("Click an item in the notch to copy it again, then paste with ⌘V.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Clipboard")
    }
}

struct DownloadsSettings: View {
    @Default(.enableDownloadListener) private var enabled
    @Default(.selectedDownloadIndicatorStyle) private var indicatorStyle
    @Default(.selectedDownloadIconStyle) private var iconStyle

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableDownloadListener) {
                    Text("Show download progress in the notch")
                }
                Defaults.Toggle(key: .enableSafariDownloads) {
                    Text("Include Safari downloads")
                }
                .disabled(!enabled)
                Picker("Progress style", selection: $indicatorStyle) {
                    Text("Ring").tag(DownloadIndicatorStyle.progress)
                    Text("Percentage").tag(DownloadIndicatorStyle.percentage)
                }
                .disabled(!enabled)
                Picker("Icon", selection: $iconStyle) {
                    Text("Browser icon").tag(DownloadIconStyle.onlyAppIcon)
                    Text("Download arrow").tag(DownloadIconStyle.onlyIcon)
                    Text("Both").tag(DownloadIconStyle.iconAndAppIcon)
                }
                .disabled(!enabled)
            } header: {
                Text("Download indicator")
            } footer: {
                Text("Watches your Downloads folder for files Safari, Chrome-based browsers and Firefox are still writing. Safari reports the total size, so it shows exact progress; Chrome and Firefox show a spinner instead. Hover the notch indicator to see the file name and size.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Downloads")
    }
}

/// Section placed in Settings › Appearance.
struct RealAudioVisualizerSection: View {
    @Default(.realAudioVisualizer) private var realAudio
    @State private var hasPermission = SystemAudioAnalyzer.hasPermission

    var body: some View {
        Section {
            Toggle("Bars react to the music", isOn: $realAudio)
                .onChange(of: realAudio) { _, isOn in
                    if isOn && !SystemAudioAnalyzer.hasPermission {
                        SystemAudioAnalyzer.requestPermission()
                    }
                    hasPermission = SystemAudioAnalyzer.hasPermission
                }

            if realAudio && !hasPermission {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("Needs Screen & System Audio Recording permission. After allowing it, restart Tisa Dynamic Island.")
                        .font(.caption)
                    Spacer()
                    Button("Open Settings") {
                        SystemAudioAnalyzer.openPrivacySettings()
                    }
                }
            }
        } header: {
            Text("Music visualizer")
        } footer: {
            Text("Off: the bars animate on their own. On: they follow the actual sound. macOS shows its recording indicator while the visualizer is listening.")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .onAppear { hasPermission = SystemAudioAnalyzer.hasPermission }
    }
}

struct PhotoBoothSettings: View {
    @Default(.enablePhotoBooth) private var enabled
    @Default(.photoBoothCountdown) private var countdown
    @Default(.boothPhotoCount) private var boothPhotoCount
    @Default(.boothCountdown) private var boothCountdown

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enablePhotoBooth) {
                    Text("Show Photo Booth tab")
                }
                Picker("Countdown", selection: $countdown) {
                    Text("Off").tag(0)
                    Text("3 seconds").tag(3)
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                }
                .disabled(!enabled)
                Defaults.Toggle(key: .photoBoothFlash) {
                    Text("Flash when taking a photo")
                }
                .disabled(!enabled)
                Defaults.Toggle(key: .photoBoothAddToShelf) {
                    Text("Add new photos to the Shelf")
                }
                .disabled(!enabled)
            } header: {
                Text("Photo Booth")
            } footer: {
                Text("Photos are saved as JPEG in Pictures › Tisa Dynamic Island Photos. The camera only runs while the Photo Booth tab is open.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                KeyboardShortcuts.Recorder("Open Photo Booth:", name: .openPhotoBooth)
                Button("Open Photos Folder") {
                    let folder = PhotoBoothCamera.shared.photosFolder
                    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(folder)
                }
            }

            Section {
                KeyboardShortcuts.Recorder("Open Photo Booth mode:", name: .openPhotoBoothMode)
                Picker("Number of photos", selection: $boothPhotoCount) {
                    Text("3 photos").tag(3)
                    Text("4 photos").tag(4)
                }
                Picker("Countdown before each photo", selection: $boothCountdown) {
                    Text("3 seconds").tag(3)
                    Text("5 seconds").tag(5)
                    Text("8 seconds").tag(8)
                }
                Button("Open Khmer Photo Booth Window") {
                    KhmerStampPanelController.shared.show()
                }
            } header: {
                Text("Photo Booth mode")
            } footer: {
                Text("In the Photo Booth tab, switch the preview to Photo Booth, pick a format (Khmer Stamp, Strip, Grid, Polaroid, Film, Minimal, Story 9:16, Square 1:1, Sticker, Comic, Receipt, Ronaldo Legacy, BTS ARMY Scrapbook, Web Hero City Night), a background, a filter and a backdrop (Off, Blur, or a scene that matches the frame, to hide your room) while a live sample shows you in that style, then press Take photos. It takes 3 or 4 photos with a countdown, fills the picture in as you go, and saves it as a PNG in Pictures › Tisa Dynamic Island Photos. The shortcut opens the tab straight in Photo Booth mode. The Khmer Photo Booth window is still in the menu bar.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Photo Booth")
    }
}

struct HomeSettings: View {
    @Default(.largeNotch) private var largeNotch
    @Default(.tisaHome) private var tisaHome
    @Default(.hiddenRecentApps) private var hiddenApps
    @Default(.homeBoxes) private var homeBoxes

    @Default(.notchTabs) private var notchTabs

    /// "6 tiles, 1 stack" for the Home section.
    private var homeSummary: String {
        let stacks = homeBoxes.filter(\.isStack).count
        let tiles = "\(homeBoxes.count) tile\(homeBoxes.count == 1 ? "" : "s")"
        return stacks == 0 ? tiles : "\(tiles), \(stacks) stack\(stacks == 1 ? "" : "s")"
    }

    private func tabBinding(_ tab: NotchTab) -> Binding<Bool> {
        Binding(
            get: { notchTabs.contains(tab) && NotchTab.visible.contains(tab) },
            set: { on in
                if on {
                    notchTabs = NotchTab.visible + [tab] + notchTabs.filter { $0 != tab && !NotchTab.visible.contains($0) }
                } else {
                    notchTabs.removeAll { $0 == tab }
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Notch size", selection: $largeNotch) {
                    Text("Standard (640 × 190)").tag(false)
                    Text("Large (720 × 220)").tag(true)
                }
                .onChange(of: largeNotch) {
                    NotificationCenter.default.post(name: .notchSizeChanged, object: nil)
                }
                Defaults.Toggle(key: .tisaHome) {
                    Text("New Home with boxes you can edit")
                }
            } header: {
                Text("Notch")
            } footer: {
                Text("The open notch's size. Large gives Home and every tab more room. Turn off the new Home to go back to the classic music player and calendar.")
            }

            Section {
                ForEach(NotchTab.allCases) { tab in
                    Toggle(isOn: tabBinding(tab)) {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .disabled(!tab.isAvailable || (!notchTabs.contains(tab) && NotchTab.visible.count >= NotchTab.maxVisible))
                }
            } header: {
                Text("Tabs (\(NotchTab.visible.count + 1) of \(NotchTab.maxVisible + 1), Home included)")
            } footer: {
                Text("Only \(NotchTab.maxVisible + 1) tabs fit next to the camera. To change the order, right-click the tab bar in the notch and drag the tabs. Shelf, Clipboard and Photo Booth also need their feature turned on in their own settings page.")
            }

            Section {
                LabeledContent("On Home", value: homeSummary)
                Button("Reset Home layout") {
                    Defaults[.homeBoxes] = HomeBox.defaultLayout
                    Defaults[.homeQuickTiles] = [.mic, .mirror]
                }
                .disabled(!tisaHome)
                Button(hiddenApps.isEmpty ? "No hidden apps" : "Show \(hiddenApps.count) hidden apps again") {
                    RecentAppsManager.shared.showHiddenApps()
                }
                .disabled(hiddenApps.isEmpty)
            } header: {
                Text("Home and Recent apps")
            } footer: {
                Text("To change Home, open the notch and press the pencil next to Settings, hold a tile, or right-click it. Tiles come in Small 1×1, Wide 2×1, Portrait 1×2, Medium 2×2, Large 3×2 and Extra large 4×2: drag the corner of a tile to resize it, drag a tile to move it, and press + to add a widget. When Home is full, Add to Stack puts more widgets in one tile; swipe sideways on a stack to switch. Recent apps learns from the apps you switch to; the list stays on this Mac.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Home & Tabs")
    }
}

struct FansSettings: View {
    @ObservedObject private var fans = FanStudio.shared.environment

    var body: some View {
        Form {
            Section {
                LabeledContent("CPU") {
                    Text(fans.temperatureText(fans.cpuTemperature))
                        .monospacedDigit()
                        .foregroundStyle(FanHeat.color(fans.cpuTemperature))
                }
                if fans.gpuTemperature != nil {
                    LabeledContent("GPU") {
                        Text(fans.temperatureText(fans.gpuTemperature))
                            .monospacedDigit()
                            .foregroundStyle(FanHeat.color(fans.gpuTemperature))
                    }
                }
                if let rpm = fans.fastestFanRPM {
                    LabeledContent("Fastest fan", value: "\(Int(rpm.rounded())) rpm")
                }
            } header: {
                Text("Right now")
            } footer: {
                Text("0 rpm is normal: Apple silicon Macs stop their fans while they're cool.")
            }

            Section {
                LabeledContent("Fan control") {
                    Text(fans.canControlFans ? "Ready" : "Not set up")
                        .foregroundStyle(fans.canControlFans ? Color.secondary : HomeStyle.warning)
                }
                if fans.canControlFans {
                    Picker("Mode", selection: Binding(
                        get: { fans.quickMode ?? .automatic },
                        set: { mode in Task { await fans.apply(mode) } }
                    )) {
                        ForEach(FanEnvironment.QuickMode.allCases, id: \.self) { mode in
                            Label(mode.title, systemImage: mode.symbol).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    Button("Set up fan control…") {
                        FanStudio.shared.showWindow(.settings)
                    }
                }
                Button("Open Tisa Fan Studio") {
                    FanStudio.shared.showWindow()
                }
            } header: {
                Text("Control")
            } footer: {
                Text("Full Blast runs every fan at full speed; Automatic hands them back to macOS. Changing fan speed needs a one-time admin setup in Fan Studio, and again after the app is rebuilt. Fan Studio also has fan curves, profiles and every sensor. The Fans tab and the Fans tile on Home have the same two buttons.")
            }
        }
    }
}

struct AIUsageSettings: View {
    private let center = AIUsageCenter.shared

    var body: some View {
        Form {
            Section {
                if center.providers.isEmpty {
                    Text(center.isReady ? "No AI tools found on this Mac yet." : "Loading…")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(center.providers) { provider in
                        LabeledContent {
                            if let meter = provider.mainMeter {
                                Text(meter.fraction == nil ? meter.leftText : "\(meter.leftText) left")
                                    .monospacedDigit()
                                    .foregroundStyle(AIUsageStyle.tint(meter.fraction))
                            } else {
                                Text(provider.error == nil ? "—" : "Can't read")
                                    .foregroundStyle(.secondary)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                center.icon(for: provider.id).frame(width: 14, height: 14)
                                Text(provider.name)
                            }
                        }
                    }
                }
                Button("Open AI Usage") {
                    AIUsageWindow.shared.show()
                }
            } header: {
                Text("Your AI tools")
            } footer: {
                Text("What's left of each tool's 5-hour limit (or the one closest to running out). Open AI Usage to add or hide tools, change the order and see every limit. It reads the logins those tools already keep on this Mac and asks each provider for your usage; nothing else is sent anywhere. Based on OpenUsage by Robin Ebers (MIT).")
            }
        }
        .onAppear { center.start() }
    }
}
