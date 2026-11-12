import XCTest
@testable import KhmerCalendarKit

final class KhmerFormatTests: XCTestCase {
    func testNumerals() {
        XCTAssertEqual(KhmerFormat.numerals(2570), "២៥៧០")
        XCTAssertEqual(KhmerFormat.numerals(0), "០")
    }

    func testNames() {
        XCTAssertEqual(KhmerFormat.solarMonthName(1), "មករា")
        XCTAssertEqual(KhmerFormat.solarMonthName(11), "វិច្ឆិកា")
        XCTAssertEqual(KhmerFormat.weekdayName(1, short: false), "ចន្ទ")
        XCTAssertEqual(KhmerFormat.weekdayName(7, short: false), "អាទិត្យ")
        XCTAssertEqual(KhmerFormat.weekdayName(7, short: true), "អា")
    }

    func testDayKeyRoundTrip() {
        XCTAssertEqual(DayKey(year: 2026, month: 11, day: 11).string, "2026-11-11")
        XCTAssertEqual(DayKey("2026-01-05"), DayKey(year: 2026, month: 1, day: 5))
        XCTAssertNil(DayKey("2026-13-01"))
        XCTAssertNil(DayKey("2026-02-30"))
        XCTAssertNil(DayKey("x"))
    }

    func testDayKeyWeekdayAndAdding() {
        let day = DayKey(year: 2026, month: 11, day: 11)   // a Wednesday
        XCTAssertEqual(day.weekday, 3)
        XCTAssertEqual(day.adding(days: 20), DayKey(year: 2026, month: 12, day: 1))
        XCTAssertEqual(DayKey(year: 2024, month: 3, day: 1).adding(days: -1), DayKey(year: 2024, month: 2, day: 29))
    }

    func testDayKeyFromDateUsesTheGivenCalendar() {
        var phnomPenh = Calendar(identifier: .gregorian)
        phnomPenh.timeZone = TimeZone(identifier: "Asia/Phnom_Penh")!
        // 2026-11-10 18:30 UTC is already 11 Nov, 01:30, in Phnom Penh.
        let date = Date(timeIntervalSince1970: 1_794_335_400)
        XCTAssertEqual(DayKey(date, calendar: phnomPenh), DayKey(year: 2026, month: 11, day: 11))
    }

    // MARK: Latin letters

    private let thursday = DayKey(year: 2026, month: 11, day: 12)   // ៣កើត ខែកត្ដិក, BE 2570

    func testLatinNumbersAndNames() {
        XCTAssertEqual(KhmerFormat.numerals(2570, script: .latin), "2570")
        XCTAssertEqual(KhmerFormat.solarMonthName(11, script: .latin), "November")
        XCTAssertEqual(KhmerFormat.weekdayName(4, short: false, script: .latin), "Thursday")
        XCTAssertEqual((1...7).map { KhmerFormat.weekdayName($0, short: true, script: .latin) }, ["M", "T", "W", "T", "F", "S", "S"])
    }

    func testLatinLunarText() {
        let date = KhmerCalendar.date(thursday)
        // The calendar's own words (កើត, រោច, the lunar month) stay in Khmer; the rest is English.
        XCTAssertEqual(KhmerFormat.lunarDay(date, script: .latin), "3កើត")
        XCTAssertEqual(KhmerFormat.lunarDay(KhmerCalendar.date(DayKey(year: 2026, month: 11, day: 25)), script: .latin), "1រោច")
        XCTAssertEqual(KhmerFormat.lunarLine(date, script: .latin), "3 កើត · ខែកត្ដិក · Year of the Horse · BE 2570")
    }

    func testEveryAnimalHasAnEnglishName() {
        XCTAssertEqual(AnimalYear.allCases.map(\.latinName),
                       ["Rat", "Ox", "Tiger", "Rabbit", "Dragon", "Snake", "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig"])
    }

    func testDateLineAndMonthTitle() {
        XCTAssertEqual(KhmerFormat.dateLine(thursday, script: .latin), "Thursday 12 November 2026")
        XCTAssertEqual(KhmerFormat.dateLine(thursday, script: .khmer), "ថ្ងៃព្រហស្បតិ៍ ទី១២ ខែវិច្ឆិកា ២០២៦")
        XCTAssertEqual(KhmerFormat.monthTitle(year: 2026, month: 11, buddhistYear: 2570, script: .latin), "November 2026 · BE 2570")
        XCTAssertEqual(KhmerFormat.monthTitle(year: 2026, month: 11, buddhistYear: 2570, script: .khmer), "វិច្ឆិកា ២០២៦ · ព.ស. ២៥៧០")
    }

    func testKhmerOutputUnchanged() {
        let date = KhmerCalendar.date(thursday)
        XCTAssertEqual(KhmerFormat.lunarDay(date), KhmerFormat.lunarDay(date, script: .khmer))
        XCTAssertEqual(KhmerFormat.lunarLine(date), KhmerFormat.lunarLine(date, script: .khmer))
        XCTAssertEqual(KhmerFormat.lunarDay(date), "៣កើត")
    }
}
