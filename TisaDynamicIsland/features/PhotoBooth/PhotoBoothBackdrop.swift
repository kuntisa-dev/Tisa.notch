//
//  PhotoBoothBackdrop.swift
//  TisaDynamicIsland
//
//  Photo Booth backdrops: replaces the room behind the person with a blur or a
//  scene drawn to fit the chosen frame (stadium for Ronaldo Legacy, concert stage
//  for BTS, city at night for Web Hero, temple sunset for Khmer Stamp, a studio in
//  the frame's background color for the rest). Vision's person segmentation finds
//  the person; each photo's mask is made once at capture and reused for every style.
//

import CoreGraphics
import CoreImage
import Defaults
import Foundation
import Vision

enum BoothBackdrop: String, CaseIterable, Identifiable, Defaults.Serializable {
    case off
    case blur
    case match
    case studio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .blur: return "Blur"
        case .match: return "Match"
        case .studio: return "Studio"
        }
    }

    var symbol: String {
        switch self {
        case .off: return "person.crop.rectangle"
        case .blur: return "camera.aperture"
        case .match: return "wand.and.stars"
        case .studio: return "rectangle.inset.filled"
        }
    }

    /// What ends up behind the person with this style, for the button's help.
    func summary(for style: BoothStyle) -> String {
        switch self {
        case .off: return "your room"
        case .blur: return "your room, blurred"
        case .match, .studio: return BackdropScene.scene(for: self, style: style)?.title ?? "your room"
        }
    }
}

// MARK: - Scenes

/// A backdrop drawn in code. Drawn in a 480-point-wide space and scaled to the photo.
enum BackdropScene: Hashable {
    case stadium
    case concert
    case cityNight
    case templeSunset
    case studio(BoothBackground)
    case bokeh(BoothBackground)
    case pop(BoothBackground)

    var title: String {
        switch self {
        case .stadium: return "Stadium"
        case .concert: return "Concert stage"
        case .cityNight: return "City at night"
        case .templeSunset: return "Temple sunset"
        case .studio(let paper): return "\(paper.title) studio"
        case .bokeh(let paper): return "\(paper.title) lights"
        case .pop(let paper): return "\(paper.title) pop burst"
        }
    }

    static func scene(for backdrop: BoothBackdrop, style: BoothStyle) -> BackdropScene? {
        let paper = paper(for: style)
        switch backdrop {
        case .off, .blur:
            return nil
        case .studio:
            return .studio(paper)
        case .match:
            switch style.format {
            case .ronaldoLegacy: return .stadium
            case .btsArmyScrapbook: return .concert
            case .webHeroCityNight: return .cityNight
            case .khmerStamp: return .templeSunset
            case .sticker, .comic: return .pop(paper)
            case .polaroid, .film, .story, .square: return .bokeh(paper)
            case .strip, .grid, .minimal, .receipt: return .studio(paper)
            }
        }
    }

    /// The frame's background color, or the color that suits a format with its own paper.
    private static func paper(for style: BoothStyle) -> BoothBackground {
        if style.format.usesBackground { return style.background }
        switch style.format {
        case .receipt: return .white
        case .ronaldoLegacy: return .black
        case .btsArmyScrapbook: return .lavender
        case .webHeroCityNight: return .ocean
        default: return .cream
        }
    }

    private static let cacheLock = NSLock()
    private static var cache: [String: CGImage] = [:]

    /// The scene at a photo's pixel size. Cached: the live sample asks every frame.
    func image(width: Int, height: Int) -> CGImage? {
        let key = "\(self)-\(width)x\(height)"
        Self.cacheLock.lock()
        if let cached = Self.cache[key] {
            Self.cacheLock.unlock()
            return cached
        }
        Self.cacheLock.unlock()

        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let scale = CGFloat(width) / 480
        context.scaleBy(x: scale, y: scale)
        draw(size: CGSize(width: 480, height: CGFloat(height) / scale), context: context)
        guard let image = context.makeImage() else { return nil }

        Self.cacheLock.lock()
        if Self.cache.count > 16 { Self.cache.removeAll() }
        Self.cache[key] = image
        Self.cacheLock.unlock()
        return image
    }

    // MARK: Drawing (y up, origin bottom left)

