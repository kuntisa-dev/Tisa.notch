//
//  PhotoBoothStyles.swift
//  TisaDynamicIsland
//
//  Styles for Photo Booth mode: after the 3 or 4 photos are taken, the user picks
//  a format (layout), a background and a filter, and BoothRenderer draws the final picture.
//  Layouts are measured in points and drawn at `scale` pixels per point, so the same
//  code makes the small live sample and the full-size PNG.
//

import CoreGraphics
import CoreImage
import CoreText
import Defaults
import Foundation

// MARK: - Format

/// Groups for the Format row in the style picker.
enum BoothCategory: String, CaseIterable, Identifiable {
    case classic, social, fun, sports, kpop, heroes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .social: return "Social"
        case .fun: return "Fun"
        case .sports: return "Sports"
        case .kpop: return "K-pop"
        case .heroes: return "Heroes"
        }
    }
}

enum BoothFormat: String, CaseIterable, Identifiable, Defaults.Serializable {
    case khmerStamp
    case strip
    case grid
    case polaroid
    case film
    case minimal
    case story
    case square
    case sticker
    case comic
    case receipt
    case ronaldoLegacy
    case btsArmyScrapbook
    case webHeroCityNight

    var id: String { rawValue }

    /// Formats to offer: artwork templates only when their files loaded.
    static var available: [BoothFormat] {
        allCases.filter { !$0.isArtworkTemplate || $0.artwork != nil }
    }

    /// Artwork templates that loaded, in order, for the photo-count button.
    static var availableArtwork: [BoothFormat] {
        available.filter(\.isArtworkTemplate)
    }

    var category: BoothCategory {
        switch self {
        case .khmerStamp, .strip, .grid, .polaroid, .film, .minimal: return .classic
        case .story, .square: return .social
        case .sticker, .comic, .receipt: return .fun
        case .ronaldoLegacy: return .sports
        case .btsArmyScrapbook: return .kpop
        case .webHeroCityNight: return .heroes
        }
    }

    var title: String {
        switch self {
        case .khmerStamp: return "Khmer Stamp"
        case .strip: return "Strip"
        case .grid: return "Grid"
        case .polaroid: return "Polaroid"
        case .film: return "Film"
        case .minimal: return "Minimal"
        case .story: return "Story 9:16"
        case .square: return "Square 1:1"
        case .sticker: return "Sticker"
        case .comic: return "Comic"
        case .receipt: return "Receipt"
        case .ronaldoLegacy: return "Ronaldo Legacy"
        case .btsArmyScrapbook: return "BTS ARMY Scrapbook"
        case .webHeroCityNight: return "Web Hero City Night"
        }
    }

    var symbol: String {
        switch self {
        case .khmerStamp: return "seal"
        case .strip: return "rectangle.grid.1x2"
        case .grid: return "square.grid.2x2"
        case .polaroid: return "photo.on.rectangle.angled"
        case .film: return "film"
        case .minimal: return "rectangle.portrait"
        case .story: return "rectangle.ratio.9.to.16"
        case .square: return "square"
        case .sticker: return "rectangle.stack"
        case .comic: return "text.bubble"
        case .receipt: return "receipt"
        case .ronaldoLegacy: return "soccerball"
        case .btsArmyScrapbook: return "music.mic"
        case .webHeroCityNight: return "moon.stars"
        }
    }

    var isArtworkTemplate: Bool { self == .ronaldoLegacy || self == .btsArmyScrapbook || self == .webHeroCityNight }

    /// Finished artwork the photos are composited into (see BoothArtworkTemplate); nil if its files didn't load.
    var artwork: BoothArtworkTemplate? {
        switch self {
        case .ronaldoLegacy: return BoothArtworkTemplate.ronaldoLegacy
        case .btsArmyScrapbook: return BoothArtworkTemplate.btsArmyScrapbook
        case .webHeroCityNight: return BoothArtworkTemplate.webHeroCityNight
        default: return nil
        }
    }

    /// Artwork templates have a fixed number of photo windows.
    var requiredPhotoCount: Int? { artwork?.slotCount }

    /// The Khmer stamp, the receipt and artwork templates bring their own paper, so backgrounds don't apply.
    var usesBackground: Bool { self != .khmerStamp && self != .receipt && artwork == nil }

    /// Pixels per point for the saved PNG; every format comes out about 1080 px wide.
    var outputScale: CGFloat {
        switch self {
        case .khmerStamp, .ronaldoLegacy, .btsArmyScrapbook, .webHeroCityNight: return 1
        case .sticker, .comic: return 2.25
        case .receipt: return 3
        default: return 2
        }
    }

    /// Pixels per point for the live sample in the notch.
    var sampleScale: CGFloat {
        switch self {
        case .khmerStamp, .ronaldoLegacy, .btsArmyScrapbook, .webHeroCityNight: return 0.25
        case .sticker, .comic: return 0.4
        case .receipt: return 0.5
        default: return 0.35
        }
    }
}

// MARK: - Background

