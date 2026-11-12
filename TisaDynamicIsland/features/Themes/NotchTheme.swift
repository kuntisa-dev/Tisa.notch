//
//  NotchTheme.swift
//  TisaDynamicIsland
//
//  Themes for the open notch: a drawn background (web, football pitch, cartoon city,
//  temples at dusk, neon grid, candy bubbles, galaxy) or a picture of your own, the
//  accent color that goes with it, and a font. The picture themes (Bianconeri, Blue Crystal,
//  Red Night, My Picture) each keep their own picture; the first three put Home's tiles on
//  clear glass so the picture shows through. The top of the notch stays black so it
//  still blends into the camera housing; Home's tiles get darker glass so they stay
//  readable over the art. The built-in art is original and drawn in code.
//

import AppKit
import Defaults
import SwiftUI

enum NotchTheme: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case classic
    case webHero
    case footballLegend
    case animalCity
    case khmerDusk
    case neonNight
    case candyPop
    case galaxy
    case bianconeri
    case blueCrystal
    case redNight
    case myPicture

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .webHero: return "Web Hero"
        case .footballLegend: return "Football Legend"
        case .animalCity: return "Animal City"
        case .khmerDusk: return "Khmer Dusk"
        case .neonNight: return "Neon Night"
        case .candyPop: return "Candy Pop"
        case .galaxy: return "Galaxy"
        case .bianconeri: return "Bianconeri"
        case .blueCrystal: return "Blue Crystal"
        case .redNight: return "Red Night"
        case .myPicture: return "My Picture"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: return "Black glass, the original look"
        case .webHero: return "Red and blue, webs over a night city"
        case .footballLegend: return "Pitch stripes, chalk lines and gold"
        case .animalCity: return "A bright cartoon city and paw prints"
        case .khmerDusk: return "Sunset sky and temple towers"
        case .neonNight: return "Synthwave grid and a neon sun"
        case .candyPop: return "Pastel bubbles, sweet and soft"
        case .galaxy: return "Stars and a violet nebula"
        case .bianconeri: return "Your picture, liquid glass, black and white"
        case .blueCrystal: return "Your picture, crystal glass, blue"
        case .redNight: return "Your picture, crystal glass, red"
        case .myPicture: return "Any picture you choose"
        }
    }

    /// The accent color the theme brings (used unless you keep your own).
    var accent: Color? {
        switch self {
        case .classic: return nil
        case .webHero: return Color(red: 0.93, green: 0.18, blue: 0.22)
        case .footballLegend: return Color(red: 0.98, green: 0.78, blue: 0.24)
        case .animalCity: return Color(red: 1.0, green: 0.55, blue: 0.22)
        case .khmerDusk: return Color(red: 0.96, green: 0.36, blue: 0.48)
        case .neonNight: return Color(red: 1.0, green: 0.26, blue: 0.80)
        case .candyPop: return Color(red: 1.0, green: 0.40, blue: 0.66)
        case .galaxy: return Color(red: 0.56, green: 0.44, blue: 1.0)
        case .bianconeri: return Color(white: 0.96)
        case .blueCrystal: return Color(red: 0.23, green: 0.61, blue: 1.0)
        case .redNight: return Color(red: 1.0, green: 0.18, blue: 0.24)
        case .myPicture: return Defaults[.themePictureAccent].flatMap(Color.init(hex:))
        }
    }

    /// Cartoon-ish themes use the rounded system font.
    var fontDesign: Font.Design {
        switch self {
        case .animalCity, .candyPop, .footballLegend: return .rounded
        default: return .default
        }
    }

    /// How dark the glass behind Home's tiles is, so text stays readable over the art.
    var cardShade: Double {
        switch self {
        case .classic, .bianconeri, .blueCrystal, .redNight: return 0
        case .animalCity, .candyPop: return 0.5
        default: return 0.42
        }
    }

    /// Themes drawn from a picture you choose, each keeping its own.
    var usesPicture: Bool {
        switch self {
        case .bianconeri, .blueCrystal, .redNight, .myPicture: return true
        default: return false
        }
    }

    /// Home's tiles on see-through glass instead of the darker glowing glass.
    enum CardGlass { case liquid, crystal, smoky }

    /// The glass the theme comes with.
    var cardGlass: CardGlass? {
        switch self {
        case .bianconeri: return .liquid
        case .blueCrystal, .redNight: return .smoky
        default: return nil
        }
    }

    /// The glass in use: the theme's own, unless Settings › Themes › Card glass picks another.
    var effectiveGlass: CardGlass? {
        guard self != .classic else { return nil }
        switch Defaults[.cardGlassChoice] {
        case .automatic: return cardGlass
        case .crystal: return .crystal
        case .smoky: return .smoky
        case .liquid: return .liquid
        case .dark: return nil
        }
    }

    static var current: NotchTheme { Defaults[.notchTheme] }
}

