// Draws the app icon (concept B, "Sunset temples") and two earlier ideas with SwiftUI.
// Run `swift Scripts/app-icon.swift` in an empty folder; it writes A.png, B.png, C.png at 1024 px.
// B.png is AppIcon.appiconset, scaled down with `sips -z`.

import SwiftUI
import AppKit

// macOS icon grid: 1024 canvas, 824 body, continuous corners.
let body: CGFloat = 824
let radius: CGFloat = 185

struct Squircle<Content: View>: View {
    @ViewBuilder let content: Content
    var body_: some View { EmptyView() }
    var body: some View {
        content
            .frame(width: 824, height: 824)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 4))
            .shadow(color: .black.opacity(0.35), radius: 18, y: 12)
            .frame(width: 1024, height: 1024)
    }
}

let rose = Color(red: 0.93, green: 0.27, blue: 0.45)
let coral = Color(red: 1.0, green: 0.55, blue: 0.42)
let plum = Color(red: 0.24, green: 0.07, blue: 0.20)
let ink = Color(red: 0.07, green: 0.06, blue: 0.09)

/// The island: a black pill with a rim of light.
struct Island: View {
    var width: CGFloat = 430
    var height: CGFloat = 118
    var body: some View {
        Capsule()
            .fill(Color.black)
            .frame(width: width, height: height)
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [rose.opacity(0.9), coral.opacity(0.5), .clear], startPoint: .bottom, endPoint: .top), lineWidth: 5))
            .shadow(color: rose.opacity(0.9), radius: 40, y: 18)
    }
}

// A. Island Glow — the island over a grid of Home tiles.
struct IconA: View {
    var body: some View {
        Squircle {
            ZStack {
                LinearGradient(colors: [Color(red: 0.16, green: 0.10, blue: 0.16), ink], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [rose.opacity(0.55), .clear], center: UnitPoint(x: 0.5, y: 0.22), startRadius: 10, endRadius: 520)
                VStack(spacing: 70) {
                    Island()
                    tiles
                }
                .offset(y: 30)
            }
        }
    }
    var tiles: some View {
        let shape = RoundedRectangle(cornerRadius: 42, style: .continuous)
        let tile = { (w: CGFloat, h: CGFloat, c: Color, o: Double) in
            shape.fill(c.opacity(o)).frame(width: w, height: h)
                .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 3))
        }
        return HStack(spacing: 26) {
            tile(250, 250, rose, 0.95)
                .overlay(Image(systemName: "music.note").font(.system(size: 120, weight: .bold)).foregroundStyle(.white))
            VStack(spacing: 26) {
                tile(250, 112, .white, 0.16)
                    .overlay(Capsule().fill(coral).frame(width: 150, height: 22))
                HStack(spacing: 26) {
                    tile(112, 112, .white, 0.16).overlay(Image(systemName: "fan.fill").font(.system(size: 58)).foregroundStyle(.white.opacity(0.9)))
                    tile(112, 112, .white, 0.16).overlay(Image(systemName: "sparkles").font(.system(size: 58)).foregroundStyle(.white.opacity(0.9)))
                }
            }
        }
    }
}

// B. Sunset Island — warm sky, the island, and temple towers at dusk.
struct IconB: View {
    var body: some View {
        Squircle {
            ZStack {
                LinearGradient(colors: [Color(red: 0.36, green: 0.10, blue: 0.42), rose, coral, Color(red: 1.0, green: 0.78, blue: 0.48)],
                               startPoint: .top, endPoint: .bottom)
                Circle().fill(Color(red: 1.0, green: 0.86, blue: 0.62)).frame(width: 300).offset(y: 120)
                    .shadow(color: Color(red: 1, green: 0.8, blue: 0.5), radius: 60)
                TempleSkyline().offset(y: 230)
                Island(width: 400, height: 112).offset(y: -255)
            }
        }
    }
}

