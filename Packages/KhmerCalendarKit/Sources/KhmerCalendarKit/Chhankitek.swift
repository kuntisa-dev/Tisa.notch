//
//  Chhankitek.swift
//  KhmerCalendarKit
//
//  The Khmer lunar calendar calculation, ported from momentkh by ThyrithSor (MIT, see
//  LICENSE). Function names from momentkh.ts are kept in the comments so the two can be
//  compared line by line. Dates here are whole days; the reference also carries a time of
//  day, which this app has no use for.
//

import Foundation

public enum KhmerCalendar {
    /// The Khmer date of a Gregorian day. Checked for 1900 to 2100.
    public static func date(_ key: DayKey) -> KhmerDate {
        let lunar = Chhankitek.lunar(key)
        let year = Chhankitek.yearInfo(key.year)

        let buddhistYear = key >= year.buddhistYearChange ? key.year + 544 : key.year + 543

        // Between New Year and the BE change the animal year is already the new one.
        var animal = DayKey.floorMod(buddhistYear + 4, 12)
        if key >= year.newYear && key < year.buddhistYearChange {
            animal = (animal + 1) % 12
        }

        let isLastDayOfMonth = Chhankitek.lunar(key.adding(days: 1)).month != lunar.month
        let day = lunar.dayNumber < 15 ? lunar.dayNumber + 1 : lunar.dayNumber - 14
        let phase: MoonPhase = lunar.dayNumber < 15 ? .keit : .roach

        return KhmerDate(
            lunarDay: day,
            phase: phase,
            month: KhmerMonth(rawValue: lunar.month) ?? .migasir,
            buddhistYear: buddhistYear,
            animalYear: AnimalYear(rawValue: animal) ?? .chhut,
            isHolyDay: day == 8 || (phase == .keit && day == 15) || isLastDayOfMonth
        )
    }

    /// The first day of Khmer New Year (មហាសង្ក្រាន្ត) in a Gregorian year.
    public static func newYearDay(gregorianYear: Int) -> DayKey {
        Chhankitek.yearInfo(gregorianYear).newYear
    }
}

enum Chhankitek {
    private static let pisakh = KhmerMonth.pisakh.rawValue
    private static let jesth = KhmerMonth.jesth.rawValue
    private static let kadeuk = KhmerMonth.kadeuk.rawValue
    private static let pathamasadh = KhmerMonth.pathamasadh.rawValue
    private static let tutiyasadh = KhmerMonth.tutiyasadh.rawValue

    private static func div(_ a: Int, _ b: Int) -> Int { DayKey.floorDiv(a, b) }

    // MARK: Leap rules (BE year based)

    /// getAharkun
    private static func aharkun(_ be: Int) -> Int { div(be * 292207 + 499, 800) + 4 }
    /// getKromthupul
    private static func kromthupul(_ be: Int) -> Int { 800 - (be * 292207 + 499) % 800 }
    /// getAvoman
    private static func avoman(_ be: Int) -> Int { (aharkun(be) * 11 + 25) % 692 }
    /// getBodithey
    private static func bodithey(_ be: Int) -> Int {
        let a = aharkun(be)
        return (div(a * 11 + 25, 692) + a + 29) % 30
    }

    /// isKhmerLeapDayByCalculation
    private static func isLeapDayByCalculation(_ be: Int) -> Bool {
        let a = avoman(be)
        let isSolarLeap = kromthupul(be) <= 207
        if a == 0 && avoman(be - 1) == 137 { return true }
        if isSolarLeap { return a < 127 }
        if a == 137 && avoman(be + 1) == 0 { return false }
        return a < 138
    }

    /// isKhmerLeapMonth
    private static func isLeapMonth(_ be: Int) -> Bool {
        let b = bodithey(be)
        let next = bodithey(be + 1)
        if b == 25 && next == 5 { return false }
        return (b == 24 && next == 6) || b >= 25 || b < 6
    }

    /// getLeapType: 1 = leap month (អធិកមាស), 2 = leap day (ចន្ទ្រាធិមាស), 0 = regular.
    private static func leapType(_ be: Int) -> Int {
        if isLeapMonth(be) { return 1 }
        if isLeapDayByCalculation(be) { return 2 }
        if isLeapMonth(be - 1) {
            var previous = be - 1
            while true {
                if isLeapDayByCalculation(previous) { return 2 }
                previous -= 1
                if !isLeapMonth(previous) { return 0 }
            }
        }
        return 0
    }