/// Settings › Themes › Card glass.
enum CardGlassChoice: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case automatic, crystal, smoky, liquid, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .crystal: return "Crystal"
        case .smoky: return "Smoky"
        case .liquid: return "Liquid"
        case .dark: return "Dark glow"
        }
    }

    var detail: String {
        switch self {
        case .automatic: return "The glass each theme comes with."
        case .crystal: return "Clearest: a light shine, the picture stays sharp behind the tiles."
        case .smoky: return "See-through with a dark tint, so a bright picture behind the tiles is darkened."
        case .liquid: return "Clear glass with a stronger shine."
        case .dark: return "Dark glass with edges that glow in the theme's color."
        }
    }
}

extension Defaults.Keys {
    static let cardGlassChoice = Key<CardGlassChoice>("cardGlassChoice", default: .automatic)
    /// On the picture themes, buttons and tab icons in color instead of white.
    static let themeColorIcons = Key<Bool>("themeColorIcons", default: true)
    static let notchTheme = Key<NotchTheme>("notchTheme", default: .classic)
    /// Let the theme set the accent color (else keep the one from Appearance).
    static let themeSetsAccent = Key<Bool>("themeSetsAccent", default: true)
    /// File name of the picture for My Picture, copied into Application Support.
    static let themePictureFile = Key<String?>("themePictureFile", default: nil)
    /// How much My Picture is darkened, 0…0.8.
    static let themePictureDim = Key<Double>("themePictureDim", default: 0.3)
    static let themePictureBlur = Key<Double>("themePictureBlur", default: 0)
    /// The picture's strongest color, as "#RRGGBB", picked when the picture is chosen.
    static let themePictureAccent = Key<String?>("themePictureAccent", default: nil)
    /// Home's tiles get glossy tops and edges that glow in the theme's color.
    static let themeGlowTiles = Key<Bool>("themeGlowTiles", default: true)
    /// Pictures for Bianconeri, Blue Crystal and Red Night, by theme: file names in Application Support.
    static let themePictures = Key<[String: String]>("themePictures", default: [:])
    /// How much each of those pictures is darkened, by theme, 0…0.8.
    static let themePictureDims = Key<[String: Double]>("themePictureDims", default: [:])
    /// How far each picture is moved down, by theme (My Picture too), so faces clear the camera.
    static let themePictureOffsets = Key<[String: Double]>("themePictureOffsets", default: [:])
}

