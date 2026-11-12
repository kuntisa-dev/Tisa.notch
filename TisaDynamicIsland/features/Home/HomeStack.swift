//
//  HomeStack.swift
//  TisaDynamicIsland
//
//  A Home tile that holds more than one widget. Swipe sideways with two fingers (or
//  click the dots) to switch; up and down stays free for opening and closing the notch.
//  Which widget is showing is remembered until the app quits.
//

import SwiftUI

@MainActor
final class HomeStackState: ObservableObject {
    static let shared = HomeStackState()

    @Published private var shown: [UUID: HomeWidget] = [:]

    private init() {}

    /// The widget the tile is showing now.
    func current(in box: HomeBox) -> HomeWidget {
        if let widget = shown[box.id], box.members.contains(widget) { return widget }
        return box.widget
    }

    func show(_ widget: HomeWidget, in box: HomeBox) {
        shown[box.id] = widget
    }
}

struct HomeStackView: View {
    let box: HomeBox
    @ObservedObject private var state = HomeStackState.shared

    var body: some View {
        if box.isStack {
            pages
                .clipShape(RoundedRectangle(cornerRadius: HomeMetrics.cornerRadius, style: .continuous))
                .overlay(alignment: .trailing) { dots }
        } else {
            HomeWidgetView(box: box)
        }
    }

    private var position: Binding<HomeWidget?> {
        Binding(
            get: { state.current(in: box) },
            set: { widget in
                guard let widget, widget != state.current(in: box) else { return }
                HomeHaptics.tap()
                state.show(widget, in: box)
            }
        )
    }

    private var pages: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(box.members) { member in
                        HomeWidgetView(box: box.showing(member))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .id(member)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.never)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: position)
        }
    }

    /// One dot per widget, on the right edge like a page indicator turned on its side.
    private var dots: some View {
        let current = state.current(in: box)
        return VStack(spacing: 3) {
            ForEach(box.members) { member in
                Circle()
                    .fill(Color.white.opacity(member == current ? 0.9 : 0.35))
                    .frame(width: 4, height: 4)
                    .padding(1.5)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            state.show(member, in: box)
                        }
                    }
                    .help(member.title)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 1)
        .background(Capsule().fill(Color.black.opacity(0.35)))
        .padding(.trailing, 3)
        .animation(.smooth(duration: 0.2), value: current)
    }
}
