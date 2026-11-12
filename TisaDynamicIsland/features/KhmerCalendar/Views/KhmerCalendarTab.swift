//
//  KhmerCalendarTab.swift
//  TisaDynamicIsland
//
//  The Calendar tab: a Khmer month on the left, the picked day with its lunar date,
//  holidays, Apple Calendar events and your notes on the right.
//

import KhmerCalendarKit
import SwiftUI

struct KhmerCalendarTab: View {
    @EnvironmentObject private var vm: TisaViewModel
    @ObservedObject private var model = KhmerCalendarModel.shared

    var body: some View {
        Group {
            if let target = model.routineEditor {
                RoutineEditor(target: target) { model.routineEditor = nil }
                    .id(target.id)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .homeCard()
            } else {
                cards
            }
        }
        .padding(.top, 2)
        // Scrolling the notes must not count as the swipe that closes the notch.
        .onHover { vm.isHoveringCalendar = $0 }
        // The model is shared now, so start each visit on today as before.
        .onAppear { model.goToToday() }
        .onDisappear {
            vm.isHoveringCalendar = false
            model.routineEditor = nil
        }
    }

    private var cards: some View {
        GeometryReader { proxy in
            HStack(alignment: .top, spacing: 8) {
                KhmerMonthCard(model: model)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(width: (proxy.size.width - 8) * 0.57)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .homeCard()
                KhmerDayCard(model: model)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .homeCard()
            }
        }
    }
}

/// Colors the calendar shares between its two cards.
enum KhmerCalendarStyle {
    /// Sundays and holidays.
    static var red: Color { Ink.tab(.calendar) }
    /// ថ្ងៃសីល.
    static let holy = Ink.reset
    /// A day where every routine was done.
    static let done = Color(red: 0.22, green: 0.74, blue: 0.97)     // #38BDF8
    /// A day where a routine was missed.
    static let missed = Color(red: 1.0, green: 0.54, blue: 0.24)    // #FF8A3D
}
