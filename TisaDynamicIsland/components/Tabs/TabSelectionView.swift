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

    /// The bar's tabs, plus the page showing now when it was opened from elsewhere (a Home
    /// tile, a file dragged in) and isn't in the bar, so a tab is always lit and you can see where you are.
    private var shownTabs: [TabModel] {
        var bar = tabs
        if !bar.contains(where: { $0.view == coordinator.currentView }),
           let extra = NotchTab.allCases.first(where: { $0.view == coordinator.currentView }) {
            bar.append(TabModel(label: extra.title, icon: extra.icon, view: extra.view))
        }
        // On a very wide notch, drop tabs from the end rather than let one sit half under
        // the camera, but keep the page showing now.
        guard let availableWidth else { return bar }
        let fitting = max(2, Int((availableWidth - Self.margin - Self.barInset + Self.spacing) / (Self.iconWidth + 2 * Self.minPadding + Self.spacing)))
        guard bar.count > fitting else { return bar }
        let current = bar.first { $0.view == coordinator.currentView }
        var kept = Array(bar.prefix(fitting))
        if let current, !kept.contains(where: { $0.view == current.view }) {
            kept[fitting - 1] = current
        }
        return kept
    }

    private static let iconWidth: CGFloat = TabButton.iconWidth
    private static let spacing: CGFloat = 2
    private static let barInset: CGFloat = 4
    private static let margin: CGFloat = 6
    private static let minPadding: CGFloat = 3

    /// Room left of the camera housing. Notch width differs by MacBook model and display
    /// scaling, so the tabs size themselves to the real space instead of a fixed count.
    var availableWidth: CGFloat?

    /// Spacing around each icon: roomy when there is space, down to 3 so every tab stays clear of the camera.
    private var tabPadding: CGFloat {
        let count = shownTabs.count
        if let availableWidth {
            let n = CGFloat(count)
            let fit = (availableWidth - Self.margin - Self.barInset - Self.spacing * (n - 1) - Self.iconWidth * n) / (2 * n)
            return min(12, max(Self.minPadding, fit.rounded(.down)))
        }
        guard count > 5 else { return 12 }
        if count > 7 { return Defaults[.largeNotch] ? 6 : 4 }
        return Defaults[.largeNotch] ? 8 : 6
    }

    /// Picking a tab also leaves Edit Tabs, which otherwise covers the page.
    private func select(_ view: NotchViews) {
        if tabEditor.isEditing { tabEditor.setEditing(false) }
        coordinator.currentView = view
    }

    var body: some View {
        Group {
            if glassStyle {
                glassTabs
            } else {
                classicTabs
            }
        }
        // Right-click the tab bar to choose and order the tabs. (A long press here used to
        // fire on slow clicks and jump into Edit Tabs by accident.)
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
            ForEach(shownTabs) { tab in
                let selected = coordinator.currentView == tab.view
                TabButton(label: tab.label, icon: tab.icon, selected: selected, horizontalPadding: tabPadding) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        select(tab.view)
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
            ForEach(shownTabs) { tab in
                TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view, horizontalPadding: tabPadding) {
                    withAnimation(.smooth) {
                        select(tab.view)
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