extension Color {
    init?(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

extension Notification.Name {
    static let notchThemeChanged = Notification.Name("NotchThemeChanged")
}

// MARK: - Picture storage

enum ThemePicture {
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Tisa Dynamic Island/Themes", isDirectory: true)
    }

    /// The picture's file name. My Picture keeps its original setting; the others share a dictionary.
    static func file(for theme: NotchTheme) -> String? {
        theme == .myPicture ? Defaults[.themePictureFile] : Defaults[.themePictures][theme.rawValue]
    }

    static func url(for theme: NotchTheme) -> URL? {
        file(for: theme).map { folder.appendingPathComponent($0) }
    }

    private static var cache: [String: NSImage] = [:]

    static func image(for theme: NotchTheme) -> NSImage? {
        guard let name = file(for: theme) else { return nil }
        if let image = cache[name] { return image }
        guard let image = NSImage(contentsOf: folder.appendingPathComponent(name)) else { return nil }
        cache[name] = image
        return image
    }

    static func dim(for theme: NotchTheme) -> Double {
        theme == .myPicture ? Defaults[.themePictureDim] : Defaults[.themePictureDims][theme.rawValue] ?? 0.08
    }

    static func setDim(_ value: Double, for theme: NotchTheme) {
        if theme == .myPicture { Defaults[.themePictureDim] = value } else { Defaults[.themePictureDims][theme.rawValue] = value }
    }

    /// The see-through themes start a little lower, so a face in the middle isn't under the camera.
    static func offset(for theme: NotchTheme) -> Double {
        Defaults[.themePictureOffsets][theme.rawValue] ?? (theme.cardGlass == nil ? 0 : 24)
    }

    static func setOffset(_ value: Double, for theme: NotchTheme) {
        Defaults[.themePictureOffsets][theme.rawValue] = value
    }

    /// Asks for a picture and keeps a copy, so moving or deleting the original doesn't break the theme.
    @MainActor
    static func choose(for theme: NotchTheme = .myPicture) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a picture for \(theme.title)"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let source = panel.url else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = "picture-\(UUID().uuidString.prefix(8)).\(source.pathExtension.isEmpty ? "png" : source.pathExtension)"
            try FileManager.default.copyItem(at: source, to: folder.appendingPathComponent(name))
            if let old = url(for: theme) { try? FileManager.default.removeItem(at: old) }
            if theme == .myPicture {
                Defaults[.themePictureFile] = name
                Defaults[.themePictureAccent] = NSImage(contentsOf: folder.appendingPathComponent(name)).flatMap(strongestColor)
            } else {
                Defaults[.themePictures][theme.rawValue] = name
            }
            Defaults[.notchTheme] = theme
            NotificationCenter.default.post(name: .notchThemeChanged, object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("AccentColorChanged"), object: nil)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

extension ThemePicture {
    /// The picture's strongest color: the most common vivid hue, brightened a little so it
    /// works as an accent. Nil for a picture with no real color (black and white).
    static func strongestColor(of image: NSImage) -> String? {
        let side = 32
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()

        let bins = 18
        var weight = [Double](repeating: 0, count: bins)
        var sums = [(h: Double, s: Double, b: Double)](repeating: (0, 0, 0), count: bins)
        for x in 0..<side {
            for y in 0..<side {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                guard s > 0.3, b > 0.25 else { continue }
                let w = Double(s * b)
                let bin = min(bins - 1, Int(h * CGFloat(bins)))
                weight[bin] += w
                sums[bin].h += Double(h) * w
                sums[bin].s += Double(s) * w
                sums[bin].b += Double(b) * w
            }
        }
        guard let best = weight.indices.max(by: { weight[$0] < weight[$1] }), weight[best] > 1 else { return nil }
        let w = weight[best]
        let color = NSColor(hue: sums[best].h / w, saturation: max(0.7, sums[best].s / w),
                            brightness: max(0.85, sums[best].b / w), alpha: 1)
        return String(format: "#%02X%02X%02X", Int(color.redComponent * 255), Int(color.greenComponent * 255), Int(color.blueComponent * 255))
    }
}

// MARK: - Backdrop

/// The theme's art, filling the open notch behind its content.
struct ThemeBackdrop: View {
    let theme: NotchTheme
    /// Fade to black at the top so the notch meets the camera housing.
    var fadeTop = true

    @Default(.themePictureDim) private var pictureDim
    @Default(.themePictureBlur) private var pictureBlur
    @Default(.themePictureFile) private var pictureFile
    @Default(.themePictures) private var pictures
    @Default(.themePictureDims) private var pictureDims
    @Default(.themePictureOffsets) private var pictureOffsets
    @Default(.cardGlassChoice) private var glassChoice

    var body: some View {
        art
            .mask {
                if fadeTop {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.55), location: 0.12),
                            .init(color: .black, location: 0.3),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                } else {
                    Color.black
                }
            }
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var art: some View {
        switch theme {
        case .classic: Color.clear
        case .webHero: WebHeroArt()
        case .footballLegend: FootballArt()
        case .animalCity: AnimalCityArt()
        case .khmerDusk: KhmerDuskArt()
        case .neonNight: NeonNightArt()
        case .candyPop: CandyArt()
        case .galaxy: GalaxyArt()
        case .bianconeri, .blueCrystal, .redNight, .myPicture:
            picture
        }
    }

    /// The theme's own picture, moved down by its offset, darkened, with a soft vignette
    /// (lighter for the see-through themes, so the picture stays clear).
    @ViewBuilder
    private var picture: some View {
        // Read here so the view redraws when a picture or its settings change.
        let _ = (pictureFile, pictures, pictureDims, pictureOffsets, pictureDim, glassChoice)
        if let image = ThemePicture.image(for: theme) {
            GeometryReader { geometry in
                Color.clear
                    .overlay(alignment: .top) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .offset(y: ThemePicture.offset(for: theme))
                    }
                    .clipped()
                    .blur(radius: theme == .myPicture ? pictureBlur : 0)
                    .overlay(Color.black.opacity(ThemePicture.dim(for: theme)))
                    .overlay(RadialGradient(colors: [.clear, .black.opacity(theme.effectiveGlass == nil ? 0.35 : 0.18)], center: .center,
                                            startRadius: geometry.size.width * 0.2, endRadius: geometry.size.width * 0.7))
            }
        } else {
            LinearGradient(colors: [theme.accent?.opacity(0.35) ?? Color(white: 0.16), Color(white: 0.06)], startPoint: .top, endPoint: .bottom)
        }
    }
}

