//
//  PhotoBoothCamera.swift
//  boringNotch
//
//  Camera engine for the Photo Booth tab. Frames from AVCaptureVideoDataOutput
//  go through Core Image (mirror, 4:3 crop, effect) and are published as a
//  small preview image. Taking a photo renders the newest frame at full
//  resolution and saves it as a JPEG in ~/Pictures/Tisa Notch Photos.
//
//  Uses its own capture session so the Home tab's mirror is untouched.
//

import AppKit
import AVFoundation
import CoreImage
import Darwin
import ImageIO
import UniformTypeIdentifiers

enum PhotoBoothEffect: String, CaseIterable, Identifiable {
    // Color looks
    case normal, mono, noir, sepia, chrome, vintage, fade, glow, popArt, comic, thermal, xray
    // Patterns
    case pixelate, halftone
    // Distortions
    case mirror, kaleidoscope, lightTunnel, bulge, pinch, twirl

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return "Normal"
        case .mono: return "Mono"
        case .noir: return "Noir"
        case .sepia: return "Sepia"
        case .chrome: return "Chrome"
        case .vintage: return "Vintage"
        case .fade: return "Fade"
        case .glow: return "Glow"
        case .popArt: return "Pop Art"
        case .comic: return "Comic"
        case .thermal: return "Thermal"
        case .xray: return "X-Ray"
        case .pixelate: return "Pixelate"
        case .halftone: return "Halftone"
        case .mirror: return "Mirror"
        case .kaleidoscope: return "Kaleidoscope"
        case .lightTunnel: return "Light Tunnel"
        case .bulge: return "Bulge"
        case .pinch: return "Pinch"
        case .twirl: return "Twirl"
        }
    }

    /// Sizes are relative to the image, so the live preview (480 px wide) and the
    /// saved photo (full resolution) look the same.
    func apply(to input: CIImage) -> CIImage {
        let extent = input.extent
        let center = CIVector(x: extent.midX, y: extent.midY)
        let radius = min(extent.width, extent.height) * 0.5

        let filter: CIFilter?
        switch self {
        case .normal:
            return input

        // MARK: Color looks
        case .mono:
            filter = CIFilter(name: "CIPhotoEffectMono")
        case .noir:
            filter = CIFilter(name: "CIPhotoEffectNoir")
        case .chrome:
            filter = CIFilter(name: "CIPhotoEffectChrome")
        case .vintage:
            filter = CIFilter(name: "CIPhotoEffectTransfer")
        case .fade:
            filter = CIFilter(name: "CIPhotoEffectFade")
        case .sepia:
            filter = CIFilter(name: "CISepiaTone")
            filter?.setValue(0.9, forKey: kCIInputIntensityKey)
        case .glow:
            // Blur reads past the edges, so extend the edge pixels first to avoid dark borders.
            filter = CIFilter(name: "CIBloom")
            filter?.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
            filter?.setValue(extent.width / 40, forKey: kCIInputRadiusKey)
            filter?.setValue(1.0, forKey: kCIInputIntensityKey)
            return (filter?.outputImage ?? input).cropped(to: extent)
        case .popArt:
            return popArt(input)
        case .comic:
            filter = CIFilter(name: "CIComicEffect")
        case .thermal:
            filter = CIFilter(name: "CIThermal")
        case .xray:
            filter = CIFilter(name: "CIXRay")

        // MARK: Patterns
        case .pixelate:
            filter = CIFilter(name: "CIPixellate")
            filter?.setValue(center, forKey: kCIInputCenterKey)
            filter?.setValue(max(4, extent.width / 48), forKey: kCIInputScaleKey)
        case .halftone:
            filter = CIFilter(name: "CIDotScreen")
            filter?.setValue(center, forKey: kCIInputCenterKey)
            filter?.setValue(0.0, forKey: kCIInputAngleKey)
            filter?.setValue(max(3, extent.width / 80), forKey: kCIInputWidthKey)
            filter?.setValue(0.7, forKey: kCIInputSharpnessKey)

        // MARK: Distortions
        case .mirror:
            return mirror(input)
        case .kaleidoscope:
            filter = CIFilter(name: "CIKaleidoscope")
            filter?.setValue(center, forKey: kCIInputCenterKey)
            filter?.setValue(6, forKey: "inputCount")
            filter?.setValue(0.0, forKey: kCIInputAngleKey)
        case .lightTunnel:
            filter = CIFilter(name: "CILightTunnel")
            filter?.setValue(center, forKey: kCIInputCenterKey)
            filter?.setValue(radius * 0.45, forKey: kCIInputRadiusKey)
            filter?.setValue(2.0, forKey: "inputRotation")
        case .bulge:
            filter = CIFilter(name: "CIBumpDistortion")
            filter?.setValue(center, forKey: kCIInputCenterKey)
            filter?.setValue(radius, forKey: kCIInputRadiusKey)
            filter?.setValue(0.6, forKey: kCIInputScaleKey)
        case .pinch:
            filter = CIFilter(name: "CIPinchDistortion")
            filter?.setValue(center, forKey: kCIInputCenterKey)
            filter?.setValue(radius, forKey: kCIInputRadiusKey)
            filter?.setValue(0.6, forKey: kCIInputScaleKey)
        case .twirl:
            filter = CIFilter(name: "CITwirlDistortion")
            filter?.setValue(center, forKey: kCIInputCenterKey)
            filter?.setValue(radius, forKey: kCIInputRadiusKey)
            filter?.setValue(2.5, forKey: kCIInputAngleKey)
        }

        guard let filter else { return input }
        filter.setValue(input, forKey: kCIInputImageKey)
        return (filter.outputImage ?? input).cropped(to: extent)
    }

    /// Bold, flat colors: boost saturation, then reduce to a few levels per channel.
    private func popArt(_ input: CIImage) -> CIImage {
        guard let saturate = CIFilter(name: "CIColorControls"),
              let posterize = CIFilter(name: "CIColorPosterize") else { return input }
        saturate.setValue(input, forKey: kCIInputImageKey)
        saturate.setValue(1.8, forKey: kCIInputSaturationKey)
        saturate.setValue(1.15, forKey: kCIInputContrastKey)
        posterize.setValue(saturate.outputImage ?? input, forKey: kCIInputImageKey)
        posterize.setValue(5, forKey: "inputLevels")
        return (posterize.outputImage ?? input).cropped(to: input.extent)
    }

    /// Classic Photo Booth mirror: the left half, reflected onto the right.
    private func mirror(_ input: CIImage) -> CIImage {
        let extent = input.extent
        let leftHalf = input.cropped(to: CGRect(x: extent.minX, y: extent.minY, width: extent.width / 2, height: extent.height))
        // Reflect across the vertical center line: x' = 2·midX − x.
        let reflect = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 2 * extent.midX, ty: 0)
        return leftHalf.transformed(by: reflect)
            .composited(over: leftHalf)
            .cropped(to: extent)
    }
}