    private func draw(size: CGSize, context: CGContext) {
        let rect = CGRect(origin: .zero, size: size)
        var random = SeededRandom(seed: 7)
        switch self {
        case .stadium: drawStadium(rect, context, &random)
        case .concert: drawConcert(rect, context, &random)
        case .cityNight: drawCityNight(rect, context, &random)
        case .templeSunset: drawTempleSunset(rect, context, &random)
        case .studio(let paper):
            paper.draw(in: rect, context: context)
            studioLight(rect, context)
        case .bokeh(let paper):
            paper.draw(in: rect, context: context)
            for _ in 0..<26 {
                let radius = random.next(in: 8...36)
                let center = CGPoint(x: random.next(in: 0...rect.width), y: random.next(in: 0...rect.height))
                let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.setFillColor(color(1, 1, 1, random.next(in: 0.12...0.3)))
                context.fillEllipse(in: circle)
                context.setStrokeColor(color(1, 1, 1, 0.25))
                context.setLineWidth(1)
                context.strokeEllipse(in: circle)
            }
            for _ in 0..<8 {
                let radius = random.next(in: 10...26)
                let center = CGPoint(x: random.next(in: 0...rect.width), y: random.next(in: 0...rect.height))
                context.setFillColor(paper.ink.copy(alpha: 0.10) ?? paper.ink)
                context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }
            studioLight(rect, context)
        case .pop(let paper):
            paper.draw(in: rect, context: context)
            let center = CGPoint(x: rect.midX, y: rect.height * 0.55)
            let reach = rect.width
            let rays = 24
            context.setFillColor(color(1, 1, 1, 0.38))
            for ray in stride(from: 0, to: rays, by: 2) {
                let start = CGFloat(ray) / CGFloat(rays) * .pi * 2
                let end = CGFloat(ray + 1) / CGFloat(rays) * .pi * 2
                context.move(to: center)
                context.addLine(to: CGPoint(x: center.x + cos(start) * reach, y: center.y + sin(start) * reach))
                context.addLine(to: CGPoint(x: center.x + cos(end) * reach, y: center.y + sin(end) * reach))
                context.closePath()
            }
            context.fillPath()
            // Halftone dots that grow toward the edges.
            context.setFillColor(paper.ink.copy(alpha: 0.16) ?? paper.ink)
            let pitch: CGFloat = 12
            for y in stride(from: CGFloat(0), through: rect.height, by: pitch) {
                for x in stride(from: CGFloat(0), through: rect.width, by: pitch) {
                    let distance = hypot(x - center.x, y - center.y) / (rect.width * 0.6)
                    let radius = min(pitch * 0.45, max(0, distance - 0.35) * pitch * 0.7)
                    if radius > 0.3 {
                        context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    }
                }
            }
        }
    }

    /// Soft light from the front and darker corners, like a photo studio backdrop.
    private func studioLight(_ rect: CGRect, _ context: CGContext) {
        radialGlow(context, center: CGPoint(x: rect.midX, y: rect.height * 0.6), radius: rect.width * 0.7,
                   color: color(1, 1, 1, 0.32))
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        if let vignette = CGGradient(colorsSpace: space, colors: [color(0, 0, 0, 0), color(0, 0, 0, 0.28)] as CFArray,
                                     locations: [0, 1]) {
            context.drawRadialGradient(vignette, startCenter: CGPoint(x: rect.midX, y: rect.midY), startRadius: rect.width * 0.35,
                                       endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: rect.width * 0.85,
                                       options: [.drawsAfterEndLocation])
        }
    }

