//
//  BoothArtworkTemplate.swift
//  TisaDynamicIsland
//
//  Photo Booth templates made from finished artwork instead of drawn layouts.
//  Each one is three bundled files:
//    <name>_original.png       the complete design (empty photo cards included)
//    <name>_frame_overlay.png  the same design with transparent photo windows
//    <name>_layout.json        the canvas size and each window's rect, in the artwork's pixels
//  The layout may name its own image files in "assetFiles". The overlay is optional:
//  for an artwork-only template (just the poster and the layout, like Web Hero City
//  Night) the flat placeholder cards are cut out of the poster when it loads.
//  The photos are drawn aspect-fill into the windows, under the overlay, so the
//  artwork's images, texture, type and borders stay exactly as designed. The live
//  sample and the exported PNG both come from render(_:scale:), only the scale differs.
//

import CoreGraphics
import Foundation
import ImageIO

struct BoothArtworkTemplate {
    struct Layout: Decodable {
        struct Size: Decodable {
            let width: CGFloat
            let height: CGFloat
        }

        /// A photo window. x and y are measured from the artwork's top-left corner.
        struct Slot: Decodable {
            let x: CGFloat
            let y: CGFloat
            let width: CGFloat
            let height: CGFloat
            let cornerRadius: CGFloat?
        }

        struct AssetFiles: Decodable {
            let original: String
            /// Leave out for an artwork-only template.
            let overlay: String?
        }

        let canvas: Size
        let slots: [Slot]
        let assetFiles: AssetFiles?
    }

    let layout: Layout
    let original: CGImage
    let overlay: CGImage
    /// Where each photo is drawn, top-left origin: the slot from the layout, grown to cover
    /// every transparent pixel of its window in the overlay, plus a bleed hidden under the frame.
    let photoFrames: [CGRect]

    /// Cristiano Ronaldo Legacy poster: 1086 × 1448 with four photo windows.
    static let ronaldoLegacy = BoothArtworkTemplate(named: "ronaldo")
    /// BTS ARMY Scrapbook poster: 1086 × 1448 with four photo windows.
    static let btsArmyScrapbook = BoothArtworkTemplate(named: "bts")
    /// Web Hero City Night poster: 1086 × 1448, artwork only (its four gray cards are cut out at load).
    static let webHeroCityNight = BoothArtworkTemplate(named: "webhero")

    /// Extra pixels drawn past each window's edge; the opaque frame covers them, so no
    /// placeholder can show along an edge whose mask is a pixel off.
    private static let bleed: CGFloat = 2

    /// Loads `<name>_layout.json`, then the images it names (default `<name>_original.png`
    /// and `<name>_frame_overlay.png`) from the app bundle. Without an overlay file the
    /// poster itself is used and its placeholder cards are cut out (see fitWindows).
    init?(named name: String, bundle: Bundle = .main) {
        guard let layoutURL = bundle.url(forResource: "\(name)_layout", withExtension: "json"),
              let data = try? Data(contentsOf: layoutURL),
              let layout = try? JSONDecoder().decode(Layout.self, from: data),
              !layout.slots.isEmpty,
              let original = Self.loadImage(layout.assetFiles?.original ?? "\(name)_original.png", bundle: bundle)
        else {
            print("BoothArtworkTemplate: could not load the \"\(name)\" template from the app bundle")
            return nil
        }
        let overlay: CGImage
        if let loaded = Self.loadImage(layout.assetFiles?.overlay ?? "\(name)_frame_overlay.png", bundle: bundle) {
            overlay = loaded
        } else if layout.assetFiles?.overlay == nil {
            overlay = original
        } else {
            print("BoothArtworkTemplate: the \"\(name)\" layout names an overlay that isn't in the app bundle")
            return nil
        }
        guard let fitted = Self.fitWindows(layout: layout, original: original, overlay: overlay) else {
            print("BoothArtworkTemplate: could not read the \"\(name)\" overlay")
            return nil
        }
        self.layout = layout
        self.original = original
        self.overlay = fitted.overlay
        self.photoFrames = fitted.frames
        self.clearedPlaceholderPixels = fitted.cleared
    }