/// Repeatable pseudo-random numbers, so the stars and bubbles land in the same places each time.
private struct Seeded {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

// MARK: Web Hero

private struct WebHeroArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.62, green: 0.06, blue: 0.12), Color(red: 0.05, green: 0.09, blue: 0.30)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                // A web from the top-left corner: spokes and sagging rings.
                let center = CGPoint(x: -size.width * 0.04, y: -size.height * 0.1)
                let reach = hypot(size.width, size.height) * 1.1
                let spokes = 11
                let angles = (0..<spokes).map { Double($0) / Double(spokes - 1) * (.pi / 2) }
                var web = Path()
                for angle in angles {
                    web.move(to: center)
                    web.addLine(to: CGPoint(x: center.x + cos(angle) * reach, y: center.y + sin(angle) * reach))
                }
                for ring in 1...9 {
                    let radius = reach * Double(ring) / 9 * 0.9
                    for (a, b) in zip(angles, angles.dropFirst()) {
                        let p1 = CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
                        let p2 = CGPoint(x: center.x + cos(b) * radius, y: center.y + sin(b) * radius)
                        let mid = (a + b) / 2
                        let sag = CGPoint(x: center.x + cos(mid) * radius * 0.94, y: center.y + sin(mid) * radius * 0.94)
                        if ring == 1 && a == angles[0] { web.move(to: p1) } else { web.move(to: p1) }
                        web.addQuadCurve(to: p2, control: sag)
                    }
                }
                context.stroke(web, with: .color(.white.opacity(0.16)), lineWidth: 1)

                // City skyline along the bottom.
                var rng = Seeded(7)
                var x: CGFloat = 0
                while x < size.width {
                    let w = 18 + rng.next() * 34
                    let h = size.height * (0.14 + rng.next() * 0.22)
                    let rect = CGRect(x: x, y: size.height - h, width: w, height: h)
                    context.fill(Path(rect), with: .color(Color(red: 0.03, green: 0.04, blue: 0.14).opacity(0.85)))
                    // A few lit windows.
                    for _ in 0..<Int(w * h / 900) {
                        let wx = rect.minX + 3 + rng.next() * (w - 8)
                        let wy = rect.minY + 4 + rng.next() * (h - 10)
                        context.fill(Path(CGRect(x: wx, y: wy, width: 3, height: 4)),
                                     with: .color(Color(red: 1, green: 0.85, blue: 0.5).opacity(0.5)))
                    }
                    x += w + 3
                }
            }
        }
    }
}

