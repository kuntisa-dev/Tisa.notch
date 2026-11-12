import XCTest
@testable import KhmerCalendarKit

final class RoutinePlanTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Phnom_Penh")!
        return c
    }()

    private func at(_ day: Int, _ hour: Int, _ minute: Int, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func routine(at hour: Int = 5, _ minute: Int = 30, lead: Int = 0, created: TimeInterval = 0) -> Routine {
        Routine.make(title: "Run", hour: hour, minute: minute, weekdays: Set(1...7), getReadyMinutes: lead,
                     startDay: DayKey(year: 2026, month: 11, day: 1), createdAt: Date(timeIntervalSince1970: created))!
    }

    private func dueNow(_ book: RoutineBook, _ now: Date, handled: Set<String> = [], snoozed: [String: Date] = [:]) -> [RoutineOccurrence] {
        RoutinePlan.dueNow(book: book, now: now, calendar: calendar, handled: handled, snoozedUntil: snoozed)
    }

    func testOccurrencesWithAndWithoutGetReady() {
        let day = DayKey(year: 2026, month: 11, day: 12)
        let both = RoutinePlan.occurrences(of: routine(lead: 30), on: day, calendar: calendar)
        XCTAssertEqual(both.map(\.kind), [.getReady, .due])
        XCTAssertEqual(both.map(\.fireDate), [at(12, 5, 0), at(12, 5, 30)])
        XCTAssertEqual(RoutinePlan.occurrences(of: routine(), on: day, calendar: calendar).map(\.kind), [.due])
    }

    func testGetReadyCrossesMidnight() {
        let r = routine(at: 0, 15, lead: 30)
        let ready = RoutinePlan.occurrences(of: r, on: DayKey(year: 2026, month: 11, day: 13), calendar: calendar)[0]
        XCTAssertEqual(ready.fireDate, at(12, 23, 45))
        XCTAssertEqual(ready.day, DayKey(year: 2026, month: 11, day: 13))
        XCTAssertEqual(dueNow(RoutineBook(routines: [r]), at(12, 23, 46)), [ready])
    }

    func testDueNowCatchUpWindow() {
        let book = RoutineBook(routines: [routine()])
        XCTAssertEqual(dueNow(book, at(12, 5, 29)), [])
        XCTAssertEqual(dueNow(book, at(12, 5, 30)).map(\.kind), [.due])
        XCTAssertEqual(dueNow(book, at(12, 7, 30)).map(\.kind), [.due])
        XCTAssertEqual(dueNow(book, at(12, 7, 31)), [])
    }

    func testDueNowSkipsDoneHandledSnoozed() {
        let r = routine()
        var book = RoutineBook(routines: [r])
        let due = dueNow(book, at(12, 5, 35))[0]
        XCTAssertEqual(dueNow(book, at(12, 5, 35), handled: [due.id]), [])
        XCTAssertEqual(dueNow(book, at(12, 5, 35), snoozed: [due.id: at(12, 5, 40)]), [])
        XCTAssertEqual(dueNow(book, at(12, 5, 40), snoozed: [due.id: at(12, 5, 40)]), [due])
        book.setDone(r.id, on: DayKey(year: 2026, month: 11, day: 12))
        XCTAssertEqual(dueNow(book, at(12, 5, 35)), [])
    }

    func testGetReadyReplacedByDue() {
        let book = RoutineBook(routines: [routine(lead: 30)])
        XCTAssertEqual(dueNow(book, at(12, 5, 10)).map(\.kind), [.getReady])
        XCTAssertEqual(dueNow(book, at(12, 5, 31)).map(\.kind), [.due])
    }

    func testDueNowReturnsAllInTimeOrder() {
        let second = routine(created: 2)
        let first = routine(created: 1)
        let early = routine(at: 5, 0, created: 3)
        let found = dueNow(RoutineBook(routines: [second, first, early]), at(12, 5, 31))
        XCTAssertEqual(found.map(\.routineID), [early.id, first.id, second.id])
    }

    func testBackupsWindowAndDone() {
        let r = routine(lead: 30)
        var book = RoutineBook(routines: [r])
        let now = at(12, 4, 0)
        let ids = RoutinePlan.backups(book: book, now: now, calendar: calendar).map(\.id)
        let prefix = "routine-\(r.id.uuidString)-"
        XCTAssertEqual(ids, [prefix + "2026-11-12-ready", prefix + "2026-11-12-due",
                             prefix + "2026-11-13-ready", prefix + "2026-11-13-due"])

        book.setDone(r.id, on: DayKey(year: 2026, month: 11, day: 12))
        let after = RoutinePlan.backups(book: book, now: now, calendar: calendar)
        XCTAssertEqual(after.map(\.id), [prefix + "2026-11-13-ready", prefix + "2026-11-13-due"])
        for occ in after {
            let fire = occ.fireDate.addingTimeInterval(RoutinePlan.backupDelay)
            XCTAssertTrue(fire > now && fire <= now.addingTimeInterval(RoutinePlan.lookAhead))
        }
    }

    func testBackupsSkipRemindersTheNotchAlreadyShowed() {
        let r = routine(lead: 30)
        let book = RoutineBook(routines: [r])
        let now = at(12, 5, 0)
        let ready = RoutinePlan.backups(book: book, now: now, calendar: calendar)[0]
        XCTAssertEqual(ready.kind, .getReady)
        let rest = RoutinePlan.backups(book: book, now: now, calendar: calendar, excluding: [ready.id])
        XCTAssertFalse(rest.contains(ready))
        XCTAssertEqual(rest.count, 3)
    }

    func testIDRoundTrip() {
        let occ = RoutinePlan.occurrences(of: routine(lead: 30), on: DayKey(year: 2026, month: 11, day: 12), calendar: calendar)[0]
        let parts = RoutinePlan.occurrenceID(parsing: occ.id)
        XCTAssertEqual(parts?.routineID, occ.routineID)
        XCTAssertEqual(parts?.day, occ.day)
        XCTAssertEqual(parts?.kind, .getReady)
        XCTAssertNil(RoutinePlan.occurrenceID(parsing: "day-note-x"))
        XCTAssertNil(RoutinePlan.occurrenceID(parsing: "routine-nonsense"))
    }
}