enum BoothBackground: String, CaseIterable, Identifiable, Defaults.Serializable {
    case white, cream, black, blush, mint, sky, lavender
    case sunset, ocean
    case dots, stripes, khmer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white: return "White"
        case .cream: return "Cream"
        case .black: return "Black"
        case .blush: return "Blush"
        case .mint: return "Mint"
        case .sky: return "Sky"
        case .lavender: return "Lavender"
        case .sunset: return "Sunset"
        case .ocean: return "Ocean"
        case .dots: return "Polka Dots"
        case .stripes: return "Candy Stripes"
        case .khmer: return "Khmer Pattern"
        }
    }

    /// Color for the title and date printed on this background.
    var ink: CGColor {
        switch self {
        case .white: return rgb(0.12, 0.12, 0.13)
        case .cream: return rgb(0.32, 0.22, 0.14)
        case .black, .ocean: return rgb(0.97, 0.97, 0.97)
        case .blush, .dots: return rgb(0.52, 0.16, 0.30)
        case .mint: return rgb(0.10, 0.32, 0.25)
        case .sky: return rgb(0.12, 0.24, 0.45)
        case .lavender: return rgb(0.33, 0.22, 0.55)
        case .sunset: return rgb(0.45, 0.14, 0.12)
        case .stripes: return rgb(0.62, 0.12, 0.18)
        case .khmer: return rgb(0.96, 0.88, 0.66)
        }
    }

    /// Patterned backgrounds get a plate behind printed text so it stays readable.
    var textPlate: CGColor? {
        switch self {
        case .dots, .stripes: return rgb(1, 0.98, 0.97, 0.92)
        case .khmer: return rgb(0.10, 0.27, 0.22, 0.95)
        default: return nil
        }
    }

    func draw(in rect: CGRect, context: CGContext) {
        func fill(_ color: CGColor) {
            context.setFillColor(color)
            context.fill(rect)
        }
        func verticalGradient(top: CGColor, bottom: CGColor) {
            guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                            colors: [top, bottom] as CFArray, locations: [0, 1]) else {
                fill(top)
                return
            }
            context.saveGState()
            context.clip(to: rect)
            context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.maxY),
                                       end: CGPoint(x: rect.midX, y: rect.minY), options: [])
            context.restoreGState()
        }

        switch self {
        case .white: fill(rgb(1, 1, 1))
        case .cream: fill(rgb(0.97, 0.93, 0.84))
        case .black: fill(rgb(0.07, 0.07, 0.08))
        case .blush: fill(rgb(0.98, 0.84, 0.87))
        case .mint: fill(rgb(0.82, 0.93, 0.87))
        case .sky: fill(rgb(0.80, 0.90, 0.98))
        case .lavender: fill(rgb(0.88, 0.85, 0.97))
        case .sunset: verticalGradient(top: rgb(1.0, 0.63, 0.56), bottom: rgb(1.0, 0.86, 0.58))
        case .ocean: verticalGradient(top: rgb(0.24, 0.64, 0.74), bottom: rgb(0.10, 0.27, 0.52))
        case .dots:
            fill(rgb(1, 0.97, 0.97))
            context.setFillColor(rgb(0.96, 0.62, 0.72))
            let pitch: CGFloat = 48
            for (row, y) in stride(from: rect.minY, through: rect.maxY + pitch, by: pitch).enumerated() {
                let offset = row.isMultiple(of: 2) ? 0 : pitch / 2
                for x in stride(from: rect.minX - offset, through: rect.maxX + pitch, by: pitch) {
                    context.fillEllipse(in: CGRect(x: x - 7, y: y - 7, width: 14, height: 14))
                }
            }
        case .stripes:
            fill(rgb(1, 0.98, 0.96))
            context.setFillColor(rgb(1.0, 0.80, 0.82))
            for x in stride(from: rect.minX, through: rect.maxX, by: 64) {
                context.fill(CGRect(x: x, y: rect.minY, width: 32, height: rect.height))
            }
        case .khmer:
            // Jade with a gold diamond lattice, after the bands on the Khmer stamp.
            fill(rgb(0.10, 0.27, 0.22))
            context.setFillColor(rgb(0.80, 0.65, 0.36))
            let pitch: CGFloat = 64
            for (row, y) in stride(from: rect.minY, through: rect.maxY + pitch, by: pitch / 2).enumerated() {
                let offset = row.isMultiple(of: 2) ? 0 : pitch / 2
                for x in stride(from: rect.minX - offset, through: rect.maxX + pitch, by: pitch) {
                    let size: CGFloat = row.isMultiple(of: 2) ? 7 : 3
                    context.move(to: CGPoint(x: x, y: y + size))
                    context.addLine(to: CGPoint(x: x + size, y: y))
                    context.addLine(to: CGPoint(x: x, y: y - size))
                    context.addLine(to: CGPoint(x: x - size, y: y))
                    context.closePath()
                }
            }
            context.fillPath()
        }
    }
}

// MARK: - Filter

enum BoothFilter: String, CaseIterable, Identifiable, Defaults.Serializable {
    case original, mono, noir, sepia, vintage, fade, chrome, warm, cool, glow, popArt, comic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: return "Original"
        case .warm: return "Warm"
        case .cool: return "Cool"
        default: return effect?.title ?? rawValue
        }
    }

    /// Most filters reuse the live Photo Booth effects.
    private var effect: PhotoBoothEffect? {
        switch self {
        case .mono: return .mono
        case .noir: return .noir
        case .sepia: return .sepia
        case .vintage: return .vintage
        case .fade: return .fade
        case .chrome: return .chrome
        case .glow: return .glow
        case .popArt: return .popArt
        case .comic: return .comic
        case .original, .warm, .cool: return nil
        }
    }

    func apply(to photo: CGImage) -> CGImage {
        let input = CIImage(cgImage: photo)
        let output: CIImage
        switch self {
        case .original:
            return photo
        case .warm:
            output = Self.channelGains(input, red: 1.08, green: 1.0, blue: 0.86)
        case .cool:
            output = Self.channelGains(input, red: 0.90, green: 0.98, blue: 1.10)
        default:
            guard let effect else { return photo }
            output = effect.apply(to: input)
        }
        return BoothRenderer.ciContext.createCGImage(output, from: input.extent) ?? photo
    }

    private static func channelGains(_ input: CIImage, red: CGFloat, green: CGFloat, blue: CGFloat) -> CIImage {
        guard let filter = CIFilter(name: "CIColorMatrix") else { return input }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: red, y: 0, z: 0, w: 0), forKey: "inputRVector")
        filter.setValue(CIVector(x: 0, y: green, z: 0, w: 0), forKey: "inputGVector")
        filter.setValue(CIVector(x: 0, y: 0, z: blue, w: 0), forKey: "inputBVector")
        return filter.outputImage ?? input
    }
}

