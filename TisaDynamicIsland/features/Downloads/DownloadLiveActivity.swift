//
//  DownloadLiveActivity.swift
//  TisaDynamicIsland
//
//  Closed-notch indicator for an in-progress browser download:
//  browser icon on the left of the notch, progress on the right.
//

import Defaults
import SwiftUI

struct DownloadLiveActivity: View {
    @EnvironmentObject var vm: TisaViewModel
    @ObservedObject private var monitor = DownloadMonitor.shared
    @Default(.selectedDownloadIndicatorStyle) private var indicatorStyle
    @Default(.selectedDownloadIconStyle) private var iconStyle

    var body: some View {
        let side = max(0, vm.effectiveClosedNotchHeight - 12)

        HStack {
            leadingIcon
                .frame(width: side, height: side)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - cornerRadiusInsets.closed.top)

            trailingIndicator
                .frame(width: side, height: side)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
        .help(helpText)
    }

    // MARK: - Pieces

    @ViewBuilder
    private var leadingIcon: some View {
        if monitor.downloads.isEmpty, monitor.recentlyCompleted != nil {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.green)
        } else if let download = monitor.primary {
            switch iconStyle {
            case .onlyIcon:
                Image(systemName: "arrow.down.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
            case .onlyAppIcon:
                appIcon(for: download)
            case .iconAndAppIcon:
                appIcon(for: download)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.white, .blue)
                    }
            }
        }
    }

    @ViewBuilder
    private func appIcon(for download: ActiveDownload) -> some View {
        if let icon = AppIconAsNSImage(for: download.bundleID) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "arrow.down.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        if monitor.downloads.isEmpty, monitor.recentlyCompleted != nil {
            ProgressRing(progress: 1, tint: .green)
        } else if let download = monitor.primary {
            if let progress = download.progress {
                if indicatorStyle == .percentage {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9, weight: .semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                } else {
                    ProgressRing(progress: progress, tint: .effectiveAccent)
                }
            } else {
                // Chrome and Firefox don't expose the total size on disk.
                IndeterminateRing()
            }
        }
    }

    private var helpText: String {
        if monitor.downloads.isEmpty, let name = monitor.recentlyCompleted {
            return "Downloaded \(name)"
        }
        guard let download = monitor.primary else { return "" }
        let done = ByteCountFormatter.string(fromByteCount: download.bytesSoFar, countStyle: .file)
        var text = "Downloading \(download.name) · \(done)"
        if let total = download.totalBytes {
            text += " of " + ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        }
        if monitor.downloads.count > 1 {
            text += " (+\(monitor.downloads.count - 1) more)"
        }
        return text
    }
}

private struct ProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: progress)
        }
        .padding(2)
    }
}

private struct IndeterminateRing: View {
    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.3)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
            .padding(2)
    }
}