    /// getNumberOfDaysInKhmerMonth
    private static func daysInMonth(_ month: Int, _ be: Int) -> Int {
        let leap = leapType(be)
        if month == jesth && leap == 2 { return 30 }
        if month == pathamasadh || month == tutiyasadh { return leap == 1 ? 30 : 0 }
        return month % 2 == 0 ? 29 : 30
    }

    /// getNumberOfDaysInKhmerYear
    private static func daysInYear(_ be: Int) -> Int {
        switch leapType(be) {
        case 1: return 384
        case 2: return 355
        default: return 354
        }
    }

    /// nextMonthOf
    private static func nextMonth(_ month: Int, _ be: Int) -> Int {
        if month == jesth && leapType(be) == 1 { return pathamasadh }
        if month == kadeuk { return KhmerMonth.migasir.rawValue }
        if month == pathamasadh { return tutiyasadh }
        if month == tutiyasadh { return KhmerMonth.srap.rawValue }
        return month + 1
    }

    /// getMaybeBEYear
    private static func maybeBE(_ year: Int, _ month: Int) -> Int {
        month <= 4 ? year + 543 : year + 544
    }

    // MARK: Gregorian day -> lunar month and day

    /// gregorianToKhmerInternal, the part that finds the month and the day number (0...29).
    /// The walk starts from 1 January 1900, which was ១ កើត ខែបុស្ស.
    static func lunar(_ key: DayKey) -> (month: Int, dayNumber: Int) {
        var epoch = DayKey(year: 1900, month: 1, day: 1).julianDay
        var month = KhmerMonth.boss.rawValue
        var diff = key.julianDay - epoch

        if diff > 0 {
            while true {
                let at = DayKey(julianDay: epoch)
                let days = daysInYear(maybeBE(at.year + 1, at.month))
                guard diff > days else { break }
                diff -= days
                epoch += days
            }
        } else if diff < 0 {
            while diff < 0 {
                let at = DayKey(julianDay: epoch)
                let days = daysInYear(maybeBE(at.year, at.month))
                diff += days
                epoch -= days
            }
        }

        while diff > 0 {
            let at = DayKey(julianDay: epoch)
            let be = maybeBE(at.year, at.month)
            let days = daysInMonth(month, be)
            guard diff > days else { break }
            diff -= days
            epoch += days
            month = nextMonth(month, be)
        }

        // A month of 29 days cannot hold day number 29: that is the first of the next month.
        let be = maybeBE(key.year, key.month)
        let total = daysInMonth(month, be)
        if total > 0, diff >= total {
            diff %= total
            month = nextMonth(month, be)
        }
        return (month, diff)
    }

    // MARK: Per-year facts

    struct YearInfo: Sendable {
        /// ១ រោច ខែពិសាខ: the Buddhist Era year goes up on this day.
        let buddhistYearChange: DayKey
        /// First day of Khmer New Year.
        let newYear: DayKey
        /// 3 or 4: the days from មហាសង្ក្រាន្ត to ថ្ងៃឡើងស័ក.
        let newYearLength: Int
    }

    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var years: [Int: YearInfo] = [:]

