//
//  KhmerMonthCard.swift
//  TisaDynamicIsland
//
//  One month, Monday first and Sunday last. Each day shows its Khmer number with the
//  lunar day beside it.
//

import Defaults
import KhmerCalendarKit
import SwiftUI

struct KhmerMonthCard: View {
    @ObservedObject var model: KhmerCalendarModel
    @ObservedObject private var notes = DayNoteStore.shared
    @ObservedObject private var routines = RoutineStore.shared
    @Default(.khmerShowLunarDay) private var showLunarDay
    @Default(.khmerShowHolidays) private var showHolidays
    @Default(.khmerShowHolyDays) private var showHolyDays
    @Default(.khmerCalendarLatin) private var latin

    private var script: CalendarScript { latin ? .latin : .khmer }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 3) {
            header
            weekdays
            GeometryReader { proxy in
                let rowHeight = max(12, (proxy.size.height - 5 * 2) / 6)
                let showLunar = showLunarDay && proxy.size.width / 7 >= 44
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(model.cells) { cell in
                        KhmerDayCell(
                            cell: cell,
                            isToday: cell.key == model.today,
                            isSelected: cell.key == model.selected,
                            hasNotes: notes.book.daysWithNotes.contains(cell.key.string),
                            mark: routines.book.mark(on: cell.key, today: model.today),
                            showLunar: showLunar,
                            showHolidays: showHolidays,
                            showHolyDays: showHolyDays,
                            script: script
                        )
                        .frame(height: rowHeight)
                        .onTapGesture { model.select(cell.key) }
                    }
                }
            }
            .inkPlate()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(model.monthTitle(script))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .ink(Color.white, Ink.title)
            Spacer(minLength: 4)
            if !routines.book.routines.isEmpty {
                // Shown only when it fits beside the title and buttons.
                ViewThatFits(in: .horizontal) {
                    legend
                    Color.clear.frame(width: 0, height: 0)
                }
            }
            if !model.isShowingToday {
                Button("Today") { model.goToToday() }
                    .buttonStyle(KhmerHeaderButtonStyle())
            }
            Button { model.showPrevious() } label: { Image(systemName: "chevron.left") }
                .buttonStyle(KhmerHeaderButtonStyle())
                .accessibilityLabel("Previous month")
            Button { model.showNext() } label: { Image(systemName: "chevron.right") }
                .buttonStyle(KhmerHeaderButtonStyle())
                .accessibilityLabel("Next month")
        }
        .frame(height: 18)
    }

    private var legend: some View {
        HStack(spacing: 7) {
            HStack(spacing: 3) {
                Circle().fill(KhmerCalendarStyle.done).frame(width: 5, height: 5)
                Text("All done")
            }
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 1).fill(KhmerCalendarStyle.missed).frame(width: 5, height: 5)
                Text("Missed")
            }
        }
        .font(.system(size: 8.5, weight: .medium))
        .inkColor(HomeStyle.secondary, Ink.detail)
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    private var weekdays: some View {
        HStack(spacing: 2) {
            ForEach(1...7, id: \.self) { weekday in
                Text(KhmerFormat.weekdayName(weekday, short: true, script: script))
                    .font(.system(size: 8.5, weight: .semibold))
                    .inkColor(weekday == 7 ? KhmerCalendarStyle.red : HomeStyle.secondary,
                              weekday == 7 ? KhmerCalendarStyle.red : Ink.detail)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(KhmerFormat.weekdayName(weekday, short: false))
            }
        }
        .frame(height: 11)
    }
}

struct KhmerHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(Color(white: 0.9))
            .padding(.horizontal, 6)
            .frame(minWidth: 18, minHeight: 18)
            .background(Capsule().fill(Ink.rowFill))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Capsule())
    }
}

private struct KhmerDayCell: View {
    let cell: KhmerCalendarModel.Cell
    let isToday: Bool
    let isSelected: Bool
    let hasNotes: Bool
    let mark: DayMark?
    let showLunar: Bool
    let showHolidays: Bool
    let showHolyDays: Bool
    let script: CalendarScript

    private var isRed: Bool { cell.grid.isSunday || (showHolidays && !cell.holidays.isEmpty) }
    private var isHoly: Bool { showHolyDays && cell.khmer.isHolyDay }
    private var isHoliday: Bool { showHolidays && !cell.holidays.isEmpty && cell.grid.inMonth }

    private var fill: Color {
        if isSelected { return Color.effectiveAccent.opacity(0.32) }
        if isToday { return Color.effectiveAccent.opacity(0.16) }
        if isHoliday { return KhmerCalendarStyle.red.opacity(0.08) }
        return .clear
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        HStack(spacing: 3) {
            Text(KhmerFormat.numerals(cell.key.day, script: script))
                .font(.system(size: 11.5, weight: isToday || isSelected ? .bold : .semibold))
                .foregroundStyle(isRed ? KhmerCalendarStyle.red : Color.white)
            if showLunar {
                HStack(spacing: 1.5) {
                    if isHoly {
                        Image(systemName: "moon.fill").font(.system(size: 5.5))
                    }
                    Text(KhmerFormat.lunarDay(cell.khmer, script: script))
                        .font(.system(size: 8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(isHoly ? KhmerCalendarStyle.holy : HomeStyle.secondary)
            } else if isHoly {
                Image(systemName: "moon.fill")
                    .font(.system(size: 5.5))
                    .foregroundStyle(KhmerCalendarStyle.holy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(cell.grid.inMonth ? 1 : 0.35)
        .background(shape.fill(fill))
        .overlay(shape.strokeBorder(isToday ? Color.effectiveAccent : Color.clear, lineWidth: 1.5))
        // Routines: a blue dot when all were done, an orange square when one was missed.
        .overlay(alignment: .bottomTrailing) {
            switch mark {
            case .allDone:
                Circle().fill(KhmerCalendarStyle.done).frame(width: 5, height: 5).padding(2.5)
            case .someMissed:
                RoundedRectangle(cornerRadius: 1).fill(KhmerCalendarStyle.missed).frame(width: 5, height: 5).padding(2.5)
            case nil:
                EmptyView()
            }
        }
        // A short bar under the day: this day has notes.
        .overlay(alignment: .bottom) {
            if hasNotes {
                Capsule()
                    .fill(Color.effectiveAccent.mix(with: .white, by: 0.3))
                    .frame(width: 12, height: 2)
                    .padding(.bottom, 0.5)
            }
        }
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityText: String {
        var parts = [
            "\(KhmerFormat.weekdayName(cell.key.weekday, short: false)) \(KhmerFormat.numerals(cell.key.day)) \(KhmerFormat.solarMonthName(cell.key.month))",
            KhmerFormat.lunarLine(cell.khmer)
        ]
        parts += cell.holidays.map(\.khmerName)
        if cell.khmer.isHolyDay { parts.append("ថ្ងៃសីល") }
        if hasNotes { parts.append("has notes") }
        switch mark {
        case .allDone: parts.append("all routines done")
        case .someMissed: parts.append("a routine missed")
        case nil: break
        }
        if isToday { parts.append("today") }
        return parts.joined(separator: ", ")
    }
}
