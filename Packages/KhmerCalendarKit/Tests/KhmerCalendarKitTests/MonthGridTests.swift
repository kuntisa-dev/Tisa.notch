import XCTest
@testable import KhmerCalendarKit

final class MonthGridTests: XCTestCase {
    func testNovember2026Grid() {          // 1 Nov 2026 is a Sunday
        let days = MonthGrid.days(year: 2026, month: 11)
        XCTAssertEqual(days.count, 42)
        XCTAssertEqual(days[0].key, DayKey(year: 2026, month: 10, day: 26))
        XCTAssertFalse(days[0].inMonth)
        XCTAssertEqual(days[6].key, DayKey(year: 2026, month: 11, day: 1))
        XCTAssertTrue(days[6].isSunday && days[6].inMonth)
    }

    func testGridAlwaysStartsMonday() {
        for year in 1900...2100 {
            for month in 1...12 {
                let days = MonthGrid.days(year: year, month: month)
                XCTAssertEqual(days.count, 42)
                XCTAssertEqual(days[0].key.weekday, 1, "\(year)-\(month)")
                XCTAssertTrue(days.prefix(7).contains { $0.key == DayKey(year: year, month: month, day: 1) }, "\(year)-\(month)")
                XCTAssertEqual(days.filter(\.isSunday).count, 6)
            }
        }
    }
}
