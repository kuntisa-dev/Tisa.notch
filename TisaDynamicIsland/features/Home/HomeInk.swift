//
//  HomeInk.swift
//  TisaDynamicIsland
//
//  Readable text over the picture themes. Home's tiles are see-through there, so white text
//  can vanish over a bright part of the picture. With a picture theme on, each label or number
//  gets its own color and sits on a small dark glass pill, and list rows get a darker backing.
//  With any other theme these modifiers leave the view exactly as it was.
//

import Defaults
import SwiftUI

/// The colors text takes over the picture themes.
enum Ink {
    static let title = Color.white
    static let time = Color(white: 0.9)
    static let reset = Color(red: 0.99, green: 0.9, blue: 0.54)
    static let cool = Color(red: 0.49, green: 0.83, blue: 0.99)
    static let heat = Color(red: 1.0, green: 0.55, blue: 0.24)
    static let good = Color(red: 0.29, green: 0.87, blue: 0.5)

    /// Each AI tool's name in its own color, like the design.
    static func provider(_ name: String) -> Color {
        let key = name.lowercased()
        if key.contains("claude") { return Color(red: 1.0, green: 0.6, blue: 0.36) }
        if key.contains("codex") || key.contains("openai") { return Color(red: 0.29, green: 0.87, blue: 0.5) }
        if key.contains("cursor") { return cool }
        if key.contains("gemini") { return Color(red: 0.55, green: 0.66, blue: 1.0) }
        if key.contains("copilot") { return Color(red: 0.77, green: 0.62, blue: 1.0) }
        return detail
    }

    /// Quick buttons: each in its own color, like their icons in the design.
    static func quick(_ tile: HomeQuickTile) -> Color {
        switch tile {
        case .mic: return Color(red: 1.0, green: 0.56, blue: 0.64)
        case .mirror: return cool
        case .photoBooth: return Color(red: 0.99, green: 0.83, blue: 0.3)
        case .shelf: return Color(red: 0.77, green: 0.71, blue: 0.99)
        }
    }

    /// The theme's color, lightened so it reads on the dark pill (artist, details, headers).
    static var detail: Color { Color.effectiveAccent.mix(with: .white, by: 0.35) }

    static var active: Bool { Defaults[.notchTheme].usesPicture }

    /// Buttons and tab icons in color (Settings › Themes › Colour icons).
    static var colorIcons: Bool { active && Defaults[.themeColorIcons] }

    /// Music buttons beside the play button: the theme's color, lightened.
    static var control: Color { colorIcons ? detail : .white }

    /// The play button: the theme's color with a white icon, or the usual white with a black one.
    static var playFill: AnyShapeStyle {
        colorIcons
            ? AnyShapeStyle(LinearGradient(colors: [Color.effectiveAccent.mix(with: .white, by: 0.2), Color.effectiveAccent.mix(with: .black, by: 0.25)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
            : AnyShapeStyle(Color.white)
    }
    static var playIcon: Color { colorIcons ? .white : .black }

    /// Each tab's icon in its own color.
    static func tab(_ view: NotchViews) -> Color {
        switch view {
        case .home: return .white
        case .apps: return Color(red: 0.75, green: 0.6, blue: 1.0)
        case .aiUsage: return provider("claude")
        case .fans: return cool
        case .downloads: return good
        case .calendar: return Color(red: 1.0, green: 0.5, blue: 0.5)
        case .clipboard: return Color(red: 0.99, green: 0.83, blue: 0.3)
        case .shelf: return Color(red: 0.77, green: 0.71, blue: 0.99)
        case .photoBooth: return Color(red: 1.0, green: 0.56, blue: 0.64)
        }
    }

    /// The round buttons at the top right (edit, mirror, settings).
    static func headerButton(_ symbol: String) -> Color {
        if symbol.hasPrefix("pencil") { return reset }
        if symbol.hasPrefix("checkmark") { return good }
        if symbol.hasPrefix("web.camera") { return cool }
        if symbol.hasPrefix("gearshape") { return cool }
        return .white
    }

    /// Backing for rows and small buttons: dark over a picture, the usual faint white otherwise.
    static var rowFill: Color { active ? Color.black.opacity(0.48) : Color.white.opacity(0.055) }
}

private struct InkPill: ViewModifier {
    let color: Color
    @Default(.notchTheme) private var theme

    func body(content: Content) -> some View {
        if theme.usesPicture {
            content
                .foregroundStyle(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(red: 0.03, green: 0.04, blue: 0.06).opacity(0.58))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                )
        } else {
            content
        }
    }
}

private struct InkPlate: ViewModifier {
    @Default(.notchTheme) private var theme

    func body(content: Content) -> some View {
        if theme.usesPicture {
            content
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(red: 0.03, green: 0.04, blue: 0.06).opacity(0.55))
                )
        } else {
            content
        }
    }
}

private struct InkColor<Normal: ShapeStyle>: ViewModifier {
    let normal: Normal?
    let picture: Color
    @Default(.notchTheme) private var theme

    func body(content: Content) -> some View {
        if theme.usesPicture {
            content.foregroundStyle(picture)
        } else if let normal {
            content.foregroundStyle(normal)
        } else {
            content
        }
    }
}

extension View {
    /// On a picture theme: this color, on a small dark pill. Otherwise unchanged.
    func ink(_ picture: Color) -> some View {
        modifier(InkPill(color: picture))
    }

    /// Like `ink(_:)`, but keeps `normal` as the color everywhere else.
    func ink<S: ShapeStyle>(_ normal: S, _ picture: Color) -> some View {
        modifier(InkColor(normal: normal, picture: picture)).modifier(InkPill(color: picture))
    }

    /// Color only, no pill: for text already on a dark plate or row.
    func inkColor<S: ShapeStyle>(_ normal: S, _ picture: Color) -> some View {
        modifier(InkColor(normal: normal, picture: picture))
    }

    /// A dark plate behind a group, such as a list, on a picture theme.
    func inkPlate() -> some View {
        modifier(InkPlate())
    }
}
