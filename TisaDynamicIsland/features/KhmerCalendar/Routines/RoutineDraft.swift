//
//  RoutineDraft.swift
//  TisaDynamicIsland
//
//  What the two routine editors (in the notch and in Settings) share: their starting values,
//  the get-ready line and saving.
//

import Defaults
import Foundation
import KhmerCalendarKit

@MainActor
enum RoutineDraft {
    static let presets: [(name: String, days: Set<Int>)] = [
        ("Every day", Set(1...7)), ("Weekdays", Set(1...5)), ("Weekend", [6, 7])
    ]

    /// The routine's time, or the next whole hour for a new one.
    static func initialTime(for routine: Routine?) -> Date {
        let calendar = Calendar.current
        if let routine, let set = calendar.date(from: DateComponents(hour: routine.hour, minute: routine.minute)) {
            return set
        }
        let next = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return calendar.date(bySetting: .minute, value: 0, of: next) ?? next
    }

    /// The routine's get-ready minutes, or the Settings default for a new one.
    static func initialGetReady(for routine: Routine?) -> Int {
        let lead = routine?.getReadyMinutes ?? Defaults[.routineGetReadyDefault]
        return Routine.getReadyChoices.contains(lead) ? lead : 30
    }

    static func hourMinute(_ time: Date) -> (hour: Int, minute: Int) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        return (parts.hour ?? 0, parts.minute ?? 0)
    }

    /// "Get-ready reminder at 5:00 AM", or "No get-ready reminder".
    static func getReadyNote(time: Date, getReady: Int) -> String {
        guard getReady > 0 else { return "No get-ready reminder" }
        let (hour, minute) = hourMinute(time)
        let minutes = ((hour * 60 + minute - getReady) % 1440 + 1440) % 1440
        guard let date = Calendar.current.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60)) else { return "" }
        return "Get-ready reminder at \(date.formatted(date: .omitted, time: .shortened))"
    }

    static func canSave(title: String, weekdays: Set<Int>) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !weekdays.isEmpty
    }

    /// Saves a new routine or the changes to `existing`. False when the values are not valid.
    @discardableResult
    static func save(existing: Routine?, title: String, time: Date, weekdays: Set<Int>, getReady: Int) -> Bool {
        let today = DayKey(Date(), calendar: .current)
        let start = existing.flatMap { DayKey($0.startDay) } ?? today
        let (hour, minute) = hourMinute(time)
        guard let routine = Routine.make(
            id: existing?.id ?? UUID(), title: title, hour: hour, minute: minute, weekdays: weekdays,
            getReadyMinutes: getReady, startDay: start, createdAt: existing?.createdAt ?? Date()
        ) else { return false }
        RoutineStore.shared.save(routine)
        if Defaults[.routineBackupNotification] {
            Task { await RoutineBackups.requestPermissionIfNeeded() }
        }
        return true
    }
}
