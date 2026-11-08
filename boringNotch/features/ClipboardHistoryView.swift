//
//  ClipboardHistoryView.swift
//  boringNotch
//
//  The Clipboard tab of the open notch: recent copies as cards.
//  Click a card to copy it again, then paste with ⌘V.
//

import AppKit
import Defaults
import SwiftUI

struct ClipboardHistoryView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var manager = ClipboardHistoryManager.shared
    @Default(.enableClipboardHistory) private var enabled

    var body: some View {
        Group {
            if !enabled {
                placeholder(icon: "clipboard", title: "Clipboard history is off", subtitle: "Turn it on in Settings › Clipboard")
            } else if manager.entries.isEmpty {
                placeholder(icon: "doc.on.clipboard", title: "Nothing copied yet", subtitle: "Text and images you copy will show up here")
            } else {
                HStack(alignment: .top, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            ForEach(manager.entries) { entry in
                                ClipboardCard(
                                    entry: entry,
                                    justCopied: manager.lastCopiedID == entry.id,
                                    onCopy: { copyAndClose(entry) },
                                    onRemove: { withAnimation(.smooth) { manager.remove(entry) } }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    Button {
                        withAnimation(.smooth) { manager.clear() }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.gray)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help("Clear clipboard history")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func copyAndClose(_ entry: ClipboardEntry) {
        manager.copy(entry)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            vm.close()
        }
    }

    private func placeholder(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.gray)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipboardCard: View {
    let entry: ClipboardEntry
    let justCopied: Bool
    let onCopy: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onCopy) {
            VStack(alignment: .leading, spacing: 6) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                HStack(spacing: 4) {
                    if let bundleID = entry.sourceBundleID, let icon = AppIconAsNSImage(for: bundleID) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 12, height: 12)
                    }
                    Text(justCopied ? "Copied" : entry.date.formatted(.relative(presentation: .numeric)))
                        .font(.system(size: 10))
                        .foregroundStyle(justCopied ? Color.green : .gray)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .padding(8)
            .frame(width: 128, height: 104)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(isHovering ? 0.14 : 0.08))
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .help("Click to copy, then paste with ⌘V")
        // Kept outside the copy button so clicking it only removes the item.
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
                .padding(4)
                .help("Remove")
            }
        }
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.content {
        case .text(let string):
            Text(string.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .lineLimit(5)
                .multilineTextAlignment(.leading)
        case .image(let data, _):
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.gray)
            }
        }
    }
}
