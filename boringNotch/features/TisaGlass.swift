//
//  TisaGlass.swift
//  Tisa Notch
//
//  The "Liquid Glass" look for the open notch: glass surfaces, a soft
//  album-color glow behind the content, and a light rim on the notch edge.
//  On macOS 26 it uses the system Liquid Glass material; on older macOS a
//  hand-drawn glass (translucent fill + specular rim) gives the same feel.
//

import Defaults
import SwiftUI

extension Defaults.Keys {
    /// Glass surfaces, rim light and refined controls in the open notch.
    static let tisaGlassStyle = Key<Bool>("tisaGlassStyle", default: true)
    /// Blurred album-art color that fills the open notch while music plays.
    static let tisaAmbientGlow = Key<Bool>("tisaAmbientGlow", default: true)
    /// Use macOS 26's own Liquid Glass material where it is available.
    static let tisaNativeGlass = Key<Bool>("tisaNativeGlass", default: true)
}

// MARK: - Glass surface

extension View {
    /// Puts a glass surface behind the view, shaped like `shape`.
    ///
    /// - Parameters:
    ///   - tint: Optional color mixed into the glass.
    ///   - native: Allow the system Liquid Glass material (macOS 26+). Pass `false`
    ///     inside `drawingGroup()` content, which can't host the system material.
    @ViewBuilder
    func tisaGlass<S: Shape>(in shape: S, tint: Color? = nil, native: Bool = true) -> some View {
        if native && Defaults[.tisaNativeGlass] {
            if #available(macOS 26.0, *) {
                self.glassEffect(tisaSystemGlass(tint: tint), in: shape)
            } else {
                self.background { DrawnGlass(shape: shape, tint: tint) }
            }
        } else {
            self.background { DrawnGlass(shape: shape, tint: tint) }
        }
    }
}

@available(macOS 26.0, *)
private func tisaSystemGlass(tint: Color?) -> Glass {
    if let tint {
        return Glass.regular.tint(tint)
    }
    return Glass.regular
}

/// Hand-drawn glass: dark translucent body, a sheen across the top,
/// and a rim that is brightest on the upper-left edge.
struct DrawnGlass<S: Shape>: View {
    let shape: S
    var tint: Color? = nil

    var body: some View {
        ZStack {
            shape.fill(Color.white.opacity(0.07))
            if let tint {
                shape.fill(tint.opacity(0.28))
            }
            shape.fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            shape.stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.38),
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.04),
                        Color.white.opacity(0.18),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Notch backdrop

/// Replaces the flat black behind the notch. The top stays pure black so
/// the open notch still blends into the camera housing.
struct NotchBackdrop: View {
    let isOpen: Bool

    @ObservedObject private var music = MusicManager.shared
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @Default(.tisaGlassStyle) private var glassStyle
    @Default(.tisaAmbientGlow) private var ambientGlow

    private var showGlow: Bool {
        isOpen && glassStyle && ambientGlow
            && coordinator.currentView == .home
            && (music.isPlaying || !music.isPlayerIdle)
    }

    var body: some View {
        ZStack {
            Color.black

            if isOpen && glassStyle {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.2),
                        .init(color: Color(white: 0.075), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .transition(.opacity)
            }

            if showGlow {
                Image(nsImage: music.albumArt)
                    .resizable()
                    .scaledToFill()
                    .saturation(1.6)
                    .blur(radius: 60)
                    .opacity(music.isPlaying ? 0.55 : 0.25)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .clear, location: 0.18),
                                .init(color: .black.opacity(0.85), location: 0.65),
                                .init(color: .black, location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.smooth(duration: 0.6), value: showGlow)
        .animation(.smooth(duration: 0.6), value: music.isPlaying)
    }
}

/// Thin light along the sides and bottom edge of the open notch.
struct NotchRimLight<S: Shape>: View {
    let shape: S

    var body: some View {
        shape
            .stroke(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.3),
                        .init(color: Color.white.opacity(0.10), location: 0.7),
                        .init(color: Color.white.opacity(0.26), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }
}

// MARK: - Controls

/// Shrinks a little while pressed, with a springy release.
struct GlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Round glass button used in the notch header (mirror, settings).
struct GlassCircleButton: View {
    let icon: String
    var help: String = ""
    let action: () -> Void

    @Default(.tisaGlassStyle) private var glassStyle
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(hovering ? 1 : 0.85))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
                .modifier(GlassCircleBackground(enabled: glassStyle, hovering: hovering))
        }
        .buttonStyle(GlassPressStyle())
        .help(help)
        .onHover { isHovering in
            withAnimation(.smooth(duration: 0.2)) { hovering = isHovering }
        }
    }
}

private struct GlassCircleBackground: ViewModifier {
    let enabled: Bool
    let hovering: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .tisaGlass(in: Circle(), tint: hovering ? Color.white.opacity(0.25) : nil)
                .scaleEffect(hovering ? 1.06 : 1)
        } else {
            content.background(Circle().fill(.black))
        }
    }
}

// MARK: - Settings

/// Section placed at the top of Settings › Appearance.
struct TisaGlassSection: View {
    @Default(.tisaGlassStyle) private var glassStyle

    var body: some View {
        Section {
            Defaults.Toggle(key: .tisaGlassStyle) {
                Text("Liquid Glass style")
            }
            Defaults.Toggle(key: .tisaAmbientGlow) {
                Text("Album color glow behind the player")
            }
            .disabled(!glassStyle)
            if #available(macOS 26.0, *) {
                Defaults.Toggle(key: .tisaNativeGlass) {
                    Text("Use the system Liquid Glass material")
                }
                .disabled(!glassStyle)
            }
        } header: {
            Text("Tisa Notch look")
        } footer: {
            Text("Glass tabs, buttons and cards, a soft glow in your album's colors and a light rim around the open notch. Turn it off for the original flat black look.")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}
