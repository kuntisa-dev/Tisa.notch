//
//  DayNoteAlertPlan.swift
//  KhmerCalendarKit
//
//  Works out which macOS notifications the notes need: which to schedule and which
//  pending ones to take away. The app applies the answer; nothing here touches the system.
//

import Foundation

public enum DayNoteAlertPlan {
    public static let identifierPrefix = "day-note-"

    public struct Change: Equatable {
        /// Notes whose alert should be pending. Scheduling again replaces an older copy.
        public var schedule: [DayNote]
        /// Identifiers of pending alerts that should no longer fire.
        public var remove: [String]
    }

    public static func identifier(for id: UUID) -> String {
        identifierPrefix + id.uuidString
    }

    /// When a note's alert fires. Nil for a note with no time or an unreadable day.
    public static func fireDate(for note: DayNote, calendar: Calendar) -> Date? {
        guard let time = note.time, let day = DayKey(note.day) else { return nil }
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day,
                                                  hour: time.hour, minute: time.minute))
    }

    public static func change(book: DayNoteBook, pending: Set<String>, now: Date, calendar: Calendar) -> Change {
        let schedule = book.notes.filter { note in
            guard note.alert, let fire = fireDate(for: note, calendar: calendar) else { return false }
            return fire > now
        }
        let wanted = Set(schedule.map { identifier(for: $0.id) })
        let remove = pending.filter { $0.hasPrefix(identifierPrefix) && !wanted.contains($0) }
        return Change(schedule: schedule, remove: remove.sorted())
    }
}
