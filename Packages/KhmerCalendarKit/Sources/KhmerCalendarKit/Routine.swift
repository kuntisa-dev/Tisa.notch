//
//  Routine.swift
//  KhmerCalendarKit
//
//  A routine the user wants to keep, such as "Run at 05:30 every day", and the record of
//  the days it was done. From that record come the day marks and the streak.
//

import Foundation

public struct Routine: Identifiable, Codable, Equatable, Sendable {
    public static let maxTitleLength = 100
    public static let getReadyChoices = [0, 5, 10, 15, 30, 60]

    public let id: UUID
    public var title: String
    public var hour: Int
    public var minute: Int
    /// 1 = Monday ... 7 = Sunday. Never empty.
    public var weekdays: Set<Int>
    /// Minutes before the time for the get-ready reminder; 0 is off.
    public var getReadyMinutes: Int
    /// "2026-11-12": the day the routine was made. Days before it never count as missed.
    public var startDay: String
    public var createdAt: Date

    /// Nil when the title is empty or a value is out of range. The title is trimmed and cut
    /// to 100 characters.
    public static func make(id: UUID = UUID(), title: String, hour: Int, minute: Int, weekdays: Set<Int>,
                            getReadyMinutes: Int, startDay: DayKey, createdAt: Date = Date()) -> Routine? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              (0...23).contains(hour), (0...59).contains(minute),
              !weekdays.isEmpty, weekdays.allSatisfy({ (1...7).contains($0) }),
              getReadyChoices.contains(getReadyMinutes)
        else { return nil }
        return Routine(id: id, title: String(trimmed.prefix(maxTitleLength)), hour: hour, minute: minute,
                       weekdays: weekdays, getReadyMinutes: getReadyMinutes, startDay: startDay.string,
                       createdAt: createdAt)
    }

    public func isScheduled(on day: DayKey) -> Bool {
        guard weekdays.contains(day.weekday), let start = DayKey(startDay) else { return false }
        return day >= start
    }
}

public enum RoutineStatus: Equatable, Sendable {
    case done, missed, upcoming, none
}

/// The mark a past day (or today) gets in the month grid.
public enum DayMark: Equatable, Sendable {
    case allDone, someMissed
}

public struct RoutineBook: Equatable, Sendable {
    public private(set) var routines: [Routine]
    /// The days ("2026-11-12") each routine was ticked done.
    public private(set) var done: [UUID: Set<String>]

    public init(routines: [Routine] = [], done: [UUID: Set<String>] = [:]) {
        self.routines = routines
        self.done = done
    }

    /// Adds a routine, or replaces it by id. Its done days are kept.
    public mutating func upsert(_ routine: Routine) {
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
        } else {
            routines.append(routine)
        }
    }

    /// Removes a routine and its history.
    public mutating func remove(id: UUID) {
        routines.removeAll { $0.id == id }
        done[id] = nil
    }

    public func isDone(_ id: UUID, on day: DayKey) -> Bool {
        done[id]?.contains(day.string) ?? false
    }

    /// The routines scheduled on a day, by time and then in the order they were made.
    public func routines(on day: DayKey) -> [Routine] {
        routines.filter { $0.isScheduled(on: day) }.sorted {
            ($0.hour, $0.minute, $0.createdAt) < ($1.hour, $1.minute, $1.createdAt)
        }
    }

    public func status(of routine: Routine, on day: DayKey, today: DayKey) -> RoutineStatus {
        if isDone(routine.id, on: day) { return .done }
        guard routine.isScheduled(on: day) else { return .none }
        if day < today { return .missed }
        return day == today ? .upcoming : .none
    }

    /// Nil when nothing was scheduled or done that day, for future days, and for today
    /// while something is still to do.
    public func mark(on day: DayKey, today: DayKey) -> DayMark? {
        guard day <= today else { return nil }
        let statuses = routines.map { status(of: $0, on: day, today: today) }.filter { $0 != .none }
        if statuses.contains(.missed) { return .someMissed }
        if !statuses.isEmpty, statuses.allSatisfy({ $0 == .done }) { return .allDone }
        return nil
    }

    /// Only today and yesterday can be ticked or unticked by hand.
    public static func canTick(_ day: DayKey, today: DayKey) -> Bool {
        day == today || day == today.adding(days: -1)
    }

    /// Ticks or unticks a day. False, with nothing changed, for an unknown routine or a day
    /// outside today and yesterday.
    @discardableResult
    public mutating func toggleDone(_ id: UUID, on day: DayKey, today: DayKey) -> Bool {
        guard Self.canTick(day, today: today), routines.contains(where: { $0.id == id }) else { return false }
        if isDone(id, on: day) {
            done[id]?.remove(day.string)
            if done[id]?.isEmpty == true { done[id] = nil }
        } else {
            done[id, default: []].insert(day.string)
        }
        return true
    }

    /// Marks a day done, whatever the day. Used by reminders.
    public mutating func setDone(_ id: UUID, on day: DayKey) {
        done[id, default: []].insert(day.string)
    }

    /// Done days in a row, counting back from today. Unscheduled days are skipped, today is
    /// skipped while still to do, and the first missed day ends the count.
    public func streak(of routine: Routine, today: DayKey) -> Int {
        guard let start = DayKey(routine.startDay) else { return 0 }
        var count = 0
        var day = today
        while day >= start {
            switch status(of: routine, on: day, today: today) {
            case .done: count += 1
            case .missed: return count
            case .upcoming, .none: break
            }
            day = day.adding(days: -1)
        }
        return count
    }
}

/// How a routine's days read in a row: "Every day", "Mon–Fri", "Weekend" or "Mon, Wed, Fri".
public enum RoutineRepeatText {
    private static let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    public static func text(_ weekdays: Set<Int>) -> String {
        switch weekdays {
        case Set(1...7): return "Every day"
        case Set(1...5): return "Mon–Fri"
        case [6, 7]: return "Weekend"
        default: return weekdays.sorted().filter { (1...7).contains($0) }.map { names[$0 - 1] }.joined(separator: ", ")
        }
    }
}