    private func drawStadium(_ rect: CGRect, _ context: CGContext, _ random: inout SeededRandom) {
        let w = rect.width, h = rect.height
        verticalGradient(context, rect, [(0, color(0.02, 0.03, 0.08)), (0.55, color(0.08, 0.12, 0.26)), (1, color(0.10, 0.14, 0.30))])

        // Stands full of people.
        let standBottom = h * 0.28, standTop = h * 0.54
        context.setFillColor(color(0.06, 0.07, 0.12))
        context.fill(CGRect(x: 0, y: standBottom, width: w, height: standTop - standBottom))
        let crowd = [color(1, 1, 1, 0.5), color(0.9, 0.2, 0.2, 0.6), color(0.95, 0.85, 0.3, 0.5), color(0.3, 0.5, 0.9, 0.5)]
        for _ in 0..<1100 {
            let x = random.next(in: 0...w), y = random.next(in: standBottom...standTop)
            let r = random.next(in: 0.6...1.3)
            context.setFillColor(crowd[Int(random.next(in: 0...3.99))])
            context.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        context.setFillColor(color(1, 1, 1, 0.06))
        for row in stride(from: standBottom + 8, to: standTop, by: 8) {
            context.fill(CGRect(x: 0, y: row, width: w, height: 0.6))
        }
        context.setFillColor(color(0.03, 0.03, 0.06))
        context.fill(CGRect(x: 0, y: standTop, width: w, height: 6))

        // Floodlights with beams down to the pitch.
        for lampX in [w * 0.12, w * 0.88] {
            let lampY = h * 0.88
            context.saveGState()
            context.setBlendMode(.screen)
            context.setFillColor(color(1, 1, 1, 0.05))
            context.move(to: CGPoint(x: lampX - 12, y: lampY))
            context.addLine(to: CGPoint(x: lampX + 12, y: lampY))
            context.addLine(to: CGPoint(x: w * 0.5 + (lampX - w * 0.5) * 0.2 + 90, y: 0))
            context.addLine(to: CGPoint(x: w * 0.5 + (lampX - w * 0.5) * 0.2 - 90, y: 0))
            context.closePath()
            context.fillPath()
            context.restoreGState()
            radialGlow(context, center: CGPoint(x: lampX, y: lampY), radius: 130, color: color(0.85, 0.9, 1, 0.45))
            context.setFillColor(color(1, 1, 0.97))
            for row in 0..<3 {
                for column in 0..<5 {
                    let x = lampX - 14 + CGFloat(column) * 7, y = lampY - 6 + CGFloat(row) * 6
                    context.fillEllipse(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
                }
            }
        }

        // Pitch with mowing stripes, closer stripes taller.
        verticalGradient(context, CGRect(x: 0, y: 0, width: w, height: standBottom),
                         [(0, color(0.17, 0.56, 0.23)), (1, color(0.09, 0.40, 0.15))])
        var top = standBottom
        var band: CGFloat = 6
        var light = true
        while top > 0 {
            if light {
                context.setFillColor(color(1, 1, 1, 0.06))
                context.fill(CGRect(x: 0, y: max(0, top - band), width: w, height: band))
            }
            top -= band
            band *= 1.35
            light.toggle()
        }
        context.setStrokeColor(color(1, 1, 1, 0.55))
        context.setLineWidth(1.5)
        context.stroke(CGRect(x: -2, y: standBottom - 6, width: w + 4, height: 0.1))
        context.strokeEllipse(in: CGRect(x: w / 2 - 100, y: -36, width: 200, height: 60))
        radialGlow(context, center: CGPoint(x: w * 0.5, y: h * 0.2), radius: w * 0.4, color: color(0.85, 0.1, 0.12, 0.10))
    }

    private func drawConcert(_ rect: CGRect, _ context: CGContext, _ random: inout SeededRandom) {
        let w = rect.width, h = rect.height
        verticalGradient(context, rect, [(0, color(0.25, 0.05, 0.36)), (1, color(0.08, 0.02, 0.18))])
        radialGlow(context, center: CGPoint(x: w * 0.5, y: h * 0.55), radius: w * 0.6, color: color(0.62, 0.30, 0.95, 0.30))

        // Stage beams from the lighting rig.
        let beams: [(CGFloat, CGColor)] = [(0.15, color(0.70, 0.45, 1.0)), (0.38, color(1.0, 0.45, 0.80)),
                                           (0.62, color(0.85, 0.80, 1.0)), (0.85, color(0.70, 0.45, 1.0))]
        for (index, (x, beamColor)) in beams.enumerated() {
            let origin = CGPoint(x: w * x, y: h)
            let lean: CGFloat = index.isMultiple(of: 2) ? 40 : -40
            context.saveGState()
            context.move(to: CGPoint(x: origin.x - 6, y: origin.y))
            context.addLine(to: CGPoint(x: origin.x + 6, y: origin.y))
            context.addLine(to: CGPoint(x: origin.x + lean + 70, y: 0))
            context.addLine(to: CGPoint(x: origin.x + lean - 70, y: 0))
            context.closePath()
            context.clip()
            context.setBlendMode(.screen)
            verticalGradient(context, rect, [(0, beamColor.copy(alpha: 0.38) ?? beamColor), (1, beamColor.copy(alpha: 0) ?? beamColor)])
            context.restoreGState()
            radialGlow(context, center: origin, radius: 40, color: color(1, 0.95, 1, 0.8))
        }

        for _ in 0..<40 {
            let radius = random.next(in: 6...22)
            let center = CGPoint(x: random.next(in: 0...w), y: random.next(in: h * 0.25...h))
            let tint = random.next(in: 0...1) > 0.5 ? color(0.80, 0.55, 1.0) : color(1.0, 0.55, 0.85)
            context.setFillColor(tint.copy(alpha: random.next(in: 0.10...0.25)) ?? tint)
            context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }

        // The crowd: heads, then purple light sticks above them.
        context.setFillColor(color(0.04, 0.0, 0.08))
        context.fill(CGRect(x: 0, y: 0, width: w, height: h * 0.07))
        var x: CGFloat = -8
        while x < w + 8 {
            let r = random.next(in: 9...15)
            context.fillEllipse(in: CGRect(x: x - r, y: h * 0.07 - r * 0.4, width: r * 2, height: r * 2))
            x += random.next(in: 14...24)
        }
        for _ in 0..<170 {
            let stick = CGPoint(x: random.next(in: 0...w), y: random.next(in: h * 0.10...h * 0.30))
            let r = random.next(in: 1.4...2.6)
            context.setFillColor(color(0.78, 0.58, 1.0, 0.22))
            context.fillEllipse(in: CGRect(x: stick.x - r * 3, y: stick.y - r * 3, width: r * 6, height: r * 6))
            context.setFillColor(color(0.92, 0.82, 1.0, 0.95))
            context.fillEllipse(in: CGRect(x: stick.x - r, y: stick.y - r, width: r * 2, height: r * 2))
        }
    }

    private func drawCityNight(_ rect: CGRect, _ context: CGContext, _ random: inout SeededRandom) {
        let w = rect.width, h = rect.height
        verticalGradient(context, rect, [(0, color(0.02, 0.03, 0.10)), (0.55, color(0.08, 0.10, 0.28)), (1, color(0.32, 0.20, 0.46))])
        context.setFillColor(color(1, 1, 1))
        for _ in 0..<90 {
            let star = CGPoint(x: random.next(in: 0...w), y: random.next(in: h * 0.4...h))
            let r = random.next(in: 0.4...1.1)
            context.setAlpha(random.next(in: 0.3...0.85))
            context.fillEllipse(in: CGRect(x: star.x - r, y: star.y - r, width: r * 2, height: r * 2))
        }
        context.setAlpha(1)

        let moon = CGPoint(x: w * 0.78, y: h * 0.78)
        radialGlow(context, center: moon, radius: 120, color: color(0.85, 0.88, 1, 0.35))
        context.setFillColor(color(0.98, 0.96, 0.88))
        context.fillEllipse(in: CGRect(x: moon.x - 34, y: moon.y - 34, width: 68, height: 68))
        context.setFillColor(color(0.6, 0.6, 0.55, 0.12))
        for (dx, dy, r) in [(-10.0, 8.0, 7.0), (9, -6, 5), (12, 12, 4), (-4, -14, 5)] {
            context.fillEllipse(in: CGRect(x: moon.x + dx - r, y: moon.y + dy - r, width: r * 2, height: r * 2))
        }
        radialGlow(context, center: CGPoint(x: w * 0.2, y: h * 0.22), radius: w * 0.45, color: color(0.9, 0.12, 0.18, 0.16))

        // Far skyline, then near buildings with lit windows.
        context.setFillColor(color(0.10, 0.12, 0.26))
        var x: CGFloat = 0
        while x < w {
            let width = random.next(in: 18...40)
            context.fill(CGRect(x: x, y: 0, width: width - 2, height: random.next(in: h * 0.28...h * 0.52)))
            x += width
        }
        x = -10
        while x < w {
            let width = random.next(in: 26...60)
            let height = random.next(in: h * 0.14...h * 0.42)
            let building = CGRect(x: x, y: 0, width: width - 3, height: height)
            context.setFillColor(color(0.03, 0.04, 0.10))
            context.fill(building)
            if height > h * 0.36 {
                context.fill(CGRect(x: building.midX - 0.75, y: height, width: 1.5, height: 14))
                context.setFillColor(color(1, 0.2, 0.2))
                context.fillEllipse(in: CGRect(x: building.midX - 1.6, y: height + 13, width: 3.2, height: 3.2))
            }
            for wy in stride(from: CGFloat(6), to: height - 6, by: 9) {
                for wx in stride(from: building.minX + 5, to: building.maxX - 5, by: 7) where random.next(in: 0...1) < 0.35 {
                    context.setFillColor(color(1.0, 0.85, 0.45, random.next(in: 0.55...0.95)))
                    context.fill(CGRect(x: wx, y: wy, width: 2.6, height: 3.6))
                }
            }
            x += width
        }
    }

    private func drawTempleSunset(_ rect: CGRect, _ context: CGContext, _ random: inout SeededRandom) {
        let w = rect.width, h = rect.height
        let horizon = h * 0.30
        let sky = CGRect(x: 0, y: horizon, width: w, height: h - horizon)
        verticalGradient(context, sky, [(0, color(0.36, 0.18, 0.46)), (0.55, color(0.95, 0.46, 0.26)), (1, color(1.0, 0.80, 0.42))])
        let sun = CGPoint(x: w * 0.5, y: horizon + 40)
        radialGlow(context, center: sun, radius: 170, color: color(1.0, 0.85, 0.5, 0.45))
        context.setFillColor(color(1.0, 0.90, 0.60))
        context.fillEllipse(in: CGRect(x: sun.x - 40, y: sun.y - 40, width: 80, height: 80))
        context.setFillColor(color(0.85, 0.40, 0.38, 0.35))
        for _ in 0..<5 {
            let cloud = CGPoint(x: random.next(in: 0...w), y: random.next(in: h * 0.62...h * 0.92))
            context.fillEllipse(in: CGRect(x: cloud.x - 70, y: cloud.y - 5, width: random.next(in: 90...160), height: 10))
        }

        // Water, with the temple and the sun reflected.
        verticalGradient(context, CGRect(x: 0, y: 0, width: w, height: horizon),
                         [(0, color(0.62, 0.30, 0.28)), (1, color(0.22, 0.09, 0.14))])
        let silhouette = color(0.18, 0.08, 0.10)
        context.saveGState()
        context.translateBy(x: 0, y: horizon * 2)
        context.scaleBy(x: 1, y: -1)
        context.setAlpha(0.35)
        drawTemple(context, width: w, ground: horizon, color: silhouette)
        context.restoreGState()
        context.setFillColor(color(1.0, 0.85, 0.5, 0.5))
        for line in 0..<9 {
            let y = horizon - 6 - CGFloat(line) * 9
            let half = 34 - CGFloat(line) * 3
            context.fill(CGRect(x: sun.x - half, y: y, width: half * 2, height: 2))
        }

        drawTemple(context, width: w, ground: horizon, color: silhouette)
        for (palmX, lean) in [(w * 0.06, CGFloat(14)), (w * 0.95, CGFloat(-16))] {
            drawPalm(context, base: CGPoint(x: palmX, y: horizon - 4), height: h * 0.5, lean: lean, color: silhouette)
        }
    }

    /// Five lotus-bud towers on stepped terraces, after Angkor Wat.
    private func drawTemple(_ context: CGContext, width w: CGFloat, ground: CGFloat, color fill: CGColor) {
        context.setFillColor(fill)
        context.fill(CGRect(x: w * 0.16, y: ground, width: w * 0.68, height: 10))
        context.fill(CGRect(x: w * 0.22, y: ground + 10, width: w * 0.56, height: 8))
        context.fill(CGRect(x: w * 0.29, y: ground + 18, width: w * 0.42, height: 7))
        let towers: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.25, 10, 26, 58), (0.75, 10, 26, 58), (0.37, 18, 32, 82), (0.63, 18, 32, 82), (0.5, 25, 44, 122),
        ]
        for (x, base, width, height) in towers {
            let cx = w * x, baseY = ground + base
            context.move(to: CGPoint(x: cx - width / 2, y: baseY))
            context.addLine(to: CGPoint(x: cx - width / 2, y: baseY + height * 0.3))
            context.addQuadCurve(to: CGPoint(x: cx, y: baseY + height),
                                 control: CGPoint(x: cx - width * 0.48, y: baseY + height * 0.78))
            context.addQuadCurve(to: CGPoint(x: cx + width / 2, y: baseY + height * 0.3),
                                 control: CGPoint(x: cx + width * 0.48, y: baseY + height * 0.78))
            context.addLine(to: CGPoint(x: cx + width / 2, y: baseY))
            context.closePath()
            context.fillPath()
            for tier in 0..<4 {
                let tierWidth = width * (1.08 - CGFloat(tier) * 0.16)
                let tierY = baseY + height * (0.30 + CGFloat(tier) * 0.13)
                context.fill(CGRect(x: cx - tierWidth / 2, y: tierY, width: tierWidth, height: 2.5))
            }
        }
    }