final class PhotoBoothCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    static let shared = PhotoBoothCamera()

    enum Status: Equatable {
        case idle
        case starting
        case running
        case needsPermission
        case noCamera
        case failed(String)
    }

    // Published on the main thread.
    @Published private(set) var previewImage: CGImage?
    @Published private(set) var status: Status = .idle
    @Published private(set) var recentPhotos: [URL] = []
    @Published var effect: PhotoBoothEffect = .normal {
        didSet { setEffectForVideoQueue(effect) }
    }

    private let sessionQueue = DispatchQueue(label: "boringNotch.photoBooth.session")
    private let videoQueue = DispatchQueue(label: "boringNotch.photoBooth.video", qos: .userInitiated)
    private var session: AVCaptureSession?
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    // Shared between the video queue and other threads.
    private let lock = NSLock()
    private var latestPixelBuffer: CVPixelBuffer?
    private var videoQueueEffect: PhotoBoothEffect = .normal
    private var lastPreviewTime: CFTimeInterval = 0

    private let previewMaxWidth: CGFloat = 480
    private let previewInterval: CFTimeInterval = 1.0 / 30.0

    /// ~/Pictures/Tisa Notch Photos. Inside the sandbox FileManager's home is the app
    /// container, so read the real home from the user database
    /// (access comes from the com.apple.security.assets.pictures.read-write entitlement).
    let photosFolder: URL = {
        var home = FileManager.default.homeDirectoryForCurrentUser
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            home = URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return home
            .appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent("Tisa Notch Photos", isDirectory: true)
    }()

    private override init() {
        super.init()
        refreshRecentPhotos()
    }

    // MARK: - Session

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            setStatus(.starting)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.start()
                } else {
                    self?.setStatus(.needsPermission)
                }
            }
            return
        default:
            setStatus(.needsPermission)
            return
        }

        setStatus(.starting)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if let session = self.session {
                if !session.isRunning { session.startRunning() }
                self.setStatus(.running)
                return
            }

            let devices = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .external],
                mediaType: .video,
                position: .unspecified
            ).devices
            guard let device = devices.first else {
                self.setStatus(.noCamera)
                return
            }

            do {
                let session = AVCaptureSession()
                session.beginConfiguration()
                session.sessionPreset = .high

                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else { throw CameraError.cannotAdd("input") }
                session.addInput(input)

                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.setSampleBufferDelegate(self, queue: self.videoQueue)
                guard session.canAddOutput(output) else { throw CameraError.cannotAdd("output") }
                session.addOutput(output)

                session.commitConfiguration()
                session.startRunning()
                self.session = session
                self.setStatus(.running)
            } catch {
                self.setStatus(.failed(error.localizedDescription))
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session?.stopRunning()
            // Drop the session so the camera light turns off and the device is released.
            self.session = nil
            self.lock.lock()
            self.latestPixelBuffer = nil
            self.lock.unlock()
            DispatchQueue.main.async {
                self.previewImage = nil
                if self.status == .running || self.status == .starting {
                    self.status = .idle
                }
            }
        }
    }

    private enum CameraError: LocalizedError {
        case cannotAdd(String)
        var errorDescription: String? {
            switch self {
            case .cannotAdd(let part): return "The camera \(part) could not be added."
            }
        }
    }

    private func setStatus(_ newStatus: Status) {
        DispatchQueue.main.async { self.status = newStatus }
    }

    private func setEffectForVideoQueue(_ effect: PhotoBoothEffect) {
        lock.lock()
        videoQueueEffect = effect
        lock.unlock()
    }

    // MARK: - Frames (video queue)

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        lock.lock()
        latestPixelBuffer = pixelBuffer
        let effect = videoQueueEffect
        lock.unlock()

        let now = CACurrentMediaTime()
        guard now - lastPreviewTime >= previewInterval else { return }
        lastPreviewTime = now

        let image = render(CIImage(cvPixelBuffer: pixelBuffer), effect: effect, maxWidth: previewMaxWidth)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.previewImage = cgImage
        }
    }

    /// Mirror like a mirror, crop to 4:3, optionally downscale, then apply the effect.
    private func render(_ source: CIImage, effect: PhotoBoothEffect, maxWidth: CGFloat?) -> CIImage {
        var image = source.oriented(.upMirrored)

        let extent = image.extent
        let targetAspect: CGFloat = 4.0 / 3.0
        var crop = extent
        if extent.width / extent.height > targetAspect {
            crop.size.width = extent.height * targetAspect
            crop.origin.x = extent.midX - crop.width / 2
        } else {
            crop.size.height = extent.width / targetAspect
            crop.origin.y = extent.midY - crop.height / 2
        }
        image = image.cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: -crop.origin.x, y: -crop.origin.y))

        if let maxWidth, image.extent.width > maxWidth {
            let scale = maxWidth / image.extent.width
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        return effect.apply(to: image)
    }

    // MARK: - Taking photos

    /// Renders the newest frame at full resolution and saves it. Returns the saved file.
    func takePhoto() async -> URL? {
        await withCheckedContinuation { continuation in
            videoQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                self.lock.lock()
                let buffer = self.latestPixelBuffer
                let effect = self.videoQueueEffect
                self.lock.unlock()

                guard let buffer else {
                    continuation.resume(returning: nil)
                    return
                }
                let image = self.render(CIImage(cvPixelBuffer: buffer), effect: effect, maxWidth: nil)
                guard let cgImage = self.ciContext.createCGImage(image, from: image.extent) else {
                    continuation.resume(returning: nil)
                    return
                }
                let url = self.save(cgImage)
                if url != nil {
                    DispatchQueue.main.async { self.refreshRecentPhotos() }
                }
                continuation.resume(returning: url)
            }
        }
    }

    private func save(_ image: CGImage) -> URL? {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: photosFolder, withIntermediateDirectories: true)
        } catch {
            print("PhotoBooth: could not create \(photosFolder.path): \(error.localizedDescription)")
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        var url = photosFolder.appendingPathComponent("Photo \(formatter.string(from: Date())).jpg")
        var counter = 2
        while fm.fileExists(atPath: url.path) {
            url = photosFolder.appendingPathComponent("Photo \(formatter.string(from: Date())) \(counter).jpg")
            counter += 1
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.92]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        return CGImageDestinationFinalize(destination) ? url : nil
    }

    // MARK: - Recent photos

    func refreshRecentPhotos() {
        let folder = photosFolder
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            let photos = urls
                .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
                .sorted { lhs, rhs in
                    let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return l > r
                }
            DispatchQueue.main.async {
                self?.recentPhotos = Array(photos.prefix(12))
            }
        }
    }

    /// Small thumbnail via ImageIO, without decoding the whole photo.
    static func thumbnail(for url: URL, maxPixelSize: Int = 200) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