// MARK: Football Legend

private struct FootballArt: View {
    var body: some View {
        ZStack {
            Canvas { context, size in
                // Mowed stripes.
                let stripes = 12
                let w = size.width / CGFloat(stripes)
                for i in 0..<stripes {
                    let color = i.isMultiple(of: 2) ? Color(red: 0.10, green: 0.46, blue: 0.22) : Color(red: 0.13, green: 0.53, blue: 0.26)
                    context.fill(Path(CGRect(x: CGFloat(i) * w, y: 0, width: w + 1, height: size.height)), with: .color(color))
                }
                // Chalk: halfway line, center circle, both boxes.
                var chalk = Path()
                let mid = size.width / 2
                chalk.move(to: CGPoint(x: mid, y: 0))
                chalk.addLine(to: CGPoint(x: mid, y: size.height))
                let r = size.height * 0.32
                chalk.addEllipse(in: CGRect(x: mid - r, y: size.height / 2 - r, width: r * 2, height: r * 2))
                let boxH = size.height * 0.62, boxW = size.width * 0.12
                chalk.addRect(CGRect(x: 6, y: (size.height - boxH) / 2, width: boxW, height: boxH))
                chalk.addRect(CGRect(x: size.width - 6 - boxW, y: (size.height - boxH) / 2, width: boxW, height: boxH))
                chalk.addRect(CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12))
                context.stroke(chalk, with: .color(.white.opacity(0.28)), lineWidth: 2)
                context.fill(Path(ellipseIn: CGRect(x: mid - 3, y: size.height / 2 - 3, width: 6, height: 6)), with: .color(.white.opacity(0.4)))
            }
            // Stadium light and a gold corner glow.
            RadialGradient(colors: [Color.white.opacity(0.18), .clear], center: .top, startRadius: 0, endRadius: 320)
            RadialGradient(colors: [Color(red: 1, green: 0.8, blue: 0.3).opacity(0.35), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 260)
            // A big gold seven, like a shirt number.
            GeometryReader { geometry in
                Text("7")
                    .font(.system(size: geometry.size.height * 0.95, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.86, blue: 0.4), Color(red: 0.85, green: 0.6, blue: 0.15)],
                                                    startPoint: .top, endPoint: .bottom))
                    .opacity(0.22)
                    .position(x: geometry.size.width * 0.86, y: geometry.size.height * 0.56)
            }
        }
    }
}

// MARK: Animal City

