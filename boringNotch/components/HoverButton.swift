//
//  HoverButton.swift
//  boringNotch
//
//  Created by Kraigo on 04.09.2024.
//

import Defaults
import SwiftUI

struct HoverButton: View {
    var icon: String
    var iconColor: Color = .primary
    var scale: Image.Scale = .medium
    var action: () -> Void
    var contentTransition: ContentTransition = .symbolEffect;

    @Default(.tisaGlassStyle) private var glassStyle
    @State private var isHovering = false

    var body: some View {
        if glassStyle {
            glassBody
        } else {
            classicBody
        }
    }

    // MARK: Glass

    private var isPrimary: Bool { scale == .large }

    private var glassBody: some View {
        let size: CGFloat = isPrimary ? 40 : 30

        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: isPrimary ? 18 : 13, weight: isPrimary ? .bold : .semibold))
                .foregroundStyle(iconColor)
                .contentTransition(contentTransition)
                .frame(width: size, height: size)
                .contentShape(Circle())
                .background {
                    // Drawn glass: this button sits inside a drawingGroup, which can't host the system material.
                    if isPrimary {
                        DrawnGlass(shape: Circle(), tint: Color.white.opacity(isHovering ? 0.35 : 0.18))
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    } else if isHovering {
                        DrawnGlass(shape: Circle())
                            .transition(.opacity.combined(with: .scale(scale: 0.7)))
                    }
                }
                .scaleEffect(isHovering ? 1.06 : 1)
        }
        .buttonStyle(GlassPressStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }

    // MARK: Classic

    private var classicBody: some View {
        let size = CGFloat(scale == .large ? 40 : 30)

        return Button(action: action) {
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .frame(width: size, height: size)
                .overlay {
                    Capsule()
                        .fill(isHovering ? Color.gray.opacity(0.2) : .clear)
                        .frame(width: size, height: size)
                        .overlay {
                            Image(systemName: icon)
                                .foregroundColor(iconColor)
                                .contentTransition(contentTransition)
                                .font(scale == .large ? .largeTitle : .body)
                        }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.3)) {
                isHovering = hovering
            }
        }
    }
}
