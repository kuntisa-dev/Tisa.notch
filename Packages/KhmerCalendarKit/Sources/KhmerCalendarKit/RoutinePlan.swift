//
//  RoutinePlan.swift
//  KhmerCalendarKit
//
//  When routine reminders happen: the get-ready reminder before a routine, the reminder at
//  its time, which of those the notch should show now, and which backup notifications
//  macOS should hold. The app applies the answers; nothing here touches the system.
//

import Foundation

/// One reminder for one routine on one day.
public struct RoutineOccurrence: Equatable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case getReady = "ready"
        case due
    }

    public let routineID: UUID
    /// The routine's day, even when a get-ready reminder fires the evening before.
    public let day: DayKey
    public let kind: Kind
    public let fireDate: Date

    /// "routine-<uuid>-2026-11-12-due". Also the backup notification's identifier.
    public var id: String {
        "\(RoutinePlan.identifierPrefix)\(routineID.uuidString)-\(day.string)-\(kind.rawValue)"
    }
}

public enum RoutinePlan {
    /// A reminder missed while the Mac slept is still shown this long after its time.
    public static let catchUp: TimeInterval = 2 * 60 * 60
    public static let snooze: TimeInterval = 10 * 60
    /// The backup notification comes this long after the notch reminder.
    public static let backupDelay: TimeInterval = 60
    public static let lookAhead: TimeInterval = 48 * 60 * 60
    public static let identifierPrefix = "routine-"

    /// The get-ready reminder (when the routine has one) and the reminder at its time.
    public static func occurrences(of routine: Routine, on day: DayKey, calendar: Calendar) -> [RoutineOccurrence] {
        guard let due = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day,
                                                           hour: routine.hour, minute: routine.minute))
        else { return [] }
        var found: [RoutineOccurrence] = []
        if routine.getReadyMinutes > 0 {
            found.append(RoutineOccurrence(routineID: routine.id, day: day, kind: .getReady,
                                           fireDate: due.addingTimeInterval(-Double(routine.getReadyMinutes) * 60)))
        }
        found.append(RoutineOccurrence(routineID: routine.id, day: day, kind: .due, fireDate: due))
        return found
    }

    /// The reminders the notch should show now, oldest first. A get-ready reminder gives way
    /// once its routine's own time has come.
    public static func dueNow(book: RoutineBook, now: Date, calendar: Calendar,
                              handled: Set<String>, snoozedUntil: [String: Date]) -> [RoutineOccurrence] {
        let today = DayKey(now, calendar: calendar)
        var found: [(occurrence: RoutineOccurrence, createdAt: Date)] = []
        for day in [today.adding(days: -1), today, today.adding(days: 1)] {
            for routine in book.routines where routine.isScheduled(on: day) && !book.isDone(routine.id, on: day) {
                let all = occurrences(of: routine, on: day, calendar: calendar)
                let dueArrived = all.contains { $0.kind == .due && $0.fireDate <= now }
                for occurrence in all {
                    let late = now.timeIntervalSince(occurrence.fireDate)
                    guard late >= 0, late <= catchUp,
                          !handled.contains(occurrence.id),
                          !(occurrence.kind == .getReady && dueArrived)
                    else { continue }
                    if let until = snoozedUntil[occurrence.id], until > now { continue }
                    found.append((occurrence, routine.createdAt))
                }
            }
        }
        return found.sorted { ($0.occurrence.fireDate, $0.createdAt) < ($1.occurrence.fireDate, $1.createdAt) }
            .map(\.occurrence)
    }

    /// The reminders whose backup notification (fire time + `backupDelay`) falls in the next
    /// `lookAhead`, for routines not yet done that day. `excluding` holds reminders the notch
    /// already showed or that were answered, which need no backup.
    public static func backups(book: RoutineBook, now: Date, calendar: Calendar,
                               excluding: Set<String> = []) -> [RoutineOccurrence] {
        let today = DayKey(now, calendar: calendar)
        let end = now.addingTimeInterval(lookAhead)
        var found: [RoutineOccurrence] = []
        for offset in 0...2 {
            let day = today.adding(days: offset)
            for routine in book.routines(on: day) where !book.isDone(routine.id, on: day) {
                found += occurrences(of: routine, on: day, calendar: calendar).filter {
                    let fire = $0.fireDate.addingTimeInterval(backupDelay)
                    return fire > now && fire <= end && !excluding.contains($0.id)
                }
            }
        }
        return found.sorted { $0.fireDate < $1.fireDate }
    }

    /// Reads an occurrence id back into its parts. Nil for anything else.
    public static func occurrenceID(parsing id: String) -> (routineID: UUID, day: DayKey, kind: RoutineOccurrence.Kind)? {
        guard id.hasPrefix(identifierPrefix) else { return nil }
        let rest = id.dropFirst(identifierPrefix.count)
        guard rest.count > 37, let uuid = UUID(uuidString: String(rest.prefix(36))) else { return nil }
        let tail = rest.dropFirst(37)          // "2026-11-12-due"
        guard let dash = tail.lastIndex(of: "-"),
              let day = DayKey(String(tail[..<dash])),
              let kind = RoutineOccurrence.Kind(rawValue: String(tail[tail.index(after: dash)...]))
        else { return nil }
        return (uuid, day, kind)
    }
}
