//
//  KhmerFormat.swift
//  KhmerCalendarKit
//
//  Khmer numerals and names for the calendar.
//

import Foundation

/// Which letters the calendar is written in. Latin writes dates, weekdays, months and numbers
/// in English, but keeps the Khmer calendar's own words (កើត, រោច, the lunar month, ថ្ងៃសីល).
public enum CalendarScript: Sendable {
    case khmer, latin
}

public enum KhmerFormat {
    private static let digits: [Character] = ["០", "១", "២", "៣", "៤", "៥", "៦", "៧", "៨", "៩"]

    private static let solarMonths = [
        "មករា", "កុម្ភៈ", "មីនា", "មេសា", "ឧសភា", "មិថុនា",
        "កក្កដា", "សីហា", "កញ្ញា", "តុលា", "វិច្ឆិកា", "ធ្នូ"
    ]

    /// Monday first.
    private static let weekdays = ["ចន្ទ", "អង្គារ", "ពុធ", "ព្រហស្បតិ៍", "សុក្រ", "សៅរ៍", "អាទិត្យ"]
    private static let shortWeekdays = ["ច", "អ", "ពុ", "ព្រ", "សុ", "ស", "អា"]

    private static let latinSolarMonths = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    private static let latinWeekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private static let latinShortWeekdays = ["M", "T", "W", "T", "F", "S", "S"]

    /// 2570 -> "២៥៧០", or "2570" in Latin.
    public static func numerals(_ value: Int, script: CalendarScript = .khmer) -> String {
        guard script == .khmer else { return String(value) }
        return String(String(value).map { $0.wholeNumberValue.map { digits[$0] } ?? $0 })
    }

    /// 1 = មករា (January) ... 12 = ធ្នូ (December).
    public static func solarMonthName(_ month: Int, script: CalendarScript = .khmer) -> String {
        let names = script == .khmer ? solarMonths : latinSolarMonths
        return names.indices.contains(month - 1) ? names[month - 1] : ""
    }

    /// 1 = Monday ... 7 = Sunday.
    public static func weekdayName(_ weekday: Int, short: Bool, script: CalendarScript = .khmer) -> String {
        let names: [String]
        switch script {
        case .khmer: names = short ? shortWeekdays : weekdays
        case .latin: names = short ? latinShortWeekdays : latinWeekdays
        }
        return names.indices.contains(weekday - 1) ? names[weekday - 1] : ""
    }

    /// "ថ្ងៃព្រហស្បតិ៍ ទី១២ ខែវិច្ឆិកា ២០២៦", or "Thursday 12 November 2026".
    public static func dateLine(_ day: DayKey, script: CalendarScript) -> String {
        let weekday = weekdayName(day.weekday, short: false, script: script)
        switch script {
        case .khmer:
            return "ថ្ងៃ\(weekday) ទី\(numerals(day.day)) ខែ\(solarMonthName(day.month)) \(numerals(day.year))"
        case .latin:
            return "\(weekday) \(day.day) \(solarMonthName(day.month, script: .latin)) \(day.year)"
        }
    }

    /// "វិច្ឆិកា ២០២៦ · ព.ស. ២៥៧០", or "November 2026 · BE 2570".
    public static func monthTitle(year: Int, month: Int, buddhistYear: Int, script: CalendarScript) -> String {
        let era = script == .khmer ? "ព.ស." : "BE"
        return "\(solarMonthName(month, script: script)) \(numerals(year, script: script)) · \(era) \(numerals(buddhistYear, script: script))"
    }
}