/// Three towers built from rounded tiers that narrow to a bud, on a long base: a stylized skyline.
struct Tower: View {
    var width: CGFloat
    var tiers: Int
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(plum).frame(width: width * 0.1, height: width * 0.32)
            ForEach(0..<tiers, id: \.self) { i in
                let t = CGFloat(i + 1) / CGFloat(tiers)
                RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                    .fill(plum)
                    .frame(width: width * (0.28 + 0.72 * t), height: width * 0.2)
                    .padding(.top, -width * 0.05)
            }
            Rectangle().fill(plum).frame(width: width * 1.1, height: width * 0.35)
        }
    }
}

struct TempleSkyline: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 30) {
                Tower(width: 150, tiers: 5)
                Tower(width: 200, tiers: 6)
                Tower(width: 150, tiers: 5)
            }
            Rectangle().fill(plum).frame(width: 824, height: 90)
        }
        .frame(width: 824, height: 364, alignment: .bottom)
    }
}

/// Three stepped towers, a stylized silhouette.
struct Temples: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let base = r.maxY
        func tower(_ cx: CGFloat, _ h: CGFloat, _ w: CGFloat) {
            let steps = 5
            var pts: [CGPoint] = [CGPoint(x: cx - w / 2, y: base)]
            for i in 0..<steps {
                let t = CGFloat(i) / CGFloat(steps)
                let half = w / 2 * (1 - t * 0.85)
                let y = base - h * 0.35 - h * 0.6 * t
                pts.append(CGPoint(x: cx - half, y: y + h * 0.12 / CGFloat(steps)))
                pts.append(CGPoint(x: cx - half, y: y))
            }
            pts.append(CGPoint(x: cx, y: base - h))
            for pt in pts.dropFirst().reversed() { _ = pt }
            let left = pts
            let right = left.reversed().map { CGPoint(x: 2 * cx - $0.x, y: $0.y) }
            p.addLines(left + right.dropFirst())
            p.closeSubpath()
        }
        p.addRect(CGRect(x: r.minX, y: base - 70, width: r.width, height: 70))
        tower(r.midX - 230, 230, 170)
        tower(r.midX + 230, 230, 170)
        tower(r.midX, 320, 210)
        return p
    }
}

// C. Monogram — a T whose top bar is the island.
struct IconC: View {
    var body: some View {
        Squircle {
            ZStack {
                LinearGradient(colors: [Color(red: 0.13, green: 0.09, blue: 0.14), ink], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [coral.opacity(0.35), .clear], center: UnitPoint(x: 0.5, y: 0.75), startRadius: 10, endRadius: 480)
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 60, style: .continuous)
                        .fill(LinearGradient(colors: [rose, coral], startPoint: .top, endPoint: .bottom))
                        .frame(width: 150, height: 470)
                        .shadow(color: rose.opacity(0.6), radius: 30, y: 10)
                        .padding(.top, 70)
                    Island(width: 520, height: 150)
                }
                .offset(y: 10)
            }
        }
    }
}

@MainActor func save<V: View>(_ view: V, _ name: String) {
    let renderer = ImageRenderer(content: view.frame(width: 1024, height: 1024))
    renderer.scale = 1
    guard let cg = renderer.cgImage else { print("fail", name); return }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: name))
    print("wrote", name)
}

MainActor.assumeIsolated {
    save(IconA(), "A.png")
    save(IconB(), "B.png")
    save(IconC(), "C.png")
    let row = HStack(spacing: 0) {
        ForEach(["A", "B", "C"], id: \.self) { name in
            VStack(spacing: 0) {
                Image(nsImage: NSImage(contentsOfFile: name + ".png")!).resizable().frame(width: 512, height: 512)
                Text(name).font(.system(size: 48, weight: .bold)).foregroundStyle(.black)
            }
        }
    }
    .padding(30)
    .background(Color(white: 0.9))
    let renderer = ImageRenderer(content: row)
    let rep = NSBitmapImageRep(cgImage: renderer.cgImage!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "preview.png"))
}