    /// Per window, how many opaque placeholder pixels the overlay still had around the
    /// transparent cut-out and were made transparent (see fitWindows). 0 for a clean overlay.
    let clearedPlaceholderPixels: [Int]

    var slotCount: Int { layout.slots.count }

    /// Width ÷ height of the first photo window, for the camera framing guide.
    var slotAspect: CGFloat {
        let frame = photoFrames[0]
        return frame.width / frame.height
    }

    /// Composites the photos into the artwork. `scale` 1 gives the artwork's native size
    /// (1086 × 1448 for both posters); smaller values make the live sample. Fewer photos
    /// than windows is fine: the empty windows keep the original's placeholder card.
    func render(_ photos: [CGImage], scale: CGFloat) -> CGImage? {
        let width = layout.canvas.width, height = layout.canvas.height
        guard let context = CGContext(
            data: nil, width: Int((width * scale).rounded()), height: Int((height * scale).rounded()),
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.interpolationQuality = .high
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)

        // The complete design goes underneath, so a window without a photo keeps its card.
        context.draw(original, in: canvas)

        for (index, photo) in photos.prefix(slotCount).enumerated() {
            let fit = photoFrames[index]
            // Core Graphics measures y from the bottom.
            let frame = CGRect(x: fit.minX, y: height - fit.maxY, width: fit.width, height: fit.height)
            let radius = min((layout.slots[index].cornerRadius ?? 0) + Self.bleed, frame.width / 2, frame.height / 2)

            // Aspect fill: scale until the photo covers the frame, keep its proportions, center it.
            let fill = max(frame.width / CGFloat(photo.width), frame.height / CGFloat(photo.height))
            let size = CGSize(width: CGFloat(photo.width) * fill, height: CGFloat(photo.height) * fill)

            context.saveGState()
            context.addPath(CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.clip()
            context.draw(photo, in: CGRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                                           width: size.width, height: size.height))
            context.restoreGState()
        }

        context.draw(overlay, in: canvas)
        return context.makeImage()
    }

    // MARK: Loading

    private static func loadImage(_ fileName: String, bundle: Bundle) -> CGImage? {
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = bundle.url(forResource: name, withExtension: ext.isEmpty ? "png" : ext),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        // Decode now, once, instead of on every sample render.
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        return CGImageSourceCreateImageAtIndex(source, 0, options)
    }

