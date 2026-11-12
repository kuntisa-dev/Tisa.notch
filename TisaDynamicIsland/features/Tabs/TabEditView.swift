//
//  TabEditView.swift
//  TisaDynamicIsland
//
//  Edit Tabs, shown in the notch in place of the page: the top row is the tab bar
//  (drag to reorder, − to take a tab out), the bottom row is every other tab (+ adds
//  it). The real tab bar above updates as you go.
//

import Defaults
import SwiftUI

struct TabEditView: View {
    @ObservedObject private var editor = TabBarEditor.shared
    @ObservedObject private var coordinator = TisaViewCoordinator.shared
    @Default(.notchTabs) private var notchTabs
    @Default(.largeNotch) private var largeNotch

    @State private var draggingTab: NotchTab?
    /// The dragged chip's left edge, following the pointer.
    @State private var dragX: CGFloat = 0
    @State private var dragStartX: CGFloat = 0

    private static let chipWidth: CGFloat = 70
    private static let gap: CGFloat = 6
    private static var step: CGFloat { chipWidth + gap }

    private var shown: [NotchTab] { NotchTab.visible }
    private var isFull: Bool { shown.count >= NotchTab.maxVisible }
    private var more: [NotchTab] { NotchTab.allCases.filter { !shown.contains($0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            barRow
            moreRow
        }
        .padding(.top, 2)
        .onDisappear { editor.setEditing(false) }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HomeLabel(title: "Tab bar", trailing: nil)
                .fixedSize()
            Text("\(shown.count + 1) of \(NotchTab.maxVisible + 1)")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isFull ? HomeStyle.warning : HomeStyle.secondary)
            Text(isFull ? "Full. Take a tab out to add another" : "Drag to reorder · − to take out · + to add")
                .font(.system(size: 10))
                .foregroundStyle(HomeStyle.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button("Reset") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    notchTabs = NotchTab.defaultOrder
                }
            }
            .buttonStyle(HomePillButtonStyle(prominent: false))
            Button("Done") {
                withAnimation(.smooth) { editor.setEditing(false) }
            }
            .buttonStyle(HomePillButtonStyle(prominent: true))
            .keyboardShortcut(.defaultAction)
        }
        .frame(height: 24)
    }

    // MARK: In the tab bar

    private var barRow: some View {
        HStack(spacing: Self.gap) {
            TabChip(icon: "house.fill", title: "Home", badge: .locked)
            ZStack(alignment: .leading) {
                ForEach(Array(shown.enumerated()), id: \.element) { index, tab in
                    let dragging = draggingTab == tab
                    TabChip(icon: tab.icon, title: tab.title, badge: .remove) {
                        remove(tab)
                    }
                    .scaleEffect(dragging ? 1.08 : 1)
                    .shadow(color: .black.opacity(dragging ? 0.5 : 0), radius: 8, y: 4)
                    .offset(x: dragging ? dragX : CGFloat(index) * Self.step)
                    .zIndex(dragging ? 1 : 0)
                    .gesture(reorderGesture(for: tab, index: index))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(width: CGFloat(NotchTab.maxVisible) * Self.step - Self.gap, alignment: .leading)
            .frame(height: TabChip.height)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: shown)
    }

    private func reorderGesture(for tab: NotchTab, index: Int) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if draggingTab != tab {
                    dragStartX = CGFloat(index) * Self.step
                    HomeHaptics.tap()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { draggingTab = tab }
                }
                let maxX = CGFloat(max(0, shown.count - 1)) * Self.step
                dragX = min(max(dragStartX + value.translation.width, -8), maxX + 8)
                let target = min(max(Int((dragX / Self.step).rounded()), 0), shown.count - 1)
                guard let current = shown.firstIndex(of: tab), target != current else { return }
                HomeHaptics.tap()
                move(tab, to: target)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { draggingTab = nil }
            }
    }

    // MARK: More tabs

    private var moreRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            HomeLabel(title: "More tabs", trailing: nil)
            if more.isEmpty {
                Text("Every tab is in the bar.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(HomeStyle.secondary)
                    .frame(height: TabChip.height, alignment: .center)
            } else {
                HStack(spacing: Self.gap) {
                    ForEach(more) { tab in
                        let blocked = !tab.isAvailable
                        TabChip(icon: tab.icon, title: tab.title, badge: blocked ? .none : .add) {
                            add(tab)
                        }
                        .onTapGesture { add(tab) }
                        .opacity(blocked || isFull ? 0.4 : 1)
                        .allowsHitTesting(!blocked && !isFull)
                        .help(tab.unavailableReason ?? (isFull ? "The tab bar is full" : "Add \(tab.title)"))
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.8), value: more)
            }
        }
    }

    // MARK: Changes

    /// Rewrites the saved order so the visible tabs come first in their new order.
    private func save(_ visible: [NotchTab]) {
        let rest = notchTabs.filter { !visible.contains($0) }
        notchTabs = visible + rest
    }

    private func move(_ tab: NotchTab, to target: Int) {
        var visible = shown
        visible.removeAll { $0 == tab }
        visible.insert(tab, at: min(target, visible.count))
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { save(visible) }
    }

    private func remove(_ tab: NotchTab) {
        HomeHaptics.tap()
        if coordinator.currentView == tab.view {
            coordinator.currentView = .home
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            notchTabs.removeAll { $0 == tab }
        }
    }

    private func add(_ tab: NotchTab) {
        guard !isFull, tab.isAvailable else { return }
        HomeHaptics.tap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            save(shown + [tab])
        }
    }
}

/// A tab as a tile: its icon and name, with a corner badge.
private struct TabChip: View {
    enum Badge { case remove, add, locked, none }

    static let height: CGFloat = 58

    let icon: String
    let title: String
    let badge: Badge
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(Color(white: 0.9))
        .frame(width: 70, height: Self.height)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topLeading) { badgeView }
    }

    @ViewBuilder
    private var badgeView: some View {
        switch badge {
        case .remove:
            badgeButton(symbol: "minus", fill: Color(white: 0.82), foreground: .black)
        case .add:
            badgeButton(symbol: "plus", fill: Color.effectiveAccent, foreground: HomeStyle.onAccent)
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(HomeStyle.secondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color(white: 0.2)))
                .offset(x: -5, y: -5)
                .help("Home is always first")
        case .none:
            EmptyView()
        }
    }

    private func badgeButton(symbol: String, fill: Color, foreground: Color) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(foreground)
                .frame(width: 18, height: 18)
                .background(Circle().fill(fill))
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        }
        .buttonStyle(GlassPressStyle())
        .offset(x: -5, y: -5)
    }
}
