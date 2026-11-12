import XCTest
@testable import KhmerCalendarKit

final class KhmerHolidaysTests: XCTestCase {
    private func names(_ year: Int, _ month: Int, _ day: Int) -> [String] {
        KhmerCalendar.holidays(DayKey(year: year, month: month, day: day)).map(\.englishName)
    }

    private func days(named name: String, in year: Int) -> [String] {
        var found: [String] = []
        var day = DayKey(year: year, month: 1, day: 1)
        while day.year == year {
            if KhmerCalendar.holidays(day).contains(where: { $0.englishName == name }) { found.append(day.string) }
            day = day.adding(days: 1)
        }
        return found
    }

    func testFixedHolidays() {
        let fixed = [(1, 1), (1, 7), (3, 8), (5, 1), (5, 14), (6, 18), (9, 24), (10, 15), (10, 29), (11, 9), (12, 29)]
        for (month, day) in fixed {
            let holidays = KhmerCalendar.holidays(DayKey(year: 2026, month: month, day: day))
            XCTAssertFalse(holidays.isEmpty, "\(month)-\(day)")
            XCTAssertTrue(holidays.contains { $0.isDayOff }, "\(month)-\(day)")
            XCTAssertFalse(holidays[0].khmerName.isEmpty)
        }
        XCTAssertEqual(names(2026, 11, 9), ["Independence Day"])
    }

    func testOrdinaryDayHasNone() {
        XCTAssertEqual(names(2026, 11, 11), [])
        XCTAssertEqual(names(2026, 2, 3), [])
    }

    func testKhmerNewYear() {
        XCTAssertEqual(days(named: "Khmer New Year", in: 2024), ["2024-04-13", "2024-04-14", "2024-04-15", "2024-04-16"])
        XCTAssertEqual(days(named: "Khmer New Year", in: 2025), ["2025-04-14", "2025-04-15", "2025-04-16"])
        XCTAssertEqual(days(named: "Khmer New Year", in: 2026), ["2026-04-14", "2026-04-15", "2026-04-16"])
    }

    func testVisakBocheaAndPloughing() {
        XCTAssertEqual(days(named: "Visak Bochea", in: 2024), ["2024-05-22"])
        XCTAssertEqual(days(named: "Visak Bochea", in: 2025), ["2025-05-11"])
        XCTAssertEqual(days(named: "Royal Ploughing Ceremony", in: 2024), ["2024-05-26"])
        XCTAssertEqual(days(named: "Royal Ploughing Ceremony", in: 2025), ["2025-05-15"])
    }

    func testPchumBen() {
        XCTAssertEqual(days(named: "Pchum Ben", in: 2024), ["2024-10-01", "2024-10-02", "2024-10-03"])
        XCTAssertEqual(days(named: "Pchum Ben", in: 2025), ["2025-09-21", "2025-09-22", "2025-09-23"])
    }

    func testWaterFestival() {
        XCTAssertEqual(days(named: "Water Festival", in: 2024), ["2024-11-14", "2024-11-15", "2024-11-16"])
        XCTAssertEqual(days(named: "Water Festival", in: 2025), ["2025-11-04", "2025-11-05", "2025-11-06"])
    }

    func testMeakBocheaIsNotADayOff() {
        XCTAssertEqual(days(named: "Meak Bochea", in: 2025), ["2025-02-12"])
        let holiday = KhmerCalendar.holidays(DayKey(year: 2025, month: 2, day: 12))
        XCTAssertEqual(holiday.map(\.isDayOff), [false])
    }

    func testLeapMonthYearStillHasThreeDayFestivals() {     // 2023 has two Asadh months
        XCTAssertEqual(days(named: "Pchum Ben", in: 2023), ["2023-10-13", "2023-10-14", "2023-10-15"])
        XCTAssertEqual(days(named: "Water Festival", in: 2023), ["2023-11-26", "2023-11-27", "2023-11-28"])
        XCTAssertEqual(days(named: "Visak Bochea", in: 2023), ["2023-05-04"])
    }

    func testEveryYearHasEachFestivalOnce() {
        for year in 1950...2100 {
            XCTAssertEqual(days(named: "Pchum Ben", in: year).count, 3, "\(year)")
            XCTAssertEqual(days(named: "Water Festival", in: year).count, 3, "\(year)")
            XCTAssertEqual(days(named: "Visak Bochea", in: year).count, 1, "\(year)")
            XCTAssertTrue([3, 4].contains(days(named: "Khmer New Year", in: year).count), "\(year)")
        }
    }
}
