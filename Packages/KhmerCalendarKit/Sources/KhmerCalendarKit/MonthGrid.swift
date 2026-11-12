//
//  MonthGrid.swift
//  KhmerCalendarKit
//
//  The 42 days a month view shows: six weeks, Monday first, Sunday last.
//

import Foundation

public struct GridDay: Identifiable, Sendable {
    public let key: DayKey
    /// False for the days borrowed from the month before or after.
    public let inMonth: Bool
    public let isSunday: Bool

    public var id: DayKey { key }

    public init(key: DayKey, inMonth: Bool, isSunday: Bool) {
        self.key = key
        self.inMonth = inMonth
        self.isSunday = isSunday
    }
}

public enum MonthGrid {
    public static func days(year: Int, month: Int) -> [GridDay] {
        let first = DayKey(year: year, month: month, day: 1)
        let start = first.adding(days: -(first.weekday - 1))
        return (0..<42).map { offset in
            let key = start.adding(days: offset)
            return GridDay(key: key, inMonth: key.year == year && key.month == month, isSunday: key.weekday == 7)
        }
    }
}
