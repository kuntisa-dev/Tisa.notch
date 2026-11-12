//
//  TabSelectionView.swift
//  TisaDynamicIsland
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

/// Home, then the tabs picked in Edit Tabs that fit next to the camera.
var tabs: [TabModel] {
    [TabModel(label: "Home", icon: "house.fill", view: .home)]
        + NotchTab.visible.map { TabModel(label: $0.title, icon: $0.icon, view: $0.view) }
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = TisaViewCoordinator.shared
    @Default(.tisaGlassStyle) private var glassStyle
    /// Read so the bar redraws when Edit Tabs changes the list.
    @Default(.notchTabs) private var notchTabs
    @ObservedObject private var tabEditor = TabBarEditor.shared
    @Namespace var animation

    /// Up to seven tabs must fit left of the camera housing, tighter still in the Standard notch.
    private var tabPadding: CGFloat {
        guard tabs.count > 5 else { return 12 }
        return Defaults[.largeNotch] ? 8 : 6
    }

    var body: some View {
        Group {
            if glassStyle {
                glassTabs
            } else {
                classicTabs
            }
        }
        // Hold the tab bar (or right-click it) to choose and order the tabs.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                withAnimation(.smooth) { tabEditor.setEditing(true) }
            }
        )
        .contextMenu {
            Button(tabEditor.isEditing ? "Done Editing Tabs" : "Edit Tabs…") {
                withAnimation(.smooth) { tabEditor.setEditing(!tabEditor.isEditing) }
            }
            ThemeMenu()
        }
    }

    // Glass bar: a frosted capsule with a lit, accent-tinted pill that slides to the selected tab.
    private var glassTabs: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                let selected = coordinator.currentView == tab.view
                TabButton(label: tab.label, icon: tab.icon, selected: selected, horizontalPadding: tabPadding) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        coordinator.currentView = tab.view
                    }
                }
                .frame(height: 24)
                .foregroundStyle(selected ? HomeStyle.onAccent : Ink.colorIcons ? Ink.tab(tab.view) : Color.white.opacity(0.55))
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
                TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view, horizontalPadding: tabPadding) {
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
    @Default(.notchTheme) private var theme

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    // Solid over the picture themes, like a lit button on glass.
                    colors: theme.effectiveGlass == nil
                        ? [Color.effectiveAccent.opacity(0.75), Color.effectiveAccent.opacity(0.45)]
                        : [Color.effectiveAccent, Color.effectiveAccent.opacity(0.8)],
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
            .shadow(color: Color.effectiveAccent.opacity(theme == .classic ? 0.45 : 0.85), radius: theme == .classic ? 6 : 10, y: 1)
    }
}

#Preview {
    TisaHeader().environmentObject(TisaViewModel())
}
