//
//  PhotoBoothView.swift
//  boringNotch
//
//  The Photo Booth tab: live preview with effects, countdown, flash,
//  and the most recent photos. Photos go to ~/Pictures/Tisa Notch Photos.
//

import AppKit
import Defaults
import SwiftUI

struct PhotoBoothView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var camera = PhotoBoothCamera.shared
    @Default(.photoBoothCountdown) private var countdownSetting

    @State private var countdown: Int?
    @State private var flash = false
    @State private var isCapturing = false
    @State private var captureTask: Task<Void, Never>?
    @State private var message: String?

    private let previewSize = CGSize(width: 184, height: 138)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            preview
            controls
            RecentPhotosGrid(photos: camera.recentPhotos)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            // The Home tab's mirror and this tab never show together; make sure the mirror lets go.
            WebcamManager.shared.stopSession()
            camera.refreshRecentPhotos()
            camera.start()
        }
        .onDisappear {
            captureTask?.cancel()
            camera.stop()
        }
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.08))

            if let image = camera.previewImage {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                statusPlaceholder
            }

            if let countdown {
                Text("\(countdown)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 8)
                    .contentTransition(.numericText(countsDown: true))
                    .transition(.scale.combined(with: .opacity))
            }

            if flash {
                Color.white
            }

            if let message {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.6)))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
        }
        .frame(width: previewSize.width, height: previewSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { shoot() }
        .help("Click or press the shutter to take a photo")
    }

    @ViewBuilder
    private var statusPlaceholder: some View {
        VStack(spacing: 6) {
            switch camera.status {
            case .needsPermission:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 20))
                    .foregroundStyle(.yellow)
                Text("Camera access is off")
                    .font(.caption)
                    .foregroundStyle(.white)
                Button("Open Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            case .noCamera:
                Image(systemName: "video.slash")
                    .font(.system(size: 20))
                    .foregroundStyle(.gray)
                Text("No camera found")
                    .font(.caption)
                    .foregroundStyle(.gray)
            case .failed(let reason):
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 20))
                    .foregroundStyle(.gray)
                Text(reason)
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
            default:
                ProgressView()
                    .controlSize(.small)
                Text("Starting camera…")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(24), spacing: 6), GridItem(.fixed(24), spacing: 6)], spacing: 6) {
                    ForEach(PhotoBoothEffect.allCases) { effect in
                        Button {
                            camera.effect = effect
                        } label: {
                            Text(effect.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(camera.effect == effect ? .black : .white)
                                .padding(.horizontal, 10)
                                .frame(height: 24)
                                .background(
                                    Capsule().fill(camera.effect == effect ? Color.white : Color.white.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 54)

            HStack(spacing: 14) {
                Button {
                    cycleCountdown()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                        Text(countdownSetting == 0 ? "Off" : "\(countdownSetting)s")
                            .monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(countdownSetting == 0 ? .gray : .white)
                    .frame(width: 52, height: 28)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Countdown before the photo")

                Button(action: shoot) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 50, height: 50)
                        Circle()
                            .fill(isCapturing ? Color.red : Color.white)
                            .frame(width: 40, height: 40)
                    }
                }
                .buttonStyle(.plain)
                .disabled(camera.status != .running || isCapturing)
                .opacity(camera.status == .running ? 1 : 0.4)
                .help("Take a photo")

                Button {
                    NSWorkspace.shared.open(camera.photosFolder)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Open the Tisa Notch Photos folder")

                Button {
                    camera.stop()
                    vm.close()
                    KhmerStampPanelController.shared.show()
                } label: {
                    Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Khmer stamp photo booth (3 or 4 photos)")
            }
        }
        .frame(width: 220)
    }

    // MARK: - Actions

    private func cycleCountdown() {
        let options = [0, 3, 5, 10]
        let index = options.firstIndex(of: countdownSetting) ?? 0
        countdownSetting = options[(index + 1) % options.count]
    }

    private func shoot() {
        guard !isCapturing, camera.status == .running else { return }
        isCapturing = true
        message = nil

        // Keep the notch open through the countdown even if the pointer drifts away.
        SharingStateManager.shared.beginInteraction()

        captureTask = Task { @MainActor in
            defer {
                isCapturing = false
                SharingStateManager.shared.endInteraction()
            }

            let seconds = Defaults[.photoBoothCountdown]
            if seconds > 0 {
                for n in stride(from: seconds, to: 0, by: -1) {
                    withAnimation(.smooth(duration: 0.25)) { countdown = n }
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled {
                        countdown = nil
                        return
                    }
                }
                withAnimation(.smooth(duration: 0.2)) { countdown = nil }
            }

            PhotoBoothSound.playShutter()
            if Defaults[.photoBoothFlash] {
                flash = true
            }

            let saved = await camera.takePhoto()

            withAnimation(.easeOut(duration: 0.45)) { flash = false }

            if let saved {
                if Defaults[.photoBoothAddToShelf], let bookmark = try? Bookmark(url: saved) {
                    ShelfStateViewModel.shared.add([ShelfItem(kind: .file(bookmark: bookmark.data), isTemporary: false)])
                    showMessage("Saved · added to Shelf")
                } else {
                    showMessage("Saved to Pictures")
                }
            } else {
                showMessage("Couldn't save the photo")
            }
        }
    }

    private func showMessage(_ text: String) {
        withAnimation(.smooth) { message = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if message == text {
                withAnimation(.smooth) { message = nil }
            }
        }
    }
}

// MARK: - Recent photos

private struct RecentPhotosGrid: View {
    let photos: [URL]

    var body: some View {
        if photos.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 18))
                    .foregroundStyle(.gray)
                Text("Your photos\nappear here")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.fixed(72), spacing: 6), GridItem(.fixed(72), spacing: 6)], spacing: 6) {
                    ForEach(photos, id: \.self) { url in
                        PhotoThumbnail(url: url)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PhotoThumbnail: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.08))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .frame(width: 72, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture { NSWorkspace.shared.open(url) }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("Add to Shelf") {
                if let bookmark = try? Bookmark(url: url) {
                    ShelfStateViewModel.shared.add([ShelfItem(kind: .file(bookmark: bookmark.data), isTemporary: false)])
                }
            }
        }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .help(url.lastPathComponent)
        .task(id: url) {
            let target = url
            image = await Task.detached(priority: .utility) {
                PhotoBoothCamera.thumbnail(for: target, maxPixelSize: 160)
            }.value
        }
    }
}

// MARK: - Sound

enum PhotoBoothSound {
    private static var player: NSSound?

    static func playShutter() {
        if player == nil {
            let candidates = [
                "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Shutter.aif",
                "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Grab.aif",
            ]
            if let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                player = NSSound(contentsOfFile: path, byReference: true)
            } else {
                player = NSSound(named: NSSound.Name("Tink"))
            }
        }
        player?.stop()
        player?.play()
    }
}