        func info(_ year: Int, make: () -> YearInfo) -> YearInfo {
            lock.lock()
            defer { lock.unlock() }
            if let known = years[year] { return known }
            let made = make()
            years[year] = made
            return made
        }
    }

    private static let cache = Cache()

    static func yearInfo(_ year: Int) -> YearInfo {
        cache.info(year) {
            let newYear = newYear(year)
            return YearInfo(buddhistYearChange: buddhistYearChange(year), newYear: newYear.day, newYearLength: newYear.length)
        }
    }

    /// getPisakhaBochea
    private static func buddhistYearChange(_ year: Int) -> DayKey {
        var day = DayKey(year: year, month: 4, day: 1)
        while day.month <= 6 {
            let found = lunar(day)
            if found.month == pisakh && found.dayNumber == 15 { return day }
            day = day.adding(days: 1)
        }
        return DayKey(year: year, month: 4, day: 15)
    }

    // MARK: Khmer New Year (Chula Sakaraj year based)

    /// khNewYearMoments: years where the published date differs from the calculation.
    private static let publishedNewYears: [Int: DayKey] = [
        1879: DayKey(year: 1879, month: 4, day: 12),
        1897: DayKey(year: 1897, month: 4, day: 13),
        2011: DayKey(year: 2011, month: 4, day: 14),
        2012: DayKey(year: 2012, month: 4, day: 14),
        2013: DayKey(year: 2013, month: 4, day: 14),
        2014: DayKey(year: 2014, month: 4, day: 14),
        2015: DayKey(year: 2015, month: 4, day: 14),
        2024: DayKey(year: 2024, month: 4, day: 13)
    ]

    /// getAharkunJs
    private static func aharkunJs(_ js: Int) -> Int { div(js * 292207 + 373, 800) + 1 }
    /// getAvomanJs
    private static func avomanJs(_ js: Int) -> Int { (aharkunJs(js) * 11 + 650) % 692 }
    /// getKromthupulJs
    private static func kromthupulJs(_ js: Int) -> Int { 800 - (292207 * js + 373) % 800 }
    /// getBoditheyJs
    private static func boditheyJs(_ js: Int) -> Int {
        let a = aharkunJs(js)
        return (a + div(11 * a + 650, 692)) % 30
    }

    /// isAdhikameas
    private static func isAdhikameas(_ js: Int) -> Bool {
        let b = boditheyJs(js)
        let next = boditheyJs(js + 1)
        if b == 24 && next == 6 { return true }
        if b == 25 && next == 5 { return false }
        return b > 24 || b < 6
    }

    /// isChantrathimeas
    private static func isChantrathimeas(_ js: Int) -> Bool {
        let a = avomanJs(js)
        let next = avomanJs(js + 1)
        let previous = avomanJs(js - 1)
        let isSolarLeap = kromthupulJs(js) <= 207
        if a == 0 && previous == 137 { return true }
        if isSolarLeap { return a < 127 }
        if a == 137 && next == 0 { return false }
        return a < 138
    }

    /// getSunInfo, reduced to the angsar (degrees) of the sun on day `sotin` of the year.
    private static func sunAngsar(js: Int, sotin: Int) -> Int {
        let r2 = 800 * sotin + kromthupulJs(js - 1)
        let reasey = div(r2, 24350)
        let r3 = r2 % 24350
        let angsar = div(r3, 811)
        let libda = div(r3 % 811, 14) - 3
        let average = 1800 * reasey + 60 * angsar + libda

        let s1 = 1800 * 2 + 60 * 20
        var leftOver = average - s1
        if average < s1 { leftOver += 1800 * 12 }
        let kaen = div(leftOver, 1800)

        var rs = -1
        switch kaen {
        case 0...2: rs = kaen
        case 3...5: rs = 1800 * 6 - leftOver
        case 6...8: rs = leftOver - 1800 * 6
        case 9...11: rs = (1800 * 11 + 60 * 29 + 60) - leftOver
        default: break
        }

        let lastReasey = div(rs, 1800)
        let lastAngsar = div(rs % 1800, 60)
        let lastLibda = rs % 60

        let khan: Int
        let pouichalip: Int
        if lastAngsar >= 15 {
            khan = 2 * lastReasey + 1
            pouichalip = 60 * (lastAngsar - 15) + lastLibda
        } else {
            khan = 2 * lastReasey
            pouichalip = 60 * lastAngsar + lastLibda
        }

        let chhayaSun: [(multiplicity: Int, chhaya: Int)] = [(35, 0), (32, 35), (27, 67), (22, 94), (13, 116), (5, 129)]
        let chosen = (0...5).contains(khan) ? chhayaSun[khan] : (multiplicity: 0, chhaya: 134)
        let phol = div(pouichalip * chosen.multiplicity, 900) + chosen.chhaya

        let inauguration = kaen <= 5 ? average - phol : average + phol
        return div(inauguration % 1800, 60)
    }

    /// getNewYearFullInfo, reduced to the day of Moha Songkran.
    private static func newYear(_ year: Int) -> (day: DayKey, length: Int) {
        let js = year - 638
        let firstSotin = kromthupulJs(js - 1) <= 207 ? 363 : 362
        let newYearDays = sunAngsar(js: js, sotin: firstSotin) == 0 ? 4 : 3
        if let published = publishedNewYears[year] { return (published, newYearDays) }

        var b = boditheyJs(js)
        if isAdhikameas(js - 1) && isChantrathimeas(js - 1) {
            b = (b + 1) % 30
        }
        // Lunar date of ថ្ងៃឡើងស័ក, the last day of New Year.
        let lerngSakDay = b >= 6 ? b - 1 : b
        let lerngSakMonth = b >= 6 ? 4 : 5

        let epoch = DayKey(year: year, month: 4, day: 17)
        let at = lunar(epoch)
        let difference = ((at.month - 4) * 29 + at.dayNumber) - ((lerngSakMonth - 4) * 29 + lerngSakDay)
        return (epoch.adding(days: -(difference + newYearDays - 1)), newYearDays)
    }
}