    private func drawPalm(_ context: CGContext, base: CGPoint, height: CGFloat, lean: CGFloat, color fill: CGColor) {
        let top = CGPoint(x: base.x + lean, y: base.y + height)
        context.setStrokeColor(fill)
        context.setLineCap(.round)
        context.setLineWidth(4)
        context.move(to: base)
        context.addQuadCurve(to: top, control: CGPoint(x: base.x - lean * 0.3, y: base.y + height * 0.6))
        context.strokePath()
        context.setLineWidth(3)
        for angle in stride(from: CGFloat(0.15), to: .pi * 2, by: .pi / 4) {
            let tip = CGPoint(x: top.x + cos(angle) * 44, y: top.y + sin(angle) * 22 - 10)
            context.move(to: top)
            context.addQuadCurve(to: tip, control: CGPoint(x: top.x + cos(angle) * 26, y: top.y + 12))
        }
        context.strokePath()
    }

    // MARK: Helpers

    /// `stops` run from the bottom (0) to the top (1) of `rect`.
    private func verticalGradient(_ context: CGContext, _ rect: CGRect, _ stops: [(CGFloat, CGColor)]) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let gradient = CGGradient(colorsSpace: space, colors: stops.map(\.1) as CFArray,
                                        locations: stops.map(\.0)) else { return }
        context.saveGState()
        context.clip(to: rect)
        context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY),
                                   end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        context.restoreGState()
    }

    private func radialGlow(_ context: CGContext, center: CGPoint, radius: CGFloat, color glow: CGColor) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let gradient = CGGradient(colorsSpace: space, colors: [glow, glow.copy(alpha: 0) ?? glow] as CFArray,
                                        locations: [0, 1]) else { return }
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: radius, options: [])
    }

    private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