    /// Fits the photo windows to the artwork, because the supplied files can be slightly off:
    /// - a layout rect can stop a pixel short of the overlay's transparent window
    ///   (BTS's windows reach one pixel further right and down), and
    /// - the overlay's cut-out can be smaller than the placeholder card in the original,
    ///   leaving an opaque band of placeholder color inside the frame (BTS keeps about 15 px of
    ///   lavender below and 13 px right of each window).
    /// For each slot this flood-fills the transparent window from its center, takes the
    /// placeholder color from the original inside it, then grows outward over opaque overlay
    /// pixels of that color (at most `maxGrowth` px past the layout rect, stopping at the frame's
    /// border) and makes them transparent. The photo is drawn to cover all of it.
    /// An artwork-only template has no window yet: the placeholder color is read from the middle
    /// of the slot and the whole card is cleared from its center outward the same way.
    private static func fitWindows(layout: Layout, original: CGImage, overlay: CGImage)
        -> (overlay: CGImage, frames: [CGRect], cleared: [Int])? {
        let width = Int(layout.canvas.width), height = Int(layout.canvas.height)
        let maxGrowth = 20, tolerance = 30
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

        func bitmap(_ image: CGImage) -> CGContext? {
            guard let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return context
        }
        guard let overlayContext = bitmap(overlay), let overlayData = overlayContext.data,
              let originalContext = bitmap(original), let originalData = originalContext.data else { return nil }
        // A bitmap context's first row is the top of the image, matching the layout's coordinates.
        let over = overlayData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        let orig = originalData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        func index(_ x: Int, _ y: Int) -> Int { (y * width + x) * 4 }
        func isWindow(_ x: Int, _ y: Int) -> Bool { over[index(x, y) + 3] < 255 }

        var visited = [Bool](repeating: false, count: width * height)
        var frames: [CGRect] = []
        var cleared: [Int] = []

        for slot in layout.slots {
            let slotRect = CGRect(x: slot.x, y: slot.y, width: slot.width, height: slot.height)
            let startX = Int(slotRect.midX), startY = Int(slotRect.midY)
            guard startX >= 0, startX < width, startY >= 0, startY < height else {
                frames.append(slotRect.insetBy(dx: -bleed, dy: -bleed))
                cleared.append(0)
                continue
            }

            // 1. The transparent window, and the placeholder color behind it in the original.
            var window: [(Int, Int)] = []
            var stack = [(startX, startY)]
            var sum = (0, 0, 0)
            var clearedHere = 0
            if isWindow(startX, startY) {
                visited[startY * width + startX] = true
                while let (x, y) = stack.popLast() {
                    window.append((x, y))
                    let i = index(x, y)
                    sum = (sum.0 + Int(orig[i]), sum.1 + Int(orig[i + 1]), sum.2 + Int(orig[i + 2]))
                    for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
                    where nx >= 0 && nx < width && ny >= 0 && ny < height
                        && !visited[ny * width + nx] && isWindow(nx, ny) {
                        visited[ny * width + nx] = true
                        stack.append((nx, ny))
                    }
                }
            } else {
                // Artwork only: sample the card's color from the middle half of the slot.
                let core = slotRect.insetBy(dx: slotRect.width / 4, dy: slotRect.height / 4)
                for y in stride(from: Int(core.minY), to: Int(core.maxY), by: 2) {
                    for x in stride(from: Int(core.minX), to: Int(core.maxX), by: 2) {
                        let i = index(x, y)
                        sum = (sum.0 + Int(orig[i]), sum.1 + Int(orig[i + 1]), sum.2 + Int(orig[i + 2]))
                        window.append((x, y))
                    }
                }
            }
            guard !window.isEmpty else {
                frames.append(slotRect.insetBy(dx: -bleed, dy: -bleed))
                cleared.append(0)
                continue
            }
            let placeholder = (sum.0 / window.count, sum.1 / window.count, sum.2 / window.count)

            // 2. Opaque placeholder pixels touching the window, within reach of the layout rect.
            let reach = slotRect.insetBy(dx: CGFloat(-maxGrowth), dy: CGFloat(-maxGrowth))
            func isPlaceholder(_ x: Int, _ y: Int) -> Bool {
                guard reach.contains(CGPoint(x: x, y: y)) else { return false }
                let i = index(x, y)
                return over[i + 3] == 255
                    && abs(Int(over[i]) - placeholder.0) <= tolerance
                    && abs(Int(over[i + 1]) - placeholder.1) <= tolerance
                    && abs(Int(over[i + 2]) - placeholder.2) <= tolerance
            }
            if !isWindow(startX, startY) {
                // Artwork only: the card is cleared outward from its center pixel.
                guard isPlaceholder(startX, startY) else {
                    frames.append(slotRect.insetBy(dx: -bleed, dy: -bleed))
                    cleared.append(0)
                    continue
                }
                visited[startY * width + startX] = true
                let i = index(startX, startY)
                over[i] = 0; over[i + 1] = 0; over[i + 2] = 0; over[i + 3] = 0
                clearedHere = 1
                window = [(startX, startY)]
            }
            var minX = startX, maxX = startX, minY = startY, maxY = startY
            stack = window
            while let (x, y) = stack.popLast() {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
                where nx >= 0 && nx < width && ny >= 0 && ny < height
                    && !visited[ny * width + nx] && isPlaceholder(nx, ny) {
                    visited[ny * width + nx] = true
                    let i = index(nx, ny)
                    over[i] = 0; over[i + 1] = 0; over[i + 2] = 0; over[i + 3] = 0
                    clearedHere += 1
                    stack.append((nx, ny))
                }
            }

            let covered = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
            frames.append(slotRect.union(covered).insetBy(dx: -bleed, dy: -bleed))
            cleared.append(clearedHere)
        }

        let fixedOverlay = cleared.contains { $0 > 0 } ? (overlayContext.makeImage() ?? overlay) : overlay
        return (fixedOverlay, frames, cleared)
    }
}