private struct AnimalCityArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.38, green: 0.72, blue: 0.98), Color(red: 0.62, green: 0.90, blue: 0.86)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                var rng = Seeded(21)
                // Puffy clouds.
                for i in 0..<4 {
                    let cx = size.width * (0.12 + 0.27 * Double(i)) + rng.next() * 30
                    let cy = size.height * (0.28 + rng.next() * 0.12)
                    for j in 0..<3 {
                        let r = 16 + rng.next() * 12
                        let rect = CGRect(x: cx + Double(j) * 18 - r, y: cy - r + (j == 1 ? -8 : 0), width: r * 2, height: r * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.75)))
                    }
                }
                // Rounded pastel buildings with windows.
                let colors: [Color] = [
                    Color(red: 1.0, green: 0.62, blue: 0.48), Color(red: 1.0, green: 0.82, blue: 0.42),
                    Color(red: 0.62, green: 0.56, blue: 0.98), Color(red: 0.42, green: 0.82, blue: 0.62),
                    Color(red: 1.0, green: 0.56, blue: 0.72),
                ]
                var x: CGFloat = -10
                var index = 0
                while x < size.width {
                    let w = 46 + rng.next() * 50
                    let h = size.height * (0.3 + rng.next() * 0.34)
                    let rect = CGRect(x: x, y: size.height - h, width: w, height: h + 20)
                    context.fill(Path(roundedRect: rect, cornerRadius: 14), with: .color(colors[index % colors.count]))
                    for row in 0..<Int(h / 26) {
                        for col in 0..<Int(w / 22) {
                            let window = CGRect(x: rect.minX + 9 + CGFloat(col) * 20, y: rect.minY + 12 + CGFloat(row) * 24, width: 10, height: 12)
                            context.fill(Path(roundedRect: window, cornerRadius: 3), with: .color(.white.opacity(0.55)))
                        }
                    }
                    x += w + 6
                    index += 1
                }
                // Paw prints wandering across the sky.
                for i in 0..<7 {
                    let px = size.width * (0.06 + 0.14 * Double(i))
                    let py = size.height * (0.16 + (i.isMultiple(of: 2) ? 0.0 : 0.1))
                    drawPaw(context, at: CGPoint(x: px, y: py), size: 13)
                }
            }
        }
    }

    private func drawPaw(_ context: GraphicsContext, at p: CGPoint, size s: CGFloat) {
        let color = GraphicsContext.Shading.color(.white.opacity(0.45))
        context.fill(Path(ellipseIn: CGRect(x: p.x - s * 0.55, y: p.y - s * 0.2, width: s * 1.1, height: s * 0.9)), with: color)
        for (dx, dy) in [(-0.62, -0.62), (-0.2, -0.95), (0.2, -0.95), (0.62, -0.62)] {
            context.fill(Path(ellipseIn: CGRect(x: p.x + dx * s - s * 0.18, y: p.y + dy * s - s * 0.18, width: s * 0.36, height: s * 0.42)), with: color)
        }
    }
}

// MARK: Khmer Dusk

private struct KhmerDuskArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.30, green: 0.09, blue: 0.38), Color(red: 0.90, green: 0.30, blue: 0.46),
                                    Color(red: 1.0, green: 0.62, blue: 0.42), Color(red: 1.0, green: 0.82, blue: 0.52)],
                           startPoint: .top, endPoint: .bottom)
            GeometryReader { geometry in
                let h = geometry.size.height
                Circle()
                    .fill(Color(red: 1, green: 0.88, blue: 0.62))
                    .frame(width: h * 0.55)
                    .shadow(color: Color(red: 1, green: 0.8, blue: 0.5), radius: 30)
                    .position(x: geometry.size.width * 0.78, y: h * 0.62)
                HStack(alignment: .bottom, spacing: h * 0.04) {
                    Temple(width: h * 0.26, tiers: 5)
                    Temple(width: h * 0.34, tiers: 6)
                    Temple(width: h * 0.26, tiers: 5)
                }
                .position(x: geometry.size.width * 0.78, y: h * 0.78)
                Rectangle()
                    .fill(Color(red: 0.24, green: 0.07, blue: 0.24))
                    .frame(height: h * 0.12)
                    .position(x: geometry.size.width / 2, y: h * 0.94)
            }
        }
    }
}

private struct Temple: View {
    let width: CGFloat
    let tiers: Int
    var body: some View {
        let ink = Color(red: 0.24, green: 0.07, blue: 0.24)
        VStack(spacing: 0) {
            Capsule().fill(ink).frame(width: width * 0.08, height: width * 0.28)
            ForEach(0..<tiers, id: \.self) { i in
                let t = CGFloat(i + 1) / CGFloat(tiers)
                Capsule().fill(ink).frame(width: width * (0.25 + 0.75 * t), height: width * 0.18).padding(.top, -width * 0.06)
            }
            Rectangle().fill(ink).frame(width: width * 0.95, height: width * 0.32)
        }
    }
}

// MARK: Neon Night

