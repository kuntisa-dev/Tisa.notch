//
//  PhotoBoothView.swift
//  TisaDynamicIsland
//
//  The Photo Booth tab: live preview with effects, countdown, flash,
//  and the most recent photos. Photos go to ~/Pictures/Tisa Dynamic Island Photos.
//  In Photo Booth mode the tab first shows a style picker (format, background,
//  filter) with a live sample that puts the camera in every window. Start takes
//  3 or 4 photos while the picture fills in, then renders it (see
//  PhotoBoothStyles.swift) and saves it as a PNG in the same folder.
//

import AppKit
import Defaults
import SwiftUI

enum PhotoBoothMode: String, CaseIterable, Identifiable, Defaults.Serializable {
    case photo
    case booth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: return "Photo"
        case .booth: return "Photo Booth"
        }
    }
}

private struct BoothResult {
    let image: CGImage
    let url: URL?
}

struct PhotoBoothView: View {
    @EnvironmentObject var vm: TisaViewModel
    @ObservedObject private var camera = PhotoBoothCamera.shared
    @Default(.photoBoothCountdown) private var countdownSetting
    @Default(.photoBoothMode) private var mode
    @Default(.largeNotch) private var largeNotch
    @Default(.boothPhotoCount) private var boothPhotoCount
    @Default(.boothCountdown) private var boothCountdown
    @Default(.boothFormat) private var boothFormat
    @Default(.boothBackground) private var boothBackground
    @Default(.boothFilter) private var boothFilter
    @Default(.boothBackdrop) private var boothBackdrop

    @State private var countdown: Int?
    @State private var flash = false
    @State private var isCapturing = false
    @State private var captureTask: Task<Void, Never>?
    @State private var message: String?
    @State private var boothShot = 0
    @State private var boothResult: BoothResult?
    /// Full-size photos from the last Photo Booth session, kept until the user retakes.
    @State private var boothPhotos: [CGImage]?
    @State private var boothSamplePhotos: [CGImage] = []
    @State private var boothSample: CGImage?
    @State private var isCreating = false
    @State private var holdingNotch = false
    /// Downscaled photos taken so far in the running session, for the live sample.
    @State private var boothTaken: [CGImage] = []
    /// The chosen style with the camera in the windows not yet taken.
    @State private var liveSample: CGImage?
    /// Person masks of the photos taken, in order, for the backdrop. Made at capture so
    /// "Change style" can switch the backdrop without redoing them.
    @State private var boothMasks: [CGImage?] = []
    /// The camera with the backdrop behind the person, shown while shooting.
    @State private var liveBackdropFrame: CGImage?

    /// The preview fills the tab's height. In Photo Booth mode it's wider, so the sample is easy to see.
    private var previewWidth: CGFloat {
        if mode == .booth { return largeNotch ? 260 : 224 }
        return largeNotch ? 220 : 184
    }
    private let boothAccent = Color(red: 0.64, green: 0.86, blue: 0.73)

