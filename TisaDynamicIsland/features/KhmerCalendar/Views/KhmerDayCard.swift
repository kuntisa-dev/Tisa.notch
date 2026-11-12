//
//  KhmerDayCard.swift
//  TisaDynamicIsland
//
//  The picked day: its Khmer and lunar date, any holiday, the day's Apple Calendar events
//  (read only) and the notes written on it.
//

import Defaults
import KhmerCalendarKit
import SwiftUI

struct KhmerDayCard: View {
    @ObservedObject var model: KhmerCalendarModel
    @ObservedObject private var store = DayNoteStore.shared
    @ObservedObject private var routineStore = RoutineStore.shared
    @Default(.khmerShowHolidays) private var showHolidays
    @Default(.khmerShowHolyDays) private var showHolyDays
    @Default(.khmerShowEvents) private var showEvents
    @Default(.khmerCalendarLatin) private var latin

    private var script: CalendarScript { latin ? .latin : .khmer }

    private enum Editing: Equatable {
        case new
        case note(DayNote)
    }

    @State private var editing: Editing?

    var body: some View {
        Group {
            if let editing {
                DayNoteEditor(day: model.selected, editing: existingNote(editing)) { self.editing = nil }
                    .id(existingNote(editing)?.id)
            } else {
                dayView
            }
        }
        // Picking another day while writing leaves the editor.
        .onChange(of: model.selected) { _, _ in editing = nil }
    }

    private func existingNote(_ editing: Editing) -> DayNote? {
        if case .note(let note) = editing { return note }
        return nil
    }

    private var dayView: some View {
        let cell = model.selectedCell
        let notes = store.book.notes(on: model.selected)
        let events = showEvents ? model.events : []
        let routines = routineStore.book.routines(on: model.selected)
        return VStack(alignment: .leading, spacing: 4) {
            Text(KhmerFormat.dateLine(cell.key, script: script))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .ink(Color.white, Ink.title)
            Text(KhmerFormat.lunarLine(cell.khmer, script: script) + (showHolyDays && cell.khmer.isHolyDay ? " · ថ្ងៃសីល" : ""))
                .font(.system(size: 10))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .ink(HomeStyle.secondary, Ink.reset)
            ForEach(showHolidays ? cell.holidays : [], id: \.englishName) { holiday in
                Text(latin ? holiday.englishName : holiday.khmerName)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .ink(KhmerCalendarStyle.red, KhmerCalendarStyle.red)
                    .help(holiday.isDayOff ? holiday.englishName : "\(holiday.englishName) (not a day off)")
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    sectionHeader(routineTitle(routines), button: "Routine") {
                        model.routineEditor = .new
                    }
                    if routines.isEmpty {
                        Text("No routines on this day")
                            .font(.system(size: 10))
                            .inkColor(HomeStyle.secondary, Ink.detail)
                    }
                    ForEach(routines) { routine in
                        RoutineRow(routine: routine, day: model.selected, today: model.today) {
                            model.routineEditor = .edit(routine)
                        }
                    }

                    sectionHeader("NOTES", button: "Note") { editing = .new }
                        .padding(.top, 2)
                    ForEach(events, id: \.id) { event in
                        eventRow(event)
                    }
                    ForEach(notes) { note in
                        DayNoteRow(note: note) {
                            editing = .note(note)
                        } onDelete: {
                            store.delete(id: note.id)
                        }
                    }
                    if store.saveFailed {
                        Text("Couldn't save notes")
                            .font(.system(size: 9.5))
                            .ink(HomeStyle.alert, HomeStyle.alert)
                            .help("The notes file could not be written. New notes are kept only until the app quits.")
                    }
                    if routineStore.saveFailed {
                        Text("Couldn't save routines")
                            .font(.system(size: 9.5))
                            .ink(HomeStyle.alert, HomeStyle.alert)
                            .help("The routines file could not be written. Changes are kept only until the app quits.")
                    }
                }
            }
            .inkPlate()
        }
    }

    /// "ROUTINES · 1 OF 2 DONE".
    private func routineTitle(_ routines: [Routine]) -> String {
        guard !routines.isEmpty else { return "ROUTINES" }
        let done = routines.filter { routineStore.book.isDone($0.id, on: model.selected) }.count
        return "ROUTINES · \(done) OF \(routines.count) DONE"
    }

    private func sectionHeader(_ title: String, button: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .inkColor(HomeStyle.secondary, Ink.detail)
            Spacer(minLength: 4)
            Button(action: action) {
                Label(button, systemImage: "plus")
            }
            .buttonStyle(KhmerHeaderButtonStyle())
        }
    }

    private func eventRow(_ event: EventModel) -> some View {
        Button {
            if let url = event.calendarAppURL() { NSWorkspace.shared.open(url) }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(Color(nsColor: event.calendar.color)).frame(width: 6, height: 6)
                Text(event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened))
                    .inkColor(HomeStyle.secondary, Ink.reset)
                    .monospacedDigit()
                    .frame(width: 46, alignment: .leading)
                Text(event.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .font(.system(size: 11))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open in Calendar")
    }
}

private struct DayNoteRow: View {
    let note: DayNote
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onEdit) {
                HStack(spacing: 6) {
                    Image(systemName: note.alert ? "bell.fill" : "note.text")
                        .font(.system(size: 8.5))
                        .foregroundStyle(Color.effectiveAccent.mix(with: .white, by: 0.3))
                        .frame(width: 8)
                    Text(DayNoteTime.text(note) ?? "–")
                        .inkColor(HomeStyle.secondary, Ink.reset)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .leading)
                    Text(note.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 11))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Edit note")

            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 9.5))
                        .foregroundStyle(HomeStyle.alert)
                }
                .buttonStyle(.plain)
                .help("Delete note")
                .accessibilityLabel("Delete note")
            }
        }
        .padding(.horizontal, 5)
        .frame(height: 20)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Ink.rowFill))
        .onHover { isHovering = $0 }
    }
}

enum DayNoteTime {
    /// A note's time the way this Mac writes times ("9:30 AM" or "09:30"). Nil without a time.
    static func text(_ note: DayNote) -> String? {
        guard let time = note.time,
              let date = Calendar.current.date(from: DateComponents(hour: time.hour, minute: time.minute))
        else { return nil }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
