//
//  ThemesSettings.swift
//  TisaDynamicIsland
//
//  Settings › Themes: a gallery of little notches dressed in each theme, and the options
//  for the chosen one. The tab bar's right-click menu has the same list (ThemeMenu).
//

import Defaults
import SwiftUI

enum ThemeSwitcher {
    /// Picks a theme. A picture theme asks for its picture the first time.
    @MainActor
    static func select(_ theme: NotchTheme) {
        if theme.usesPicture && ThemePicture.image(for: theme) == nil {
            ThemePicture.choose(for: theme)
            return
        }
        Defaults[.notchTheme] = theme
        NotificationCenter.default.post(name: .notchThemeChanged, object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("AccentColorChanged"), object: nil)
    }
}

/// Theme submenu for right-click menus in the notch.
struct ThemeMenu: View {
    @Default(.notchTheme) private var current

    var body: some View {
        Menu("Theme") {
            ForEach(NotchTheme.allCases) { theme in
                Button {
                    ThemeSwitcher.select(theme)
                } label: {
                    if theme == current {
                        Label(theme.title, systemImage: "checkmark")
                    } else {
                        Text(theme.title)
                    }
                }
            }
            Divider()
            Button("Choose Picture…") { ThemePicture.choose(for: current.usesPicture ? current : .myPicture) }
        }
    }
}

struct ThemesSettings: View {
    @Default(.notchTheme) private var current
    @Default(.themeSetsAccent) private var setsAccent
    @Default(.themePictureDim) private var dim
    @Default(.themePictureBlur) private var blur
    @Default(.themePictureFile) private var pictureFile
    @Default(.themePictures) private var pictures
    @Default(.themePictureDims) private var pictureDims
    @Default(.themePictureOffsets) private var pictureOffsets
    @Default(.themeGlowTiles) private var glowTiles
    @Default(.cardGlassChoice) private var glassChoice
    @Default(.themeColorIcons) private var colorIcons

    private let columns = [GridItem(.adaptive(minimum: 196), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(NotchTheme.allCases) { theme in
                        ThemeCard(theme: theme, selected: theme == current) {
                            withAnimation(.smooth(duration: 0.25)) { ThemeSwitcher.select(theme) }
                        }
                    }
                }

                options
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: Binding(get: { setsAccent }, set: { on in
                setsAccent = on
                NotificationCenter.default.post(name: NSNotification.Name("AccentColorChanged"), object: nil)
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use the theme's colors")
                    Text("Buttons, bars and highlights take the theme's color. Off keeps the accent from Appearance.")
                        .font(.system(size: 11))
                        .foregroundStyle(TisaPalette.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding(14)

            if current != .classic {
                Divider().overlay(TisaPalette.cardBorder)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Card glass")
                        Spacer()
                        Picker("Card glass", selection: $glassChoice) {
                            ForEach(CardGlassChoice.allCases) { choice in
                                Text(choice.title).tag(choice)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 380)
                    }
                    Text(glassChoice.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(TisaPalette.secondary)
                }
                .padding(14)
            }

            if current.usesPicture {
                Divider().overlay(TisaPalette.cardBorder)
                Toggle(isOn: $colorIcons) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Colour icons")
                        Text("The play button, music buttons, tab icons and the buttons at the top right in color, so they show over a bright picture.")
                            .font(.system(size: 11))
                            .foregroundStyle(TisaPalette.secondary)
                    }
                }
                .toggleStyle(.switch)
                .padding(14)
            }

            Divider().overlay(TisaPalette.cardBorder)
            Toggle(isOn: $glowTiles) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Glowing tiles")
                    Text("Home's tiles get glossy tops and edges that glow in the theme's color, and the music controls get a glass bar.")
                        .font(.system(size: 11))
                        .foregroundStyle(TisaPalette.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding(14)

            if current.usesPicture {
                let chosen = ThemePicture.file(for: current) != nil
                let darken = Binding(get: { ThemePicture.dim(for: current) }, set: { ThemePicture.setDim($0, for: current) })
                let down = Binding(get: { ThemePicture.offset(for: current) }, set: { ThemePicture.setOffset($0, for: current) })
                let _ = (pictureFile, pictures, pictureDims, pictureOffsets, dim)
                Divider().overlay(TisaPalette.cardBorder)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(current.title) picture")
                        Text(chosen ? "A copy is kept in Application Support › Tisa Dynamic Island › Themes" : "None chosen yet")
                            .font(.system(size: 11))
                            .foregroundStyle(TisaPalette.secondary)
                    }
                    Spacer()
                    Button(chosen ? "Change Picture…" : "Choose Picture…") { ThemePicture.choose(for: current) }
                }
                .padding(14)
                Divider().overlay(TisaPalette.cardBorder)
                slider("Darken", value: darken, range: 0...0.8, text: "\(Int(darken.wrappedValue * 100))%")
                Divider().overlay(TisaPalette.cardBorder)
                slider("Move down", value: down, range: 0...60, text: down.wrappedValue < 0.5 ? "Off" : "\(Int(down.wrappedValue))")
                if current == .myPicture {
                    Divider().overlay(TisaPalette.cardBorder)
                    slider("Blur", value: $blur, range: 0...30, text: blur < 0.5 ? "Off" : "\(Int(blur))")
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(TisaPalette.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(TisaPalette.cardBorder))
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, text: String) -> some View {
        HStack(spacing: 12) {
            Text(title).frame(width: 74, alignment: .leading)
            Slider(value: value, in: range)
            Text(text)
                .monospacedDigit()
                .foregroundStyle(TisaPalette.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(14)
    }
}

/// A little open notch dressed in the theme, with pretend tabs and tiles.
private struct ThemeCard: View {
    let theme: NotchTheme
    let selected: Bool
    let choose: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            preview
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(theme.title)
                        .font(.system(size: 12.5, weight: .semibold, design: theme.fontDesign))
                    Text(theme.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(TisaPalette.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.accent ?? Color.effectiveAccent)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(hovering ? Color.white.opacity(0.08) : TisaPalette.card))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? (theme.accent ?? Color.effectiveAccent) : TisaPalette.cardBorder, lineWidth: selected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(perform: choose)
        .onHover { inside in withAnimation(.smooth(duration: 0.15)) { hovering = inside } }
        .help("Use \(theme.title)")
    }

    private var preview: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16, style: .continuous)
        let accent = theme.accent ?? Color.effectiveAccent
        return ZStack(alignment: .top) {
            Color.black
            ThemeBackdrop(theme: theme)
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Capsule().fill(accent).frame(width: 16, height: 8)
                    ForEach(0..<4) { _ in Circle().fill(.white.opacity(0.5)).frame(width: 5, height: 5) }
                    Spacer()
                    Circle().fill(.white.opacity(0.35)).frame(width: 7, height: 7)
                }
                HStack(spacing: 5) {
                    tile.frame(width: 50)
                        .overlay(Capsule().fill(accent).frame(width: 26, height: 4).padding(.bottom, 8), alignment: .bottom)
                    VStack(spacing: 5) { tile; tile }
                    tile
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 9)
            // The camera in the middle of the top edge.
            Capsule().fill(.black).frame(width: 46, height: 10).padding(.top, 2)
        }
        .frame(height: 92)
        .clipShape(shape)
    }

    private var tile: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.black.opacity(max(theme.cardShade, 0.0)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
    }
}
