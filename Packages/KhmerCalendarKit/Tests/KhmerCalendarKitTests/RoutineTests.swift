import XCTest
@testable import KhmerCalendarKit

final class RoutineTests: XCTestCase {
    /// Thursday.
    private let today = DayKey(year: 2026, month: 11, day: 12)

    private func day(_ d: Int) -> DayKey { DayKey(year: 2026, month: 11, day: d) }

    private func routine(_ title: String = "Run", at hour: Int = 5, _ minute: Int = 30,
                         days: Set<Int> = Set(1...7), from start: Int = 1, created: TimeInterval = 0) -> Routine {
        Routine.make(title: title, hour: hour, minute: minute, weekdays: days, getReadyMinutes: 30,
                     startDay: day(start), createdAt: Date(timeIntervalSince1970: created))!
    }

    // MARK: Making a routine

    func testMakeValidates() {
        let start = day(1)
        XCTAssertNil(Routine.make(title: "", hour: 5, minute: 0, weekdays: [1], getReadyMinutes: 0, startDay: start))
        XCTAssertNil(Routine.make(title: "  \n", hour: 5, minute: 0, weekdays: [1], getReadyMinutes: 0, startDay: start))
        XCTAssertNil(Routine.make(title: "a", hour: 24, minute: 0, weekdays: [1], getReadyMinutes: 0, startDay: start))
        XCTAssertNil(Routine.make(title: "a", hour: 5, minute: 60, weekdays: [1], getReadyMinutes: 0, startDay: start))
        XCTAssertNil(Routine.make(title: "a", hour: 5, minute: 0, weekdays: [], getReadyMinutes: 0, startDay: start))
        XCTAssertNil(Routine.make(title: "a", hour: 5, minute: 0, weekdays: [0], getReadyMinutes: 0, startDay: start))
        XCTAssertNil(Routine.make(title: "a", hour: 5, minute: 0, weekdays: [8], getReadyMinutes: 0, startDay: start))
        XCTAssertNil(Routine.make(title: "a", hour: 5, minute: 0, weekdays: [1], getReadyMinutes: 20, startDay: start))

        let long = String(repeating: "រត់", count: 150)
        let made = Routine.make(title: "  " + long, hour: 5, minute: 0, weekdays: [1], getReadyMinutes: 0, startDay: start)
        XCTAssertEqual(made?.title.count, 100)
        XCTAssertEqual(made?.startDay, "2026-11-01")
    }

    func testScheduledRespectsWeekdaysAndStart() {
        let r = routine(days: Set(1...5), from: 10)
        XCTAssertTrue(r.isScheduled(on: day(12)))   // Thursday
        XCTAssertFalse(r.isScheduled(on: day(14)))  // Saturday
        XCTAssertFalse(r.isScheduled(on: day(9)))   // Monday, before the start
    }

    // MARK: Status

    func testStatus() {
        let r = routine(days: Set(1...5))
        var book = RoutineBook(routines: [r])
        book.setDone(r.id, on: day(10))
        XCTAssertEqual(book.status(of: r, on: day(10), today: today), .done)
        XCTAssertEqual(book.status(of: r, on: day(11), today: today), .missed)
        XCTAssertEqual(book.status(of: r, on: today, today: today), .upcoming)
        XCTAssertEqual(book.status(of: r, on: day(14), today: today), .none)
        XCTAssertEqual(book.status(of: r, on: day(13), today: today), .none)  // future
    }

    func testStatusUsesCurrentDaysOnly() {
        var r = routine()
        var book = RoutineBook(routines: [r])
        book.setDone(r.id, on: day(7))      // Saturday
        r.weekdays = Set(1...5)
        book.upsert(r)
        XCTAssertEqual(book.status(of: r, on: day(7), today: today), .done)
        XCTAssertEqual(book.status(of: r, on: day(8), today: today), .none)  // Sunday, never done
        XCTAssertEqual(book.status(of: r, on: day(10), today: today), .missed)
    }

