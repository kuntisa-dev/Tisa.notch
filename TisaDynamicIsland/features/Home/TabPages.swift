//
//  TabPages.swift
//  TisaDynamicIsland
//
//  The Apps, Calendar and Downloads tabs.
//

import AppKit
import Defaults
import SwiftUI

// MARK: - Apps

struct AppsTabView: View {
    @ObservedObject private var manager = RecentAppsManager.shared
    @Default(.appsSortByUse) private var sortByUse
    @Default(.hiddenRecentApps) private var hidden

    var body: some View {
        let kept = manager.keptApps()
        HStack(alignment: .top, spacing: 8) {
            if !kept.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HomeLabel(title: "Kept", trailing: "Always first")
                        .padding(.horizontal, 2)
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                            ForEach(kept) { app in
                                AppIconButton(app: app, iconSize: 38)
                            }
                        }
                    }
                }
                .padding(8)
                .frame(width: 140)
                .homeCard()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    HomeLabel(title: "Recent", trailing: nil)
                    Spacer(minLength: 0)
                    if !hidden.isEmpty {
                        Button("Show \(hidden.count) hidden") { manager.showHiddenApps() }
                            .buttonStyle(.plain)
                            .font(.system(size: 10))
                            .foregroundStyle(HomeStyle.secondary)
                    }
                    Picker("Sort", selection: $sortByUse) {
                        Text("Recent").tag(false)
                        Text("Most used").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.mini)
                    .frame(width: 130)
                }
                .padding(.horizontal, 2)

                let recent = manager.recentApps(sortByUse: sortByUse, excluding: Set(kept.map(\.bundleID)))
                if recent.isEmpty {
                    Text("Apps you switch to show up here.")
                        .font(.system(size: 11))
                        .foregroundStyle(HomeStyle.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 4)], spacing: 4) {
                            ForEach(recent) { app in
                                AppIconButton(app: app, iconSize: 36)
                            }
                        }
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .homeCard()
        }
        .padding(.top, 2)
    }
}

// MARK: - Calendar

/// The Calendar tab is the Khmer calendar with day notes (features/KhmerCalendar).
struct CalendarTabView: View {
    var body: some View {
        KhmerCalendarTab()
    }
}

// MARK: - Downloads

struct DownloadsTabView: View {
    @ObservedObject private var downloads = DownloadMonitor.shared
    @ObservedObject private var feed = DownloadsFolderFeed.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HomeLabel(title: downloads.isActive ? "Downloading" : "Newest in Downloads")
                Spacer(minLength: 0)
                Button {
                    NSWorkspace.shared.open(feed.folder)
                } label: {
                    Label("Open folder", systemImage: "folder")
                }
                .buttonStyle(HomePillButtonStyle(prominent: false))
            }

            if downloads.isActive {
                VStack(spacing: 5) {
                    ForEach(downloads.downloads) { download in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: feed.folder.path))
                                .resizable()
                                .frame(width: 22, height: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(download.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(Self.progressText(download))
                                        .font(.system(size: 10))
                                        .foregroundStyle(HomeStyle.secondary)
                                        .monospacedDigit()
                                }
                                if let progress = download.progress {
                                    ProgressView(value: progress).progressViewStyle(.linear).controlSize(.small).tint(Color.effectiveAccent)
                                } else {
                                    ProgressView().progressViewStyle(.linear).controlSize(.small)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 42)
                        .homeCard()
                    }
                }
            }

            if feed.files.isEmpty {
                Text("Nothing in Downloads yet.")
                    .font(.system(size: 11))
                    .inkColor(HomeStyle.secondary, Ink.detail)
                    .inkPlate()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(feed.files) { file in
                            DownloadedFileTile(file: file)
                        }
                    }
                }
            }
        }
        .padding(.top, 2)
        .task {
            while !Task.isCancelled {
                feed.refresh()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    static func progressText(_ download: ActiveDownload) -> String {
        let soFar = ByteCountFormatter.string(fromByteCount: download.bytesSoFar, countStyle: .file)
        if let total = download.totalBytes {
            return "\(soFar) of \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))"
        }
        return soFar
    }
}

private struct DownloadedFileTile: View {
    let file: DownloadedFile
    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(file.url)
        } label: {
            VStack(spacing: 4) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                    .resizable()
                    .frame(width: 40, height: 40)
                Text(file.name)
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(file.added.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))
                    .font(.system(size: 9))
                    .foregroundStyle(HomeStyle.tertiary)
            }
            .padding(7)
            .frame(width: 92)
            .frame(maxHeight: .infinity, alignment: .top)
            // The shared dark glass, so the tile stays readable on picture themes.
            .homeCard(highlight: hovering ? Color.effectiveAccent : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(contentsOf: file.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(file.url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
        }
        .help("\(file.name) · \(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))")
    }
}
