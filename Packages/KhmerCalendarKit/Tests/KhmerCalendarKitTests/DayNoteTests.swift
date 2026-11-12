import XCTest
@testable import KhmerCalendarKit

final class DayNoteTests: XCTestCase {
    private let day = DayKey(year: 2026, month: 11, day: 11)
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("DayNoteTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func note(_ title: String, at time: (hour: Int, minute: Int)? = nil, alert: Bool = false,
                      created: TimeInterval = 0, on day: DayKey? = nil) -> DayNote {
        DayNote.make(day: day ?? self.day, title: title, time: time, alert: alert,
                     createdAt: Date(timeIntervalSince1970: created))!
    }

    // MARK: Making a note

    func testRejectsEmptyTitles() {
        XCTAssertNil(DayNote.make(day: day, title: "", time: nil, alert: false))
        XCTAssertNil(DayNote.make(day: day, title: "   \n\t", time: nil, alert: false))
    }

    func testTrimsTitle() {
        XCTAssertEqual(note("  hi \n").title, "hi")
    }

    func testCutsLongKhmerTitleOnACharacter() {
        let long = String(repeating: "កើ", count: 300)
        let made = note(long)
        XCTAssertEqual(made.title.count, 200)
        XCTAssertEqual(made.title, String(repeating: "កើ", count: 200))
    }

    func testAlertNeedsATime() {
        XCTAssertFalse(note("a", at: nil, alert: true).alert)
        XCTAssertTrue(note("a", at: (9, 0), alert: true).alert)
    }

    func testRejectsImpossibleTimes() {
        XCTAssertNil(DayNote.make(day: day, title: "a", time: (24, 0), alert: false))
        XCTAssertNil(DayNote.make(day: day, title: "a", time: (9, 60), alert: false))
        XCTAssertNil(DayNote.make(day: day, title: "a", time: (-1, 0), alert: false))
    }

    func testKeepsTheDayAsText() {
        XCTAssertEqual(note("a").day, "2026-11-11")
    }

    // MARK: The book

    func testSortsTimedFirstThenByCreation() {
        var book = DayNoteBook()
        book.upsert(note("later untimed", created: 20))
        book.upsert(note("afternoon", at: (14, 30), created: 5))
        book.upsert(note("first untimed", created: 10))
        book.upsert(note("morning", at: (9, 0), created: 30))
        book.upsert(note("other day", on: DayKey(year: 2026, month: 11, day: 12)))
        XCTAssertEqual(book.notes(on: day).map(\.title), ["morning", "afternoon", "first untimed", "later untimed"])
    }

    func testUpsertReplacesById() {
        var book = DayNoteBook()
        var one = note("one")
        book.upsert(one)
        one.title = "changed"
        book.upsert(one)
        XCTAssertEqual(book.notes.map(\.title), ["changed"])
    }

    func testRemoveAndDaysWithNotes() {
        var book = DayNoteBook()
        let one = note("one")
        book.upsert(one)
        XCTAssertEqual(book.daysWithNotes, ["2026-11-11"])
        book.remove(id: one.id)
        XCTAssertTrue(book.daysWithNotes.isEmpty)
    }

    // MARK: The file

    func testSaveCreatesFoldersAndRoundTrips() throws {
        let url = folder.appendingPathComponent("Calendar/notes.json")
        var book = DayNoteBook()
        book.upsert(note("ប្រជុំ", at: (9, 15), alert: true, created: 1_000))
        book.upsert(note("plain", created: 2_000))
        try DayNoteFile.save(book, to: url)

        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("\"version\" : 1"), text)

        guard case .loaded(let loaded) = DayNoteFile.load(from: url) else { return XCTFail("not loaded") }
        XCTAssertEqual(loaded, book)
    }

    func testMissingFile() {
        guard case .missing = DayNoteFile.load(from: folder.appendingPathComponent("notes.json")) else {
            return XCTFail("expected missing")
        }
    }

    func testHalfWrittenFileIsKeptAside() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("notes.json")
        let broken = Data("{\"version\":1,\"notes\":[".utf8)
        try broken.write(to: url)

        guard case .unreadable(let moved) = DayNoteFile.load(from: url, now: Date(timeIntervalSince1970: 1_794_335_400)) else {
            return XCTFail("expected unreadable")
        }
        XCTAssertTrue(moved.lastPathComponent.hasPrefix("notes-unreadable-"))
        XCTAssertEqual(moved.pathExtension, "json")
        XCTAssertEqual(try Data(contentsOf: moved), broken)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testUnreadableFileThatCannotBeMovedIsReportedAsStuck() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("notes.json")
        let broken = Data("{\"version\":1,\"notes\":[".utf8)
        try broken.write(to: url)
        // A read-only folder: the file cannot be renamed inside it.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }

        guard case .unreadableInPlace = DayNoteFile.load(from: url) else {
            return XCTFail("expected unreadableInPlace")
        }
        XCTAssertEqual(try Data(contentsOf: url), broken)
    }

    func testNewerVersionIsKeptAside() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("notes.json")
        try Data("{\"version\":2,\"notes\":[]}".utf8).write(to: url)
        guard case .unreadable = DayNoteFile.load(from: url) else { return XCTFail("expected unreadable") }
    }

    func testTwoUnreadableFilesInOneSecondBothSurvive() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("notes.json")
        let now = Date(timeIntervalSince1970: 1_794_335_400)
        try Data("first".utf8).write(to: url)
        guard case .unreadable(let one) = DayNoteFile.load(from: url, now: now) else { return XCTFail() }
        try Data("second".utf8).write(to: url)
        guard case .unreadable(let two) = DayNoteFile.load(from: url, now: now) else { return XCTFail() }
        XCTAssertNotEqual(one, two)
        XCTAssertEqual(try String(contentsOf: one, encoding: .utf8), "first")
        XCTAssertEqual(try String(contentsOf: two, encoding: .utf8), "second")
    }

    func testNoteWithAnOddDayIsKeptInTheFile() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("notes.json")
        let json = """
        {"version":1,"notes":[
          {"id":"\(UUID().uuidString)","day":"2026-11-11","title":"good","alert":false,"createdAt":"2026-11-11T00:00:00Z"},
          {"id":"\(UUID().uuidString)","day":"not-a-day","title":"odd","alert":false,"createdAt":"2026-11-11T00:00:00Z"}
        ]}
        """
        try Data(json.utf8).write(to: url)
        guard case .loaded(let book) = DayNoteFile.load(from: url) else { return XCTFail("not loaded") }
        XCTAssertEqual(book.notes(on: day).map(\.title), ["good"])
        try DayNoteFile.save(book, to: url)
        guard case .loaded(let again) = DayNoteFile.load(from: url) else { return XCTFail("not loaded") }
        XCTAssertEqual(Set(again.notes.map(\.title)), ["good", "odd"])
    }
}
