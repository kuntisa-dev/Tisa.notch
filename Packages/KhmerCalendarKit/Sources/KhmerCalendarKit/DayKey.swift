//
//  DayKey.swift
//  KhmerCalendarKit
//
//  One calendar day as plain year, month and day numbers. It has no time zone, so a note
//  saved on 11 November stays on 11 November wherever the Mac travels.
//

import Foundation

public struct DayKey: Hashable, Comparable, Sendable, Codable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Reads "2026-11-11". Nil for anything that is not a real date.
    public init?(_ string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), day >= 1, day <= DayKey.daysInMonth(year: year, month: month)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The day `date` falls on in `calendar`'s time zone.
    public init(_ date: Date, calendar: Calendar) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public var string: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// 1 = Monday ... 7 = Sunday.
    public var weekday: Int {
        Self.floorMod(julianDay, 7) + 1
    }

    public func adding(days: Int) -> DayKey {
        DayKey(julianDay: julianDay + days)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        let isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        if month == 2 { return isLeap ? 29 : 28 }
        return [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
    }

    // MARK: Julian day numbers

    var julianDay: Int {
        let a = Self.floorDiv(14 - month, 12)
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + Self.floorDiv(153 * m + 2, 5) + 365 * y
            + Self.floorDiv(y, 4) - Self.floorDiv(y, 100) + Self.floorDiv(y, 400) - 32045
    }

    init(julianDay: Int) {
        let a = julianDay + 32044
        let b = Self.floorDiv(4 * a + 3, 146097)
        let c = a - Self.floorDiv(146097 * b, 4)
        let d = Self.floorDiv(4 * c + 3, 1461)
        let e = c - Self.floorDiv(1461 * d, 4)
        let m = Self.floorDiv(5 * e + 2, 153)
        self.init(year: 100 * b + d - 4800 + Self.floorDiv(m, 10),
                  month: m + 3 - 12 * Self.floorDiv(m, 10),
                  day: e - Self.floorDiv(153 * m + 2, 5) + 1)
    }

    static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }

    static func floorMod(_ a: Int, _ b: Int) -> Int {
        a - floorDiv(a, b) * b
    }
}