// MARK: - Style

struct BoothStyle: Hashable {
    var format: BoothFormat
    var background: BoothBackground
    var filter: BoothFilter
    var backdrop: BoothBackdrop = .off
}

// MARK: - Renderer

enum BoothRenderer {
    static let ciContext = CIContext(options: [.cacheIntermediates: false])

    /// Draws the finished picture. `photos` must hold 3 or 4 images. `masks` holds each
    /// photo's person mask (see PhotoBoothBackdrop.swift); without one a photo keeps its room.
    static func render(_ style: BoothStyle, photos: [CGImage], masks: [CGImage?] = [], scale: CGFloat) -> CGImage? {
        guard let layout = StampLayout(rawValue: photos.count) else { return nil }
        // Backdrop, then filter, so the person and the backdrop get the same look. Each
        // distinct photo is done once (the live sample repeats the camera frame in every window).
        var done: [ObjectIdentifier: CGImage] = [:]
        var filtered = photos.enumerated().map { index, photo in
            if let image = done[ObjectIdentifier(photo)] { return image }
            let mask = index < masks.count ? masks[index] : nil
            let backdropped = BoothBackdropCompositor.apply(style.backdrop, style: style, to: photo, mask: mask)
            let image = style.filter.apply(to: backdropped)
            done[ObjectIdentifier(photo)] = image
            return image
        }
        if style.format == .receipt {
            // Thermal printers only print black and white.
            filtered = filtered.map { BoothFilter.mono.apply(to: $0) }
        }

        switch style.format {
        case .khmerStamp:
            return PostageStamp.render(layout, photos: filtered, scale: scale)
        case .strip:
            return renderStrip(filtered, background: style.background, scale: scale)
        case .grid:
            return renderGrid(filtered, background: style.background, scale: scale)
        case .polaroid:
            return renderPolaroid(filtered, background: style.background, scale: scale)
        case .film:
            return renderFilm(filtered, background: style.background, scale: scale)
        case .minimal:
            return renderMinimal(filtered, background: style.background, scale: scale)
        case .story:
            return renderStory(filtered, background: style.background, scale: scale)
        case .square:
            return renderSquare(filtered, background: style.background, scale: scale)
        case .sticker:
            return renderSticker(filtered, background: style.background, scale: scale)
        case .comic:
            return renderComic(filtered, background: style.background, scale: scale)
        case .receipt:
            return renderReceipt(filtered, filter: style.filter, scale: scale)
        case .ronaldoLegacy, .btsArmyScrapbook, .webHeroCityNight:
            return style.format.artwork?.render(filtered, scale: scale)
        }
    }

    /// Shrinks a camera photo for the live sample, so re-rendering on every tap stays quick.
    static func downscaled(_ image: CGImage, maxWidth: Int = 480) -> CGImage {
        guard image.width > maxWidth else { return image }
        let height = Int(CGFloat(image.height) * CGFloat(maxWidth) / CGFloat(image.width))
        guard let context = makeContext(width: CGFloat(maxWidth), height: CGFloat(height), scale: 1) else { return image }
        context.draw(image, in: CGRect(x: 0, y: 0, width: maxWidth, height: height))
        return context.makeImage() ?? image
    }

    /// Small square preview of a background for the picker.
    static let swatches: [BoothBackground: CGImage] = {
        var result: [BoothBackground: CGImage] = [:]
        for background in BoothBackground.allCases {
            guard let context = makeContext(width: 160, height: 160, scale: 0.25) else { continue }
            background.draw(in: CGRect(x: 0, y: 0, width: 160, height: 160), context: context)
            result[background] = context.makeImage()
        }
        return result
    }()

    // MARK: Layouts (points; y is measured from the top and flipped when drawing)

    /// Classic photo-booth strip: photos stacked, title and date at the bottom.
    private static func renderStrip(_ photos: [CGImage], background: BoothBackground, scale: CGFloat) -> CGImage? {
        let width: CGFloat = 600, margin: CGFloat = 36, gap: CGFloat = 18
        let photoSize = CGSize(width: width - margin * 2, height: (width - margin * 2) * 3 / 4)
        let height = margin + CGFloat(photos.count) * photoSize.height + CGFloat(photos.count - 1) * gap + 130
        guard let context = makeContext(width: width, height: height, scale: scale) else { return nil }
        background.draw(in: CGRect(x: 0, y: 0, width: width, height: height), context: context)

        for (index, photo) in photos.enumerated() {
            let top = margin + CGFloat(index) * (photoSize.height + gap)
            drawPhoto(photo, in: rect(x: margin, top: top, size: photoSize, canvasHeight: height), cornerRadius: 0, context: context)
        }
        drawFooter(background: background, centerX: width / 2, titleBaseline: 72, size: 26, context: context)
        return context.makeImage()
    }