    /// Stands in for photos not taken yet in the live sample.
    private static let emptySlot: CGImage? = {
        let context = CGContext(data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.setFillColor(CGColor(gray: 0.32, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        return context?.makeImage()
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            preview
            if mode == .photo {
                controls
                RecentPhotosGrid(photos: camera.recentPhotos)
            } else if boothResult != nil {
                RecentPhotosGrid(photos: camera.recentPhotos)
            } else if isCapturing {
                boothCapturePanel
                    .transition(.opacity)
            } else {
                stylePicker
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: LiveSampleKey(style: currentStyle, count: boothCaptureCount, active: showsLiveSample)) {
            await runLiveSample()
        }
        .onAppear {
            // The Home tab's mirror and this tab never show together; make sure the mirror lets go.
            WebcamManager.shared.stopSession()
            camera.refreshRecentPhotos()
            camera.start()
        }
        .onDisappear {
            captureTask?.cancel()
            camera.stop()
            holdNotch(false)
        }
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.08))

            if let boothResult {
                boothResultView(boothResult)
            } else if boothPhotos != nil {
                boothSampleView
            } else if mode == .booth && !isCapturing {
                liveSampleView
            } else {
                if let image = cameraImage {
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

                if mode == .booth, let artwork = boothFormat.artwork, camera.previewImage != nil {
                    // The center crop each poster window will use, so the camera and the poster match.
                    FramingGuide(aspect: artwork.slotAspect)
                }

                if mode == .booth && isCapturing && boothShot > 0 {
                    Text("PHOTO \(boothShot) OF \(boothCaptureCount)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(boothAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 6)
                }

                if !isCapturing && camera.previewImage != nil {
                    modePicker
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 6)
                }
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
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 6)
                    .transition(.opacity)
            }
        }
        .frame(width: previewWidth)
        .frame(maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            if mode == .booth {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(boothAccent.opacity(0.8), lineWidth: 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if boothResult == nil && boothPhotos == nil && !isCapturing { shoot() }
        }
        .help(mode == .photo
              ? "Click or press the shutter to take a photo"
              : "Click to take \(boothCaptureCount) photos in this style")
    }

    /// While shooting with a backdrop, the camera with the backdrop behind the person.
    private var cameraImage: CGImage? {
        if mode == .booth && isCapturing && boothBackdrop != .off, let liveBackdropFrame {
            return liveBackdropFrame
        }
        return camera.previewImage
    }

    /// Photo Booth mode before shooting: the chosen style with the live camera in every window.
    private var liveSampleView: some View {
        ZStack {
            if camera.previewImage == nil {
                statusPlaceholder
            } else {
                if let liveSample {
                    Image(decorative: liveSample, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(6)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
                // A small switch in the corner, so the sample gets the whole frame.
                compactModePicker
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(6)
            }
        }
    }

    /// Photo / Photo Booth switch, like the mode picker in a phone camera.
    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(PhotoBoothMode.allCases) { option in
                Button {
                    withAnimation(.smooth(duration: 0.2)) {
                        mode = option
                        message = nil
                    }
                } label: {
                    Text(option.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(mode == option ? .black : .white)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(
                            Capsule().fill(mode == option ? (option == .booth ? boothAccent : .white) : .clear)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(.black.opacity(0.6)))
    }

    /// Photo / Photo Booth as two icons, for the corner of the Photo Booth sample.
    private var compactModePicker: some View {
        HStack(spacing: 2) {
            ForEach(PhotoBoothMode.allCases) { option in
                Button {
                    withAnimation(.smooth(duration: 0.2)) {
                        mode = option
                        message = nil
                    }
                } label: {
                    Image(systemName: option == .photo ? "camera.fill" : "square.grid.2x2.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(mode == option ? .black : .white)
                        .frame(width: 24, height: 20)
                        .background(
                            Capsule().fill(mode == option ? (option == .booth ? boothAccent : .white) : .clear)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(option.title)
            }
        }
        .padding(2)
        .background(Capsule().fill(.black.opacity(0.6)))
    }

    private func boothResultView(_ result: BoothResult) -> some View {
        HStack(spacing: 10) {
            Image(decorative: result.image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(.vertical, 8)
                .onTapGesture { openBoothResult(result) }

            VStack(alignment: .leading, spacing: 6) {
                Text(result.url == nil ? "Not saved" : "Saved to Pictures")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(boothAccent)
                    .fixedSize(horizontal: false, vertical: true)

                resultButton("Open", prominent: true) { openBoothResult(result) }
                    .disabled(result.url == nil)
                    .help("Saved in Pictures › Tisa Dynamic Island Photos")

                if boothPhotos != nil {
                    resultButton("Change style") {
                        withAnimation(.smooth) { boothResult = nil }
                        holdNotch(true)
                    }
                    .help("Make another picture from the same photos")
                }

                resultButton("Take again") {
                    withAnimation(.smooth) { resetBooth() }
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .transition(.opacity)
    }

    private func resultButton(_ title: LocalizedStringKey, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: prominent ? .semibold : .medium))
                .foregroundStyle(prominent ? .black : .white)
                .frame(width: 88, height: 24)
                .background(Capsule().fill(prominent ? boothAccent : Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Style picker

    private var currentStyle: BoothStyle {
        BoothStyle(format: boothFormat, background: boothBackground, filter: boothFilter, backdrop: boothBackdrop)
    }

    /// Live sample of the chosen style, shown where the camera preview was.
    private var boothSampleView: some View {
        ZStack {
            if let boothSample {
                Image(decorative: boothSample, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
                    .shadow(color: .black.opacity(0.4), radius: 4)
            } else if let artwork = boothFormat.artwork {
                Image(decorative: artwork.original, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
            }
            if boothSample == nil || isCreating {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .task(id: currentStyle) {
            let photos = boothSamplePhotos
            let masks = boothMasks
            let style = currentStyle
            guard !photos.isEmpty else { return }
            let image = await Task.detached(priority: .userInitiated) {
                BoothRenderer.render(style, photos: photos, masks: masks, scale: style.format.sampleScale)
            }.value
            if !Task.isCancelled {
                boothSample = image
            }
        }
    }

    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            styleRow("Format") {
                ForEach(BoothCategory.allCases) { category in
                    let formats = BoothFormat.available.filter { $0.category == category }
                    if !formats.isEmpty {
                        Text(category.title.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.gray)
                            .padding(.leading, category == .classic ? 0 : 6)
                        ForEach(formats) { format in
                            formatChip(format)
                        }
                    }
                }
            }

            styleRow("Background") {
                ForEach(BoothBackground.allCases) { background in
                    Button {
                        boothBackground = background
                    } label: {
                        Group {
                            if let swatch = BoothRenderer.swatches[background] {
                                Image(decorative: swatch, scale: 1)
                                    .resizable()
                            } else {
                                Color.gray
                            }
                        }
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                        .padding(3)
                        .overlay(
                            Circle().strokeBorder(boothBackground == background ? boothAccent : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(background.title)
                }
            }
            .disabled(!boothFormat.usesBackground)
            .opacity(boothFormat.usesBackground ? 1 : 0.35)
            .help(boothFormat.usesBackground ? "" : "This format has its own paper")

            styleRow("Filter") {
                ForEach(BoothFilter.allCases) { filter in
                    styleChip(selected: boothFilter == filter) {
                        boothFilter = filter
                    } label: {
                        Text(filter.title)
                    }
                }
            }

            if boothPhotos == nil {
                startBar
            } else {
                restyleBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Before shooting: how many photos, the countdown, and Start.
    private var startBar: some View {
        HStack(spacing: 8) {
            photoCountPicker
            timerButton
            backdropButton

            Spacer(minLength: 0)

            Button(action: shoot) {
                Label("Take \(boothCaptureCount) photos", systemImage: "camera.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(Capsule().fill(boothAccent))
            }
            .buttonStyle(.plain)
            .disabled(camera.status != .running)
            .opacity(camera.status == .running ? 1 : 0.4)
            .help("Take \(boothCaptureCount) photos, each after a \(boothCountdown) s countdown, in this style")
        }
    }

    @ViewBuilder
    private var photoCountPicker: some View {
        if let fixed = boothFormat.requiredPhotoCount {
            Text("\(fixed) photos")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.gray)
                .padding(.horizontal, 6)
                .help("\(boothFormat.title) always uses \(fixed) photos")
        } else {
            HStack(spacing: 2) {
                ForEach([3, 4], id: \.self) { count in
                    Button {
                        boothPhotoCount = count
                    } label: {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(boothPhotoCount == count ? .black : .white)
                            .frame(width: 24, height: 24)
                            .background(Capsule().fill(boothPhotoCount == count ? boothAccent : .clear))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Capsule().fill(Color.white.opacity(0.1)))
            .help("Number of photos")
        }
    }

    /// Off → Blur → Match → Studio: what goes behind the person.
    private var backdropButton: some View {
        Button {
            let options = BoothBackdrop.allCases
            let index = options.firstIndex(of: boothBackdrop) ?? 0
            boothBackdrop = options[(index + 1) % options.count]
        } label: {
            HStack(spacing: 3) {
                Image(systemName: boothBackdrop.symbol)
                Text(boothBackdrop.title)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(boothBackdrop == .off ? .white : boothAccent)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Capsule().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .disabled(isCreating)
        .help("Backdrop: \(boothBackdrop.summary(for: currentStyle)). Press for the next one (Off, Blur, Match, Studio)")
    }

    /// After "Change style": same photos, new style.
    private var restyleBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.smooth) { resetBooth() }
            } label: {
                Label("Retake", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .disabled(isCreating)
            .help("Discard these photos and pick a style to shoot again")

            backdropButton

            Spacer(minLength: 0)

            Button(action: createBoothPicture) {
                Label("Create", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 28)
                    .background(Capsule().fill(boothAccent))
            }
            .buttonStyle(.plain)
            .disabled(isCreating)
            .help("Make the picture and save it to Pictures")
        }
    }

    /// While shooting: the picture filling in, photo by photo, with the camera in the next window.
    private var boothCapturePanel: some View {
        HStack(spacing: 14) {
            ZStack {
                if let liveSample {
                    Image(decorative: liveSample, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: 220, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                Text(boothShot > 0 ? "PHOTO \(boothShot) OF \(boothCaptureCount)" : "MAKING YOUR PICTURE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(boothAccent)
                Text(styleSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)

                if boothShot > 0 {
                    Button {
                        captureTask?.cancel()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Stop and go back to the styles")
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var styleSummary: String {
        var parts = [boothFormat.title]
        if boothFormat.usesBackground { parts.append(boothBackground.title) }
        parts.append(boothFilter.title)
        return parts.joined(separator: " · ")
    }

    private func formatChip(_ format: BoothFormat) -> some View {
        // Before shooting every format fits; afterwards only those that take this many photos.
        let fits = boothPhotos == nil || (format.requiredPhotoCount.map { $0 == boothPhotos?.count } ?? true)
        return styleChip(selected: boothFormat == format) {
            boothFormat = format
        } label: {
            HStack(spacing: 4) {
                Image(systemName: format.symbol)
                Text(format.title)
            }
        }
        .disabled(!fits)
        .opacity(fits ? 1 : 0.35)
        .help(fits ? "" : "Needs \(format.requiredPhotoCount ?? 4) photos. Press Retake and pick \(format.title) before you shoot.")
    }

    private func styleRow<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.gray)
                .frame(width: 66, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    content()
                }
            }
        }
        .frame(height: 24)
    }

    private func styleChip<ChipLabel: View>(selected: Bool, action: @escaping () -> Void,
                                            @ViewBuilder label: () -> ChipLabel) -> some View {
        Button(action: action) {
            label()
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(selected ? .black : .white)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule().fill(selected ? boothAccent : Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
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
                timerButton

                Button {
                    if isCapturing {
                        captureTask?.cancel()
                    } else {
                        shoot()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 50, height: 50)
                        if isCapturing {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.red)
                                .frame(width: 20, height: 20)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(camera.status != .running)
                .opacity(camera.status == .running ? 1 : 0.4)
                .help(isCapturing ? "Stop" : "Take a photo")

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
                .help("Open the Tisa Dynamic Island Photos folder")
            }
        }
        .frame(width: 220)
    }

    /// Photo mode: Off/3/5/10 s. Photo Booth mode: 3/5/8 s before each photo.
    private var timerButton: some View {
        let seconds = mode == .photo ? countdownSetting : boothCountdown
        return Button {
            cycleCountdown()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "timer")
                Text(seconds == 0 ? "Off" : "\(seconds)s")
                    .monospacedDigit()
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(seconds == 0 ? .gray : .white)
            .frame(width: 52, height: 28)
            .background(Capsule().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
        .help(mode == .photo ? "Countdown before the photo" : "Countdown before each photo")
    }

    /// Photos per Photo Booth session: an artwork template's window count, else the 3/4 setting.
    private var boothCaptureCount: Int {
        boothFormat.requiredPhotoCount ?? boothPhotoCount
    }

    // MARK: - Live sample

    private struct LiveSampleKey: Equatable {
        let style: BoothStyle
        let count: Int
        let active: Bool
    }

    /// Photo Booth mode until the photos are all in: choosing a style, or shooting.
    private var showsLiveSample: Bool {
        mode == .booth && boothPhotos == nil && boothResult == nil
    }

    /// Largest live sample worth drawing, in pixels: it shows at most 260 × 180 pt (Retina 2×).
    private static let liveSampleMaxPixels = CGSize(width: 520, height: 360)

    /// Re-renders the live sample at the camera's 30 fps while it shows. Photos are
    /// shrunk to 240 px and the picture is drawn only as large as it is shown.
    private func runLiveSample() async {
        // When it stops, the last render stays up while the picture is made.
        guard showsLiveSample else { return }
        let frameTime = Duration.seconds(1) / 30
        let clock = ContinuousClock()
        // Starts at the format's sample size and shrinks to the shown size after the first render.
        var scale = currentStyle.format.sampleScale
        var lastFrame: CGImage?
        var lastTaken = -1
        while !Task.isCancelled {
            let started = clock.now
            let frame = camera.previewImage
            if frame !== lastFrame || boothTaken.count != lastTaken, let photos = livePhotos(frame: frame) {
                lastFrame = frame
                lastTaken = boothTaken.count
                let style = currentStyle
                let renderScale = scale
                let takenMasks = boothMasks
                let capturing = isCapturing
                let (image, backdropFrame) = await Task.detached(priority: .userInitiated) {
                    // One person mask per camera frame, shared by every window that shows it.
                    var liveMask: CGImage?
                    if style.backdrop != .off, let frame {
                        liveMask = BoothBackdropCompositor.personMask(for: frame, quality: .live)
                    }
                    let masks: [CGImage?] = photos.indices.map { index in
                        if photos[index] === frame { return liveMask }
                        return index < takenMasks.count ? takenMasks[index] : nil
                    }
                    // Before shooting every window holds the same frame; shrink it once.
                    var shrunk: [ObjectIdentifier: CGImage] = [:]
                    let small = photos.map { photo in
                        let key = ObjectIdentifier(photo)
                        if let done = shrunk[key] { return done }
                        let done = BoothRenderer.downscaled(photo, maxWidth: 240)
                        shrunk[key] = done
                        return done
                    }
                    var backdropFrame: CGImage?
                    if capturing, style.backdrop != .off, let frame {
                        backdropFrame = BoothBackdropCompositor.apply(style.backdrop, style: style, to: frame, mask: liveMask)
                    }
                    return (BoothRenderer.render(style, photos: small, masks: masks, scale: renderScale), backdropFrame)
                }.value
                if Task.isCancelled { return }
                liveSample = image
                liveBackdropFrame = backdropFrame
                if let image {
                    let fit = min(Self.liveSampleMaxPixels.width / CGFloat(image.width),
                                  Self.liveSampleMaxPixels.height / CGFloat(image.height))
                    if fit < 1 { scale *= fit }
                }
            }
            try? await clock.sleep(until: started + frameTime)
        }
    }

    /// Before shooting the camera fills every window. While shooting: the photos taken,
    /// the camera in the next window, gray in the rest.
    private func livePhotos(frame: CGImage?) -> [CGImage]? {
        let count = boothCaptureCount
        var photos = Array(boothTaken.prefix(count))
        guard photos.count < count else { return photos }
        guard let frame, let empty = Self.emptySlot else { return nil }
        if !isCapturing {
            return Array(repeating: frame, count: count)
        }
        photos.append(frame)
        photos += Array(repeating: empty, count: count - photos.count)
        return photos
    }

    // MARK: - Actions

    private func cycleCountdown() {
        if mode == .photo {
            let options = [0, 3, 5, 10]
            let index = options.firstIndex(of: countdownSetting) ?? 0
            countdownSetting = options[(index + 1) % options.count]
        } else {
            let options = [3, 5, 8]
            let index = options.firstIndex(of: boothCountdown) ?? 0
            boothCountdown = options[(index + 1) % options.count]
        }
    }

    private func shoot() {
        guard !isCapturing, camera.status == .running else { return }
        switch mode {
        case .photo: shootPhoto()
        case .booth: shootBooth()
        }
    }

    private func shootPhoto() {
        isCapturing = true
        message = nil

        // Keep the notch open through the countdown even if the pointer drifts away.
        SharingStateManager.shared.beginInteraction()

        captureTask = Task { @MainActor in
            defer {
                isCapturing = false
                SharingStateManager.shared.endInteraction()
            }

            guard await runCountdown(from: Defaults[.photoBoothCountdown]) else { return }

            startFlash()
            let saved = await camera.takePhoto()
            endFlash()

            if let saved {
                showMessage(addToShelfIfWanted(saved) ? "Saved · added to Shelf" : "Saved to Pictures")
            } else {
                showMessage("Couldn't save the photo")
            }
        }
    }

    private func shootBooth() {
        let layout = StampLayout(rawValue: boothCaptureCount) ?? .three
        let seconds = boothCountdown
        isCapturing = true
        message = nil
        resetBooth()
        liveBackdropFrame = nil

        // 4 photos with 8 s timers takes over half a minute; keep the notch open.
        SharingStateManager.shared.beginInteraction()

        captureTask = Task { @MainActor in
            defer {
                isCapturing = false
                boothShot = 0
                boothTaken = []
                SharingStateManager.shared.endInteraction()
            }

            var photos: [CGImage] = []
            for shot in 1...layout.rawValue {
                boothShot = shot
                guard await runCountdown(from: seconds) else { return }

                startFlash()
                let photo = await camera.captureFrame()
                endFlash()

                guard let photo else {
                    showMessage("Couldn't take photo \(shot)")
                    return
                }
                photos.append(photo)

                // The live sample fills this window with the photo just taken. The mask is
                // made even with the backdrop off, so "Change style" can turn it on later.
                let (small, mask) = await Task.detached(priority: .userInitiated) {
                    (BoothRenderer.downscaled(photo), BoothBackdropCompositor.personMask(for: photo, quality: .final))
                }.value
                guard !Task.isCancelled else { return }
                boothMasks.append(mask)
                boothTaken.append(small)
            }
            boothShot = 0

            // Kept for "Change style", which reuses the photos.
            boothSamplePhotos = boothTaken
            boothPhotos = photos
            await makeBoothPicture(from: photos)
        }
    }

    private func createBoothPicture() {
        guard let photos = boothPhotos, !isCreating else { return }
        Task { @MainActor in
            await makeBoothPicture(from: photos)
        }
    }

    /// Renders the picture in the current style, saves it and shows the result.
    private func makeBoothPicture(from photos: [CGImage]) async {
        let style = currentStyle
        let masks = boothMasks
        isCreating = true
        defer { isCreating = false }

        let artwork = await Task.detached(priority: .userInitiated) {
            BoothRenderer.render(style, photos: photos, masks: masks, scale: style.format.outputScale)
        }.value
        guard let artwork else {
            // The style picker stays up with these photos, so Create can try again.
            showMessage("Couldn't make the picture")
            return
        }

        let saved = await camera.saveBoothPicture(artwork)
        if let saved {
            _ = addToShelfIfWanted(saved)
        } else {
            showMessage("Couldn't save the picture")
        }
        withAnimation(.smooth) { boothResult = BoothResult(image: artwork, url: saved) }
        holdNotch(false)
    }

    /// Drops the current Photo Booth photos and picture and goes back to the camera.
    private func resetBooth() {
        boothResult = nil
        boothPhotos = nil
        boothSamplePhotos = []
        boothMasks = []
        boothSample = nil
        holdNotch(false)
    }

    private func holdNotch(_ hold: Bool) {
        guard hold != holdingNotch else { return }
        holdingNotch = hold
        if hold {
            SharingStateManager.shared.beginInteraction()
        } else {
            SharingStateManager.shared.endInteraction()
        }
    }

    /// Counts down on the preview. Returns false if the capture was cancelled.
    private func runCountdown(from seconds: Int) async -> Bool {
        guard seconds > 0 else { return !Task.isCancelled }
        for n in stride(from: seconds, to: 0, by: -1) {
            withAnimation(.smooth(duration: 0.25)) { countdown = n }
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled {
                countdown = nil
                return false
            }
        }
        withAnimation(.smooth(duration: 0.2)) { countdown = nil }
        return true
    }

    private func startFlash() {
        PhotoBoothSound.playShutter()
        if Defaults[.photoBoothFlash] {
            flash = true
        }
    }

    private func endFlash() {
        withAnimation(.easeOut(duration: 0.45)) { flash = false }
    }

    /// Adds the file to the Shelf when that setting is on. Returns whether it did.
    private func addToShelfIfWanted(_ url: URL) -> Bool {
        guard Defaults[.photoBoothAddToShelf], let bookmark = try? Bookmark(url: url) else { return false }
        ShelfStateViewModel.shared.add([ShelfItem(kind: .file(bookmark: bookmark.data), isTemporary: false)])
        return true
    }

    private func openBoothResult(_ result: BoothResult) {
        guard let url = result.url else { return }
        NSWorkspace.shared.open(url)
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


// MARK: - Framing guide

/// Dims the camera preview outside a centered window of `aspect` (width ÷ height).
/// Photos are center-cropped to that shape, so this is exactly what lands in the poster.
private struct FramingGuide: View {
    let aspect: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let window = min(geometry.size.width, geometry.size.height * aspect)
            HStack(spacing: 0) {
                Color.black.opacity(0.5)
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.white.opacity(0.75), lineWidth: 1)
                    .frame(width: window)
                Color.black.opacity(0.5)
            }
        }
        .allowsHitTesting(false)
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
