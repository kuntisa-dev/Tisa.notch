//
//  FeatureSettings.swift
//  boringNotch
//
//  Settings pages for clipboard history, downloads and the audio-reactive visualizer.
//

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
                    Text("Needs Screen & System Audio Recording permission. After allowing it, restart Tisa Notch.")
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
                Text("Photos are saved as JPEG in Pictures › Tisa Notch Photos. The camera only runs while the Photo Booth tab is open.")
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
                KeyboardShortcuts.Recorder("Open Khmer Photo Booth:", name: .openKhmerStampBooth)
                Button("Open Khmer Photo Booth") {
                    KhmerStampPanelController.shared.show()
                }
            } header: {
                Text("Khmer stamp booth")
            } footer: {
                Text("Takes 3 or 4 photos with a countdown and turns them into a Khmer Heritage postage stamp you can save as a PNG. Also in the menu bar and the Photo Booth tab.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Photo Booth")
    }
}