/// Same scene every time: the backdrop must not shimmer between live frames.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next(in range: ClosedRange<CGFloat>) -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let unit = CGFloat(state >> 11) / CGFloat(UInt64(1) << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Compositing

enum BoothBackdropCompositor {
    enum Quality {
        /// About 14 ms on a 480 px frame: for the live sample and the camera preview.
        case live
        /// About 55 ms: for the photos that go into the picture.
        case final
    }

    /// Grayscale mask, white where a person is, or nil if Vision fails.
    static func personMask(for photo: CGImage, quality: Quality) -> CGImage? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = quality == .live ? .balanced : .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        do {
            try VNImageRequestHandler(cgImage: photo).perform([request])
        } catch {
            return nil
        }
        guard let buffer = request.results?.first?.pixelBuffer else { return nil }
        let mask = CIImage(cvPixelBuffer: buffer)
        return BoothRenderer.ciContext.createCGImage(mask, from: mask.extent, format: .L8,
                                                     colorSpace: CGColorSpaceCreateDeviceGray())
    }

    /// The photo with everything but the person replaced by the backdrop. The mask
    /// may be any size; it is stretched over the photo.
    static func apply(_ backdrop: BoothBackdrop, style: BoothStyle, to photo: CGImage, mask: CGImage?) -> CGImage {
        guard backdrop != .off, let mask else { return photo }
        let input = CIImage(cgImage: photo)
        let extent = input.extent

        let background: CIImage
        switch backdrop {
        case .off:
            return photo
        case .blur:
            background = input.clampedToExtent()
                .applyingGaussianBlur(sigma: extent.width * 0.02)
                .cropped(to: extent)
        case .match, .studio:
            guard let scene = BackdropScene.scene(for: backdrop, style: style),
                  let image = scene.image(width: photo.width, height: photo.height) else { return photo }
            background = CIImage(cgImage: image)
        }

        var matte = CIImage(cgImage: mask)
        matte = matte.transformed(by: CGAffineTransform(scaleX: extent.width / matte.extent.width,
                                                        y: extent.height / matte.extent.height))
        // Soften the cut a little so hair and shoulders blend into the backdrop.
        matte = matte.clampedToExtent()
            .applyingGaussianBlur(sigma: max(0.8, extent.width * 0.0015))
            .cropped(to: extent)

        let output = input.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: background,
            kCIInputMaskImageKey: matte,
        ])
        return BoothRenderer.ciContext.createCGImage(output, from: extent) ?? photo
    }
}
