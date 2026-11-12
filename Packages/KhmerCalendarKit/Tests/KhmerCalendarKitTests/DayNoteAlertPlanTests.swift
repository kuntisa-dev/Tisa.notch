import XCTest
@testable import KhmerCalendarKit

final class DayNoteAlertPlanTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Phnom_Penh")!
        return calendar
    }()

    private let day = DayKey(year: 2026, month: 11, day: 11)
    /// 11 Nov 2026, 08:00 in Phnom Penh.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 8))! }

    private func note(_ title: String, at time: (hour: Int, minute: Int)?, alert: Bool) -> DayNote {
        DayNote.make(day: day, title: title, time: time, alert: alert)!
    }

    private func change(_ notes: [DayNote], pending: Set<String> = []) -> DayNoteAlertPlan.Change {
        DayNoteAlertPlan.change(book: DayNoteBook(notes: notes), pending: pending, now: now, calendar: calendar)
    }

    func testIdentifier() {
        let id = UUID()
        XCTAssertEqual(DayNoteAlertPlan.identifier(for: id), "day-note-\(id.uuidString)")
    }

    func testFireDate() {
        let fire = DayNoteAlertPlan.fireDate(for: note("a", at: (9, 30), alert: true), calendar: calendar)
        XCTAssertEqual(fire, calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 9, minute: 30)))
        XCTAssertNil(DayNoteAlertPlan.fireDate(for: note("a", at: nil, alert: false), calendar: calendar))
    }

    func testSchedulesAFutureNoteWithAlert() {
        let future = note("future", at: (9, 0), alert: true)
        XCTAssertEqual(change([future]).schedule, [future])
    }

    func testDoesNotScheduleWithoutAlertOrTimeOrInThePast() {
        let notes = [
            note("no alert", at: (9, 0), alert: false),
            note("no time", at: nil, alert: true),
            note("past", at: (7, 59), alert: true),
            note("now", at: (8, 0), alert: true)
        ]
        XCTAssertEqual(change(notes).schedule, [])
    }

    func testRemovesPendingAlertsThatNoLongerApply() {
        let deleted = DayNoteAlertPlan.identifier(for: UUID())
        let lostTime = note("lost its time", at: nil, alert: false)
        let alertOff = note("alert off", at: (9, 0), alert: false)
        let kept = note("kept", at: (10, 0), alert: true)
        let pending: Set<String> = [
            deleted,
            DayNoteAlertPlan.identifier(for: lostTime.id),
            DayNoteAlertPlan.identifier(for: alertOff.id),
            DayNoteAlertPlan.identifier(for: kept.id)
        ]
        let result = change([lostTime, alertOff, kept], pending: pending)
        XCTAssertEqual(Set(result.remove), pending.subtracting([DayNoteAlertPlan.identifier(for: kept.id)]))
        XCTAssertEqual(result.schedule, [kept])
    }

    func testNeverRemovesOtherFeaturesNotifications() {
        let result = change([], pending: ["ai-usage-quota-1", "something-else"])
        XCTAssertEqual(result.remove, [])
    }
}