private struct NeonNightArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.02, blue: 0.12), Color(red: 0.20, green: 0.03, blue: 0.30)],
                           startPoint: .top, endPoint: .bottom)
            GeometryReader { geometry in
                let size = geometry.size
                // A striped neon sun on the horizon.
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.3), Color(red: 1, green: 0.25, blue: 0.7)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: size.height * 0.62)
                    .mask {
                        VStack(spacing: size.height * 0.022) {
                            ForEach(0..<9) { i in
                                Rectangle().frame(height: size.height * (0.07 - Double(i) * 0.005))
                            }
                        }
                    }
                    .shadow(color: Color(red: 1, green: 0.3, blue: 0.7).opacity(0.8), radius: 24)
                    .position(x: size.width * 0.5, y: size.height * 0.56)
                // Perspective grid on the floor.
                Canvas { context, canvas in
                    let horizon = canvas.height * 0.66
                    var grid = Path()
                    for i in -14...14 {
                        let bottomX = canvas.width / 2 + CGFloat(i) * canvas.width / 9
                        grid.move(to: CGPoint(x: canvas.width / 2 + CGFloat(i) * 10, y: horizon))
                        grid.addLine(to: CGPoint(x: bottomX, y: canvas.height))
                    }
                    for j in 1...6 {
                        let t = pow(Double(j) / 6, 1.8)
                        let y = horizon + (canvas.height - horizon) * t
                        grid.move(to: CGPoint(x: 0, y: y))
                        grid.addLine(to: CGPoint(x: canvas.width, y: y))
                    }
                    context.fill(Path(CGRect(x: 0, y: horizon, width: canvas.width, height: canvas.height - horizon)),
                                 with: .color(Color(red: 0.06, green: 0.01, blue: 0.14)))
                    context.stroke(grid, with: .color(Color(red: 0.25, green: 0.95, blue: 1).opacity(0.7)), lineWidth: 1.2)
                }
            }
        }
    }
}

// MARK: Candy Pop

private struct CandyArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 1.0, green: 0.74, blue: 0.86), Color(red: 0.78, green: 0.72, blue: 1.0)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                var rng = Seeded(5)
                let colors: [Color] = [.white, Color(red: 1, green: 0.9, blue: 0.5), Color(red: 0.6, green: 0.95, blue: 0.9), Color(red: 1, green: 0.6, blue: 0.75)]
                for i in 0..<34 {
                    let r = 6 + rng.next() * 26
                    let rect = CGRect(x: rng.next() * size.width - r, y: rng.next() * size.height - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(colors[i % colors.count].opacity(0.35 + rng.next() * 0.3)))
                    // A shine on each bubble.
                    context.fill(Path(ellipseIn: CGRect(x: rect.minX + r * 0.45, y: rect.minY + r * 0.35, width: r * 0.5, height: r * 0.35)),
                                 with: .color(.white.opacity(0.5)))
                }
            }
        }
    }
}

// MARK: Galaxy

private struct GalaxyArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.03, blue: 0.10), Color(red: 0.08, green: 0.04, blue: 0.20)],
                           startPoint: .top, endPoint: .bottom)
            GeometryReader { geometry in
                let size = geometry.size
                Ellipse().fill(Color(red: 0.55, green: 0.25, blue: 0.95).opacity(0.55))
                    .frame(width: size.width * 0.5, height: size.height * 0.7)
                    .blur(radius: 50)
                    .position(x: size.width * 0.3, y: size.height * 0.62)
                Ellipse().fill(Color(red: 0.95, green: 0.3, blue: 0.6).opacity(0.4))
                    .frame(width: size.width * 0.4, height: size.height * 0.5)
                    .blur(radius: 50)
                    .position(x: size.width * 0.62, y: size.height * 0.72)
                Ellipse().fill(Color(red: 0.2, green: 0.6, blue: 1).opacity(0.35))
                    .frame(width: size.width * 0.35, height: size.height * 0.4)
                    .blur(radius: 46)
                    .position(x: size.width * 0.85, y: size.height * 0.45)
            }
            Canvas { context, size in
                var rng = Seeded(42)
                for _ in 0..<160 {
                    let r = 0.4 + rng.next() * 1.4
                    let rect = CGRect(x: rng.next() * size.width, y: rng.next() * size.height, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.3 + rng.next() * 0.6)))
                }
            }
        }
    }
}
