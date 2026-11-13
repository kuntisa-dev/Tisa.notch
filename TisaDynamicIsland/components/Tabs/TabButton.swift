//
//  TabButton.swift
//  TisaDynamicIsland
//
//  Created by Hugo Persson on 2024-08-24.
//

import SwiftUI

struct TabButton: View {
    let label: String
    let icon: String
    let selected: Bool
    /// Narrower when many tabs share the bar.
    var horizontalPadding: CGFloat = 12
    let onClick: () -> Void

    /// Every icon gets the same width so the tab bar can work out what fits beside the camera.
    static let iconWidth: CGFloat = 18

    @State private var hovering = false

    var body: some View {
        Button(action: onClick) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: selected ? .bold : .semibold))
                .symbolEffect(.bounce, value: selected)
                .frame(width: Self.iconWidth)
                .padding(.horizontal, horizontalPadding)
                .frame(maxHeight: .infinity)
                .contentShape(Capsule())
                .scaleEffect(hovering && !selected ? 1.08 : 1)
        }
        .buttonStyle(GlassPressStyle())
        .help(label)
        .onHover { isHovering in
            withAnimation(.smooth(duration: 0.2)) { hovering = isHovering }
        }
    }
}

#Preview {
    TabButton(label: "Home", icon: "tray.fill", selected: true) {
        print("Tapped")
    }
}
