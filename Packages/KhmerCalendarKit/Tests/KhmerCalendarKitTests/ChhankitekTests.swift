import XCTest
@testable import KhmerCalendarKit

final class ChhankitekTests: XCTestCase {
    private func khmer(_ year: Int, _ month: Int, _ day: Int) -> KhmerDate {
        KhmerCalendar.date(DayKey(year: year, month: month, day: day))
    }

    private func assert(_ date: KhmerDate, _ day: Int, _ phase: MoonPhase, _ month: KhmerMonth,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(date.lunarDay, day, file: file, line: line)
        XCTAssertEqual(date.phase, phase, file: file, line: line)
        XCTAssertEqual(date.month, month, file: file, line: line)
    }

    // MARK: Published festival dates

    func testVisakBochea() {
        assert(khmer(2024, 5, 22), 15, .keit, .pisakh)
        assert(khmer(2025, 5, 11), 15, .keit, .pisakh)
    }

    func testPchumBenMainDay() {
        assert(khmer(2024, 10, 2), 15, .roach, .photrobot)
        assert(khmer(2025, 9, 22), 15, .roach, .photrobot)
    }

    func testWaterFestivalMiddleDay() {
        assert(khmer(2024, 11, 15), 15, .keit, .kadeuk)
        assert(khmer(2025, 11, 5), 15, .keit, .kadeuk)
    }

    func testNewYearDays() {
        XCTAssertEqual(KhmerCalendar.newYearDay(gregorianYear: 2024), DayKey(year: 2024, month: 4, day: 13))
        XCTAssertEqual(KhmerCalendar.newYearDay(gregorianYear: 2025), DayKey(year: 2025, month: 4, day: 14))
        XCTAssertEqual(KhmerCalendar.newYearDay(gregorianYear: 2026), DayKey(year: 2026, month: 4, day: 14))
    }

    // MARK: Year changes

    func testBuddhistYearChangesAfterVisakBochea() {
        XCTAssertEqual(khmer(2025, 5, 11).buddhistYear, 2568)
        XCTAssertEqual(khmer(2025, 5, 12).buddhistYear, 2569)
        XCTAssertEqual(khmer(2026, 1, 1).buddhistYear, 2569)
    }

    func testAnimalYearChangesAtNewYear() {     // 2025 is ម្សាញ់, 2026 is មមី
        let newYear = KhmerCalendar.newYearDay(gregorianYear: 2026)
        XCTAssertEqual(KhmerCalendar.date(newYear).animalYear, .momee)
        XCTAssertEqual(KhmerCalendar.date(newYear.adding(days: -1)).animalYear, .masagn)
        XCTAssertEqual(khmer(2026, 11, 11).animalYear, .momee)
        XCTAssertEqual(khmer(2026, 1, 1).animalYear, .masagn)
    }

    // MARK: Leap months

    func testLeapMonthYearHasTwoAsadh() {
        var months = Set<KhmerMonth>()
        var day = DayKey(year: 2023, month: 1, day: 1)
        while day.year == 2023 {
            months.insert(KhmerCalendar.date(day).month)
            day = day.adding(days: 1)
        }
        XCTAssertTrue(months.contains(.pathamasadh))
        XCTAssertTrue(months.contains(.tutiyasadh))
        XCTAssertFalse(months.contains(.asadh))
    }

    func testOrdinaryYearHasOneAsadh() {
        var months = Set<KhmerMonth>()
        var day = DayKey(year: 2025, month: 1, day: 1)
        while day.year == 2025 {
            months.insert(KhmerCalendar.date(day).month)
            day = day.adding(days: 1)
        }
        XCTAssertTrue(months.contains(.asadh))
        XCTAssertFalse(months.contains(.pathamasadh))
        XCTAssertFalse(months.contains(.tutiyasadh))
    }

    // MARK: Every day, 1900...2100