    /// 2×2 grid. With 3 photos the fourth square holds a "Photo Booth" title card.
    private static func renderGrid(_ photos: [CGImage], background: BoothBackground, scale: CGFloat) -> CGImage? {
        let width: CGFloat = 1200, height: CGFloat = 1032, margin: CGFloat = 48, gap: CGFloat = 24
        let cell = CGSize(width: (width - margin * 2 - gap) / 2, height: (width - margin * 2 - gap) / 2 * 3 / 4)
        guard let context = makeContext(width: width, height: height, scale: scale) else { return nil }
        background.draw(in: CGRect(x: 0, y: 0, width: width, height: height), context: context)

        for index in 0..<4 {
            let frame = rect(x: margin + CGFloat(index % 2) * (cell.width + gap),
                             top: margin + CGFloat(index / 2) * (cell.height + gap),
                             size: cell, canvasHeight: height)
            if index < photos.count {
                drawPhoto(photos[index], in: frame, cornerRadius: 14, context: context)
            } else {
                let path = CGPath(roundedRect: frame, cornerWidth: 14, cornerHeight: 14, transform: nil)
                context.addPath(path)
                context.setFillColor(background.ink.copy(alpha: 0.10) ?? background.ink)
                context.fillPath()
                text("Photo Booth", font: "SnellRoundhand-Bold", size: 76, color: background.ink,
                     centerX: frame.midX, baseline: frame.midY - 10, context: context)
                text("✦  ✦  ✦", font: "AvenirNext-Medium", size: 22, color: background.ink,
                     centerX: frame.midX, baseline: frame.midY - 70, context: context)
            }
        }
        drawFooter(background: background, centerX: width / 2, titleBaseline: 80, size: 30, context: context)
        return context.makeImage()
    }

    /// Instant-camera prints scattered on the background, slightly tilted.
    private static func renderPolaroid(_ photos: [CGImage], background: BoothBackground, scale: CGFloat) -> CGImage? {
        let width: CGFloat = 1200, height: CGFloat = 1080
        guard let context = makeContext(width: width, height: height, scale: scale) else { return nil }
        background.draw(in: CGRect(x: 0, y: 0, width: width, height: height), context: context)

        // (center x, center y from the top, tilt in radians)
        let spots: [(CGFloat, CGFloat, CGFloat)] = photos.count == 4
            ? [(330, 300, -0.10), (870, 290, 0.08), (330, 750, 0.06), (870, 760, -0.07)]
            : [(320, 300, -0.10), (880, 290, 0.08), (600, 750, -0.04)]

        for (index, photo) in photos.enumerated() {
            let (x, top, angle) = spots[index]
            context.saveGState()
            context.translateBy(x: x, y: height - top)
            context.rotate(by: angle)

            let card = CGRect(x: -220, y: -200, width: 440, height: 400)
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: rgb(0, 0, 0, 0.35))
            context.setFillColor(rgb(0.99, 0.99, 0.97))
            context.fill(card)
            context.restoreGState()

            drawPhoto(photo, in: CGRect(x: -200, y: -120, width: 400, height: 300), cornerRadius: 0, context: context)
            text("#\(index + 1)", font: "Noteworthy-Bold", size: 30, color: rgb(0.25, 0.25, 0.27),
                 centerX: 0, baseline: -175, context: context)
            context.restoreGState()
        }