    func testDayMark() {
        let a = routine("a", created: 1)
        let b = routine("b", at: 20, 0, created: 2)
        var book = RoutineBook(routines: [a, b])
        book.setDone(a.id, on: day(10))
        book.setDone(b.id, on: day(10))
        book.setDone(a.id, on: day(11))
        XCTAssertEqual(book.mark(on: day(10), today: today), .allDone)
        XCTAssertEqual(book.mark(on: day(11), today: today), .someMissed)
        XCTAssertNil(book.mark(on: today, today: today))
        book.setDone(a.id, on: today)
        book.setDone(b.id, on: today)
        XCTAssertEqual(book.mark(on: today, today: today), .allDone)
        XCTAssertNil(RoutineBook(routines: [routine(days: [6])]).mark(on: day(10), today: today))
        XCTAssertNil(book.mark(on: day(13), today: today))
    }

    func testTickWindow() {
        XCTAssertTrue(RoutineBook.canTick(today, today: today))
        XCTAssertTrue(RoutineBook.canTick(day(11), today: today))
        XCTAssertFalse(RoutineBook.canTick(day(10), today: today))
        XCTAssertFalse(RoutineBook.canTick(day(13), today: today))

        let r = routine()
        var book = RoutineBook(routines: [r])
        XCTAssertFalse(book.toggleDone(r.id, on: day(10), today: today))
        XCTAssertEqual(book.done, [:])
        XCTAssertFalse(book.toggleDone(UUID(), on: today, today: today))
        XCTAssertTrue(book.toggleDone(r.id, on: today, today: today))
        XCTAssertTrue(book.isDone(r.id, on: today))
        XCTAssertTrue(book.toggleDone(r.id, on: today, today: today))
        XCTAssertFalse(book.isDone(r.id, on: today))
    }

    // MARK: Streak

    func testStreak() {
        let r = routine()
        var book = RoutineBook(routines: [r])
        for d in 5...11 { book.setDone(r.id, on: day(d)) }
        XCTAssertEqual(book.streak(of: r, today: today), 7)
        book.setDone(r.id, on: today)
        XCTAssertEqual(book.streak(of: r, today: today), 8)
    }

    func testStreakSkipsUnscheduledDays() {
        let r = routine(days: [1, 3, 5])
        var book = RoutineBook(routines: [r])
        book.setDone(r.id, on: day(9))
        book.setDone(r.id, on: day(11))
        XCTAssertEqual(book.streak(of: r, today: today), 2)
    }

    func testStreakStopsAtMissedAndStart() {
        let r = routine()
        var book = RoutineBook(routines: [r])
        book.setDone(r.id, on: day(10))
        book.setDone(r.id, on: day(11))
        XCTAssertEqual(book.streak(of: r, today: today), 2)

        let fresh = routine(from: 12)
        XCTAssertEqual(RoutineBook(routines: [fresh]).streak(of: fresh, today: today), 0)
    }

    func testRepeatText() {
        XCTAssertEqual(RoutineRepeatText.text(Set(1...7)), "Every day")
        XCTAssertEqual(RoutineRepeatText.text(Set(1...5)), "Mon–Fri")
        XCTAssertEqual(RoutineRepeatText.text([6, 7]), "Weekend")
        XCTAssertEqual(RoutineRepeatText.text([5, 1, 3]), "Mon, Wed, Fri")
        XCTAssertEqual(RoutineRepeatText.text([7]), "Sun")
    }

    // MARK: The book

    func testRemoveDropsHistory() {
        let r = routine()
        var book = RoutineBook(routines: [r])
        book.setDone(r.id, on: today)
        book.remove(id: r.id)
        XCTAssertNil(book.done[r.id])
        XCTAssertTrue(book.routines.isEmpty)
    }

    func testRoutinesOnDaySorted() {
        let late = routine("late", at: 20, 0, created: 1)
        let early = routine("early", at: 5, 30, created: 2)
        let weekend = routine("weekend", days: [6, 7], created: 3)
        let book = RoutineBook(routines: [late, early, weekend])
        XCTAssertEqual(book.routines(on: today).map(\.title), ["early", "late"])
    }
}
