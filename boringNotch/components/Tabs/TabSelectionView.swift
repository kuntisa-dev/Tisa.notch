//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    // Stable per view, because the tab list is rebuilt from settings on every redraw.
    var id: NotchViews { view }
    let label: String
    let icon: String
    let view: NotchViews
}

var tabs: [TabModel] {
    var result = [TabModel(label: "Home", icon: "house.fill", view: .home)]
    if Defaults[.boringShelf] {
        result.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf))
    }
    if Defaults[.enableClipboardHistory] {
        result.append(TabModel(label: "Clipboard", icon: "doc.on.clipboard.fill", view: .clipboard))
    }
    if Defaults[.enablePhotoBooth] {
        result.append(TabModel(label: "Photo Booth", icon: "camera.fill", view: .photoBooth))
    }
    return result
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.tisaGlassStyle) private var glassStyle
    @Namespace var animation

    var body: some View {
        if glassStyle {
            glassTabs
        } else {
            classicTabs
        }
    }

    // Glass bar: a frosted capsule with a lit, accent-tinted pill that slides to the selected tab.
    private var glassTabs: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                let selected = coordinator.currentView == tab.view
                TabButton(label: tab.label, icon: tab.icon, selected: selected) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        coordinator.currentView = tab.view
                    }
                }
                .frame(height: 24)
                .foregroundStyle(selected ? Color.white : Color.white.opacity(0.55))
                .background {
                    if selected {
                        SelectedTabPill()
                            .matchedGeometryEffect(id: "glassPill", in: animation)
                    }
                }
            }
        }
        .padding(2)
        .tisaGlass(in: Capsule())
    }

    private var classicTabs: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                    withAnimation(.smooth) {
                        coordinator.currentView = tab.view
                    }
                }
                .frame(height: 26)
                .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                .background {
                    if tab.view == coordinator.currentView {
                        Capsule()
                            .fill(Color(nsColor: .secondarySystemFill))
                            .matchedGeometryEffect(id: "capsule", in: animation)
                    }
                }
            }
        }
        .clipShape(Capsule())
    }
}

private struct SelectedTabPill: View {
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color.effectiveAccent.opacity(0.75), Color.effectiveAccent.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Capsule().stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            )
            .shadow(color: Color.effectiveAccent.opacity(0.45), radius: 6, y: 1)
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