        text("TISA DYNAMIC ISLAND  ·  \(dateText)", font: "AvenirNext-DemiBold", size: 24, color: background.ink,
             centerX: width / 2, baseline: 40, kern: 3, plate: background.textPlate, context: context)
        return context.makeImage()
    }

    /// A strip of film negative with sprocket holes and orange frame numbers.
    private static func renderFilm(_ photos: [CGImage], background: BoothBackground, scale: CGFloat) -> CGImage? {
        let width: CGFloat = 700, filmWidth: CGFloat = 500, filmTop: CGFloat = 60
        let photoSize = CGSize(width: 420, height: 315), padding: CGFloat = 45, gap: CGFloat = 30
        let filmHeight = padding * 2 + CGFloat(photos.count) * photoSize.height + CGFloat(photos.count - 1) * gap
        let height = filmTop + filmHeight + 140
        guard let context = makeContext(width: width, height: height, scale: scale) else { return nil }
        background.draw(in: CGRect(x: 0, y: 0, width: width, height: height), context: context)

        let film = rect(x: (width - filmWidth) / 2, top: filmTop, size: CGSize(width: filmWidth, height: filmHeight), canvasHeight: height)
        let path = CGMutablePath()
        path.addRect(film)
        for y in stride(from: film.maxY - 38, through: film.minY + 12, by: -46) {
            for x in [film.minX + 12, film.maxX - 30] {
                path.addRoundedRect(in: CGRect(x: x, y: y, width: 18, height: 26), cornerWidth: 4, cornerHeight: 4)
            }
        }
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: rgb(0, 0, 0, 0.3))
        context.addPath(path)
        context.setFillColor(rgb(0.09, 0.08, 0.08))
        context.fillPath(using: .evenOdd)
        context.restoreGState()

        let orange = rgb(0.98, 0.58, 0.20)
        for (index, photo) in photos.enumerated() {
            let top = filmTop + padding + CGFloat(index) * (photoSize.height + gap)
            let frame = rect(x: (width - photoSize.width) / 2, top: top, size: photoSize, canvasHeight: height)
            drawPhoto(photo, in: frame, cornerRadius: 4, context: context)
            text("▸ \(index + 1)A", font: "Menlo-Bold", size: 13, color: orange,
                 centerX: frame.minX + 26, baseline: frame.minY - 20, context: context)
            text("TISA 400", font: "Menlo-Bold", size: 13, color: orange,
                 centerX: frame.maxX - 34, baseline: frame.minY - 20, context: context)
        }
        drawFooter(background: background, centerX: width / 2, titleBaseline: 72, size: 26, context: context)
        return context.makeImage()
    }

    /// One clean column with a wide border and only the date.
    private static func renderMinimal(_ photos: [CGImage], background: BoothBackground, scale: CGFloat) -> CGImage? {
        let width: CGFloat = 540, margin: CGFloat = 30, gap: CGFloat = 16
        let photoSize = CGSize(width: width - margin * 2, height: (width - margin * 2) * 3 / 4)
        let height = margin + CGFloat(photos.count) * photoSize.height + CGFloat(photos.count - 1) * gap + 110
        guard let context = makeContext(width: width, height: height, scale: scale) else { return nil }
        background.draw(in: CGRect(x: 0, y: 0, width: width, height: height), context: context)

        for (index, photo) in photos.enumerated() {
            let top = margin + CGFloat(index) * (photoSize.height + gap)
            drawPhoto(photo, in: rect(x: margin, top: top, size: photoSize, canvasHeight: height), cornerRadius: 0, context: context)
        }
        text(dotDateText, font: "Menlo-Bold", size: 18, color: background.ink.copy(alpha: 0.75) ?? background.ink,
             centerX: width / 2, baseline: 46, kern: 4, plate: background.textPlate, context: context)
        return context.makeImage()
    }

    /// 1080×1920 for Instagram and Telegram stories: big title, 2×2 portrait photos.
    private static func renderStory(_ photos: [CGImage], background: BoothBackground, scale: CGFloat) -> CGImage? {
        let width: CGFloat = 540, height: CGFloat = 960, padding: CGFloat = 40, gap: CGFloat = 16
        guard let context = makeContext(width: width, height: height, scale: scale) else { return nil }
        background.draw(in: CGRect(x: 0, y: 0, width: width, height: height), context: context)
        let ink = background.ink

        alignedText("PHOTO", font: "AvenirNext-Heavy", size: 76, color: ink, x: padding, align: .left,
                    baseline: height - 112, context: context)
        alignedText("BOOTH", font: "AvenirNext-Heavy", size: 76, color: ink, x: padding, align: .left,
                    baseline: height - 184, context: context)
        alignedText("\(dateText) · \(photos.count) SHOTS", font: "Menlo-Bold", size: 17, color: ink, x: padding + 2,
                    align: .left, baseline: height - 224, kern: 2, context: context)

        let cell = CGSize(width: (width - padding * 2 - gap) / 2, height: 296)
        for (index, photo) in photos.enumerated() {
            let top = 260 + CGFloat(index / 2) * (cell.height + gap)
            // With 3 photos the last one spans both columns.
            let spansRow = photos.count == 3 && index == 2
            let size = spansRow ? CGSize(width: width - padding * 2, height: cell.height) : cell
            let frame = rect(x: padding + CGFloat(index % 2) * (cell.width + gap), top: top, size: size, canvasHeight: height)
            drawPhoto(photo, in: frame, cornerRadius: 0, context: context)
            strokeBox(frame, width: 4, color: ink, context: context)
        }
        text("TISA DYNAMIC ISLAND", font: "Menlo-Bold", size: 14, color: ink, centerX: width / 2, baseline: 40,
             kern: 4, plate: background.textPlate, context: context)
        return context.makeImage()
    }

    /// 1080×1080 feed post with no text. With 3 photos: one tall photo on the left, two on the right.
    private static func renderSquare(_ photos: [CGImage], background: BoothBackground, scale: CGFloat) -> CGImage? {
        let side: CGFloat = 540, gap: CGFloat = 9
        let cell = (side - gap * 3) / 2
        guard let context = makeContext(width: side, height: side, scale: scale) else { return nil }
        background.draw(in: CGRect(x: 0, y: 0, width: side, height: side), context: context)

        let frames: [CGRect]
        if photos.count == 3 {
            frames = [
                CGRect(x: gap, y: gap, width: cell, height: side - gap * 2),
                CGRect(x: gap * 2 + cell, y: gap * 2 + cell, width: cell, height: cell),
                CGRect(x: gap * 2 + cell, y: gap, width: cell, height: cell),
            ]
        } else {
            frames = (0..<4).map { index in
                rect(x: gap + CGFloat(index % 2) * (cell + gap), top: gap + CGFloat(index / 2) * (cell + gap),
                     size: CGSize(width: cell, height: cell), canvasHeight: side)
            }
        }
        for (photo, frame) in zip(photos, frames) {
            drawPhoto(photo, in: frame, cornerRadius: 0, context: context)
        }
        return context.makeImage()
    }

    /// Photos as taped stickers with ink borders and hard shadows (the Tisa Neobrutal look).
    private static func renderSticker(_ photos: [CGImage], background: BoothBackground, scale: CGFloat) -> CGImage? {
        let width: CGFloat = 480, height: CGFloat = 600
        guard let context = makeContext(width: width, height: height, scale: scale) else { return nil }
        background.draw(in: CGRect(x: 0, y: 0, width: width, height: height), context: context)

        // (left, top, tilt in degrees, clockwise like CSS) for each photo, and its tape.
        let slots: [(CGFloat, CGFloat, CGFloat)] = photos.count == 4
            ? [(36, 56, -3), (252, 64, 2.5), (44, 262, 2), (248, 272, -2)]
            : [(36, 56, -3), (252, 64, 2.5), (145, 266, 1.5)]
        let tapes: [(CGFloat, CGFloat, CGFloat, CGColor)] = [
            (60, -14, -8, neoYellow), (62, -12, 6, neoPink), (60, -12, 5, neoBlue), (58, -10, -5, neoYellow),
        ]
        let photoSize = CGSize(width: 190, height: 146)

        for (index, photo) in photos.enumerated() {
            let (left, top, tilt) = slots[index]
            let frame = rect(x: left, top: top, size: photoSize, canvasHeight: height)
            rotated(around: CGPoint(x: frame.midX, y: frame.midY), degrees: tilt, context: context) { box in
                let local = box(photoSize)
                context.setFillColor(neoInk)
                context.fill(local.offsetBy(dx: 6, dy: -6))
                drawPhoto(photo, in: local, cornerRadius: 0, context: context)
                strokeBox(local, width: 3, color: neoInk, context: context)
            }

            let (tapeLeft, tapeTop, tapeTilt, tapeColor) = tapes[index]
            let tape = rect(x: left + tapeLeft, top: top + tapeTop, size: CGSize(width: 72, height: 22), canvasHeight: height)
            rotated(around: CGPoint(x: tape.midX, y: tape.midY), degrees: tapeTilt, context: context) { box in
                let local = box(tape.size)
                context.setFillColor(tapeColor)
                context.fill(local)
                strokeBox(local, width: 2, color: neoInk, context: context)
            }
        }

        // "TISA BOOTH" sticker and a date pill.
        let title = "TISA BOOTH"
        let titleSize = CGSize(width: textWidth(title, font: "AvenirNext-Heavy", size: 34) + 36, height: 56)
        let titleFrame = rect(x: 36, top: 470, size: titleSize, canvasHeight: height)
        rotated(around: CGPoint(x: titleFrame.midX, y: titleFrame.midY), degrees: -2, context: context) { box in
            let local = box(titleSize)
            context.setFillColor(neoInk)
            context.fill(local.offsetBy(dx: 6, dy: -6))
            context.setFillColor(neoYellow)
            context.fill(local)
            strokeBox(local, width: 3, color: neoInk, context: context)
            text(title, font: "AvenirNext-Heavy", size: 34, color: neoInk, centerX: 0, baseline: -12, context: context)
        }

        let date = dateText
        let pillSize = CGSize(width: textWidth(date, font: "Menlo-Bold", size: 13) + 28, height: 30)
        let pillFrame = rect(x: 304, top: 494, size: pillSize, canvasHeight: height)
        rotated(around: CGPoint(x: pillFrame.midX, y: pillFrame.midY), degrees: 3, context: context) { box in
            let local = box(pillSize)
            let pill = CGPath(roundedRect: local, cornerWidth: 15, cornerHeight: 15, transform: nil)
            context.saveGState()
            context.translateBy(x: 3, y: -3)
            context.addPath(pill)
            context.setFillColor(neoInk)
            context.fillPath()
            context.restoreGState()
            context.addPath(pill)
            context.setFillColor(neoPink)
            context.fillPath()
            context.addPath(pill)
            context.setStrokeColor(neoInk)
            context.setLineWidth(2)
            context.strokePath()
            text(date, font: "Menlo-Bold", size: 13, color: neoInk, centerX: 0, baseline: -4.5, context: context)
        }
        return context.makeImage()
    }

    /// Comic page: title bar, thick panels, a speech bubble and a "POW!" burst.
    private static func renderComic(_ photos: [CGImage], background: BoothBackground, scale: CGFloat) -> CGImage? {
        let width: CGFloat = 480, height: CGFloat = 600, pad: CGFloat = 16, gap: CGFloat = 10
        guard let context = makeContext(width: width, height: height, scale: scale) else { return nil }
        background.draw(in: CGRect(x: 0, y: 0, width: width, height: height), context: context)

        let bar = rect(x: pad, top: pad, size: CGSize(width: width - pad * 2, height: 56), canvasHeight: height)
        context.setFillColor(neoYellow)
        context.fill(bar)
        strokeBox(bar, width: 4, color: neoInk, context: context)
        alignedText("TISA COMICS", font: "AvenirNext-Heavy", size: 28, color: neoInk, x: bar.minX + 14, align: .left,
                    baseline: bar.midY - 10, context: context)
        alignedText("NO. 1 · \(dateText)", font: "Menlo-Bold", size: 12, color: neoInk, x: bar.maxX - 14, align: .right,
                    baseline: bar.midY - 4, context: context)

        let full = width - pad * 2, half = (full - gap) / 2
        // (left, top, width, height) of each panel.
        let panels: [(CGFloat, CGFloat, CGFloat, CGFloat)] = photos.count == 4
            ? [(pad, 84, full, 170), (pad, 264, half, 160), (pad + half + gap, 264, half, 160), (pad, 434, full, 150)]
            : [(pad, 84, full, 240), (pad, 334, half, 250), (pad + half + gap, 334, half, 250)]
        var frames: [CGRect] = []
        for (photo, panel) in zip(photos, panels) {
            let frame = rect(x: panel.0, top: panel.1, size: CGSize(width: panel.2, height: panel.3), canvasHeight: height)
            drawPhoto(photo, in: frame, cornerRadius: 0, context: context)
            strokeBox(frame, width: 4, color: neoInk, context: context)
            frames.append(frame)
        }

        // Speech bubble in the first panel.
        if let first = frames.first {
            let label = "SMILE!"
            let bubble = CGRect(x: first.minX + 18, y: first.maxY - 18 - 36,
                                width: textWidth(label, font: "AvenirNext-Heavy", size: 20) + 28, height: 36)
            let tail = CGMutablePath()
            tail.move(to: CGPoint(x: bubble.minX + 30, y: bubble.minY + 2))
            tail.addLine(to: CGPoint(x: bubble.minX + 26, y: bubble.minY - 16))
            tail.addLine(to: CGPoint(x: bubble.minX + 50, y: bubble.minY + 2))
            context.addPath(CGPath(roundedRect: bubble, cornerWidth: 18, cornerHeight: 18, transform: nil))
            context.setFillColor(rgb(1, 1, 1))
            context.fillPath()
            context.addPath(CGPath(roundedRect: bubble, cornerWidth: 18, cornerHeight: 18, transform: nil))
            context.setStrokeColor(neoInk)
            context.setLineWidth(3)
            context.strokePath()
            // Fill the tail over the bubble's edge, then outline only its two sides.
            context.addPath(tail)
            context.setFillColor(rgb(1, 1, 1))
            context.fillPath()
            context.move(to: CGPoint(x: bubble.minX + 30, y: bubble.minY))
            context.addLine(to: CGPoint(x: bubble.minX + 26, y: bubble.minY - 16))
            context.addLine(to: CGPoint(x: bubble.minX + 50, y: bubble.minY))
            context.strokePath()
            text(label, font: "AvenirNext-Heavy", size: 20, color: neoInk, centerX: bubble.midX, baseline: bubble.minY + 11,
                 context: context)
        }

        // "POW!" burst in the last panel.
        if let last = frames.last {
            // Smaller in a half-width panel so it doesn't cover the face.
            let size = min(120, last.width * 0.42)
            let outer = CGRect(x: last.maxX - 16 - size, y: last.maxY - 12 - size, width: size, height: size)
            star(in: outer, color: neoInk, context: context)
            let inner = outer.insetBy(dx: size * 0.05, dy: size * 0.05)
            star(in: inner, color: neoYellow, context: context)
            let fontSize = size * 0.16
            text("POW!", font: "AvenirNext-Heavy", size: fontSize, color: neoInk, centerX: inner.midX,
                 baseline: inner.midY - fontSize * 0.36, context: context)
        }
        return context.makeImage()
    }

    /// A thermal-printer receipt: mono photos, totals, a barcode from the date and អរគុណ.
    private static func renderReceipt(_ photos: [CGImage], filter: BoothFilter, scale: CGFloat) -> CGImage? {
        let width: CGFloat = 340, side: CGFloat = 32
        let photoSize = CGSize(width: width - side * 2, height: 135)
        let photosBottom = 106 + CGFloat(photos.count) * photoSize.height + CGFloat(photos.count - 1) * 8
        let height = photosBottom + 222
        guard let context = makeContext(width: width, height: height, scale: scale) else { return nil }
        let paper = rgb(0.984, 0.98, 0.965)
        let ink = rgb(0.10, 0.10, 0.10)

        // Paper with a torn zigzag bottom; the rest of the PNG stays transparent.
        let teeth = 20, depth: CGFloat = 9
        let paperPath = CGMutablePath()
        paperPath.move(to: CGPoint(x: 0, y: height))
        paperPath.addLine(to: CGPoint(x: width, y: height))
        paperPath.addLine(to: CGPoint(x: width, y: depth))
        for step in 1...(teeth * 2) {
            let x = width - CGFloat(step) * width / CGFloat(teeth * 2)
            paperPath.addLine(to: CGPoint(x: x, y: step.isMultiple(of: 2) ? depth : 0))
        }
        paperPath.closeSubpath()
        context.addPath(paperPath)
        context.setFillColor(paper)
        context.fillPath()

        func y(_ top: CGFloat) -> CGFloat { height - top }
        func dashedLine(atTop top: CGFloat) {
            context.saveGState()
            context.setLineDash(phase: 0, lengths: [6, 4])
            context.setLineWidth(2)
            context.setStrokeColor(ink)
            context.move(to: CGPoint(x: side, y: y(top)))
            context.addLine(to: CGPoint(x: width - side, y: y(top)))
            context.strokePath()
            context.restoreGState()
        }
        func row(_ left: String, _ right: String, top: CGFloat, bold: Bool = false) {
            let font = bold ? "Menlo-Bold" : "Menlo-Regular"
            alignedText(left, font: font, size: 12, color: ink, x: side, align: .left, baseline: y(top), context: context)
            alignedText(right, font: font, size: 12, color: ink, x: width - side, align: .right, baseline: y(top), context: context)
        }

        text("TISA PHOTO BOOTH", font: "Menlo-Bold", size: 18, color: ink, centerX: width / 2, baseline: y(43),
             kern: 1.4, context: context)
        text("TISA DYNAMIC ISLAND", font: "Menlo-Regular", size: 10, color: ink, centerX: width / 2, baseline: y(59),
             kern: 1.2, context: context)
        dashedLine(atTop: 72)

        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yyyy"
        let day = formatter.string(from: now)
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: now)
        row("DATE \(day)", time, top: 92)

        for (index, photo) in photos.enumerated() {
            let top = 106 + CGFloat(index) * (photoSize.height + 8)
            drawPhoto(photo, in: rect(x: side, top: top, size: photoSize, canvasHeight: height), cornerRadius: 0, context: context)
        }

        dashedLine(atTop: photosBottom + 12)
        row("SMILES x\(photos.count)", "FREE", top: photosBottom + 34)
        row("FILTER: \(filter == .original ? "MONO" : filter.title.uppercased())", "0.00", top: photosBottom + 52)
        row("TOTAL", "1 GOOD DAY", top: photosBottom + 70, bold: true)
        dashedLine(atTop: photosBottom + 84)

        // Barcode: bar widths come from the date and time digits.
        formatter.dateFormat = "yyyyMMddHHmm"
        let digits = formatter.string(from: now)
        let widths = digits.compactMap(\.wholeNumberValue).flatMap { [CGFloat(1 + $0 % 3), CGFloat(1 + ($0 + 1) % 2)] }
        let barcodeWidth = widths.reduce(0, +) + CGFloat(widths.count - 1) * 2
        var barX = (width - barcodeWidth) / 2
        context.setFillColor(ink)
        for barWidth in widths {
            context.fill(CGRect(x: barX, y: y(photosBottom + 140), width: barWidth, height: 44))
            barX += barWidth + 2
        }
        text(digits, font: "Menlo-Regular", size: 10, color: ink, centerX: width / 2, baseline: y(photosBottom + 156),
             kern: 3, context: context)
        text("អរគុណ · THANK YOU", font: "Khmer Sangam MN", size: 15, color: ink, centerX: width / 2,
             baseline: y(photosBottom + 182), context: context)
        return context.makeImage()
    }

    // MARK: Drawing helpers

    private static let neoInk = rgb(0.067, 0.067, 0.067)
    private static let neoYellow = rgb(1.0, 0.824, 0.247)
    private static let neoPink = rgb(1.0, 0.42, 0.616)
    private static let neoBlue = rgb(0.302, 0.486, 0.996)

    private enum TextAlign { case left, center, right }

    private static var dotDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd · MM · yyyy"
        return formatter.string(from: Date())
    }

    private static func textWidth(_ string: String, font: String, size: CGFloat, kern: CGFloat = 0) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName(font as CFString, size, nil),
            NSAttributedString.Key(kCTKernAttributeName as String): kern,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) - kern
    }

    /// Text that starts at, centers on or ends at `x`.
    private static func alignedText(_ string: String, font: String, size: CGFloat, color: CGColor, x: CGFloat,
                                    align: TextAlign, baseline: CGFloat, kern: CGFloat = 0, context: CGContext) {
        let width = textWidth(string, font: font, size: size, kern: kern)
        let centerX: CGFloat
        switch align {
        case .left: centerX = x + width / 2
        case .center: centerX = x
        case .right: centerX = x - width / 2
        }
        text(string, font: font, size: size, color: color, centerX: centerX, baseline: baseline, kern: kern, context: context)
    }

    /// Runs `draw` with the context rotated clockwise (like CSS) around `center`. The closure's
    /// argument turns a size into a rect centered on the origin.
    private static func rotated(around center: CGPoint, degrees: CGFloat, context: CGContext,
                                draw: ((CGSize) -> CGRect) -> Void) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: -degrees * .pi / 180)
        draw { size in CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height) }
        context.restoreGState()
    }

    /// A border drawn just inside `frame`.
    private static func strokeBox(_ frame: CGRect, width: CGFloat, color: CGColor, context: CGContext) {
        context.setStrokeColor(color)
        context.setLineWidth(width)
        context.stroke(frame.insetBy(dx: width / 2, dy: width / 2))
    }

    /// The 14-point comic burst.
    private static func star(in box: CGRect, color: CGColor, context: CGContext) {
        let points: [(CGFloat, CGFloat)] = [(50, 0), (61, 30), (95, 20), (72, 47), (100, 64), (66, 68), (70, 100),
                                            (50, 77), (28, 100), (32, 68), (0, 64), (28, 47), (5, 20), (39, 30)]
        let path = CGMutablePath()
        for (index, point) in points.enumerated() {
            let p = CGPoint(x: box.minX + point.0 / 100 * box.width, y: box.maxY - point.1 / 100 * box.height)
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        context.addPath(path)
        context.setFillColor(color)
        context.fillPath()
    }

    private static var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: Date()).uppercased()
    }

    private static func drawFooter(background: BoothBackground, centerX: CGFloat, titleBaseline: CGFloat,
                                   size: CGFloat, context: CGContext) {
        if let plate = background.textPlate {
            let plateRect = CGRect(x: centerX - size * 9, y: titleBaseline - size * 1.85,
                                   width: size * 18, height: size * 3.1)
            context.addPath(CGPath(roundedRect: plateRect, cornerWidth: size * 0.6, cornerHeight: size * 0.6, transform: nil))
            context.setFillColor(plate)
            context.fillPath()
        }
        text("TISA DYNAMIC ISLAND", font: "AvenirNext-DemiBold", size: size, color: background.ink,
             centerX: centerX, baseline: titleBaseline, kern: size * 0.18, context: context)
        text(dateText, font: "AvenirNext-Medium", size: size * 0.62, color: background.ink.copy(alpha: 0.75) ?? background.ink,
             centerX: centerX, baseline: titleBaseline - size * 1.3, kern: size * 0.12, context: context)
    }

    private static func makeContext(width: CGFloat, height: CGFloat, scale: CGFloat) -> CGContext? {
        guard let context = CGContext(
            data: nil, width: Int((width * scale).rounded()), height: Int((height * scale).rounded()),
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.interpolationQuality = .high
        return context
    }

    /// A rect given from the top of the canvas, in Core Graphics' bottom-up coordinates.
    private static func rect(x: CGFloat, top: CGFloat, size: CGSize, canvasHeight: CGFloat) -> CGRect {
        CGRect(x: x, y: canvasHeight - top - size.height, width: size.width, height: size.height)
    }

    /// Fills `frame` with the photo (aspect fill, centered).
    private static func drawPhoto(_ photo: CGImage, in frame: CGRect, cornerRadius: CGFloat, context: CGContext) {
        let fit = max(frame.width / CGFloat(photo.width), frame.height / CGFloat(photo.height))
        let size = CGSize(width: CGFloat(photo.width) * fit, height: CGFloat(photo.height) * fit)
        context.saveGState()
        context.addPath(CGPath(roundedRect: frame, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
        context.clip()
        context.draw(photo, in: CGRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                                       width: size.width, height: size.height))
        context.restoreGState()
    }

    private static func text(_ string: String, font: String, size: CGFloat, color: CGColor, centerX: CGFloat,
                             baseline: CGFloat, kern: CGFloat = 0, plate: CGColor? = nil, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName(font as CFString, size, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTKernAttributeName as String): kern,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
        // Kerning adds space after the last letter too; leave it out when centering.
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) - kern
        if let plate {
            let plateRect = CGRect(x: centerX - width / 2 - size * 0.8, y: baseline - size * 0.6,
                                   width: width + size * 1.6, height: size * 1.8)
            context.addPath(CGPath(roundedRect: plateRect, cornerWidth: plateRect.height / 2,
                                   cornerHeight: plateRect.height / 2, transform: nil))
            context.setFillColor(plate)
            context.fillPath()
        }
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: centerX - width / 2, y: baseline)
        CTLineDraw(line, context)
    }
}

private func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}