    func testEveryDayIsContinuous() {
        var day = DayKey(year: 1900, month: 1, day: 1)
        var previous = KhmerCalendar.date(day)
        let end = DayKey(year: 2100, month: 12, day: 31)
        var failures = 0
        while day < end {
            day = day.adding(days: 1)
            let current = KhmerCalendar.date(day)
            XCTAssertTrue((1...15).contains(current.lunarDay))
            let sameMonth = current.month == previous.month
            let ok: Bool
            if current.phase == previous.phase && current.lunarDay == previous.lunarDay + 1 {
                ok = sameMonth
            } else if previous.phase == .keit && previous.lunarDay == 15 {
                ok = sameMonth && current.phase == .roach && current.lunarDay == 1
            } else if previous.phase == .roach && previous.lunarDay >= 14 {
                ok = !sameMonth && current.phase == .keit && current.lunarDay == 1
            } else {
                ok = false
            }
            if !ok {
                failures += 1
                if failures <= 5 { XCTFail("\(day.string): \(previous) -> \(current)") }
            }
            previous = current
        }
        XCTAssertEqual(failures, 0)
    }

    func testBuddhistYearNeverGoesBack() {
        var day = DayKey(year: 1900, month: 1, day: 1)
        var previous = KhmerCalendar.date(day).buddhistYear
        while day.year <= 2100 {
            day = day.adding(days: 1)
            let current = KhmerCalendar.date(day).buddhistYear
            XCTAssertTrue(current == previous || current == previous + 1, day.string)
            previous = current
        }
    }

    // MARK: Holy days

    func testHolyDays() {
        // November 2025: 15 កើត កត្ដិក is 5 Nov.
        XCTAssertTrue(khmer(2025, 11, 5).isHolyDay)       // 15 កើត
        XCTAssertTrue(khmer(2025, 10, 29).isHolyDay)      // 8 កើត
        XCTAssertFalse(khmer(2025, 10, 28).isHolyDay)     // 7 កើត
        XCTAssertTrue(khmer(2025, 11, 13).isHolyDay)      // 8 រោច
        XCTAssertFalse(khmer(2025, 11, 6).isHolyDay)      // 1 រោច
    }

    func testLastDayOfEveryMonthIsHoly() {
        var day = DayKey(year: 2020, month: 1, day: 1)
        while day.year < 2031 {
            let today = KhmerCalendar.date(day)
            let tomorrow = KhmerCalendar.date(day.adding(days: 1))
            if tomorrow.month != today.month {
                XCTAssertTrue(today.isHolyDay, day.string)
                XCTAssertEqual(today.phase, .roach)
            }
            day = day.adding(days: 1)
        }
    }

    // MARK: Text

    func testLunarText() {
        let date = khmer(2025, 11, 5)
        XCTAssertEqual(KhmerFormat.lunarDay(date), "១៥កើត")
        XCTAssertEqual(KhmerFormat.lunarLine(date), "១៥ កើត ខែកត្ដិក ឆ្នាំម្សាញ់ ព.ស. ២៥៦៩")
    }

    // MARK: Against momentkh's own data

    private func fixture(_ name: String) throws -> [String: String] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }

    func testMatchesReferenceConversions() throws {
        let weekdays = ["ចន្ទ", "អង្គារ", "ពុធ", "ព្រហស្បតិ៍", "សុក្រ", "សៅរ៍", "អាទិត្យ"]
        var checked = 0
        for (stamp, expected) in try fixture("conversion") {
            guard let key = DayKey(String(stamp.prefix(10))), (1900...2100).contains(key.year) else { continue }
            let words = expected.split(separator: " ").map(String.init)
            XCTAssertEqual(words.count, 7, expected)
            let date = KhmerCalendar.date(key)
            XCTAssertEqual("ថ្ងៃ" + weekdays[key.weekday - 1], words[0], stamp)
            XCTAssertEqual(KhmerFormat.lunarDay(date), words[1], stamp)
            XCTAssertEqual("ខែ" + date.month.name, words[2], stamp)
            XCTAssertEqual(KhmerFormat.numerals(date.buddhistYear), words[6], stamp)
            // The reference switches the animal year at the New Year's exact minute; this
            // engine switches on that day, so the day itself is left out.
            if key != KhmerCalendar.newYearDay(gregorianYear: key.year) {
                XCTAssertEqual("ឆ្នាំ" + date.animalYear.name, words[3], stamp)
            }
            checked += 1
        }
        XCTAssertGreaterThan(checked, 1000)
    }

    func testMatchesReferenceNewYears() throws {
        let newYears = try fixture("new-year")
        for year in 1900...2100 {
            let expected = try XCTUnwrap(newYears[String(year)])
            XCTAssertEqual(KhmerCalendar.newYearDay(gregorianYear: year).string, String(expected.prefix(10)), "\(year)")
        }
    }
}
