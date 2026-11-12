import XCTest
@testable import KhmerCalendarKit

final class RoutineFileTests: XCTestCase {
    private var folder: URL!
    private var url: URL { folder.appendingPathComponent("routines.json") }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("RoutineFileTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
        try? FileManager.default.removeItem(at: folder)
    }

    private func writeRaw(_ text: String) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    func testRoundTrip() throws {
        let start = DayKey(year: 2026, month: 11, day: 1)
        let run = Routine.make(title: "រត់", hour: 5, minute: 30, weekdays: Set(1...7), getReadyMinutes: 30,
                               startDay: start, createdAt: Date(timeIntervalSince1970: 1_000))!
        let study = Routine.make(title: "Study", hour: 20, minute: 0, weekdays: Set(1...5), getReadyMinutes: 0,
                                 startDay: start, createdAt: Date(timeIntervalSince1970: 2_000))!
        var book = RoutineBook(routines: [run, study])
        book.setDone(run.id, on: DayKey(year: 2026, month: 11, day: 11))
        book.setDone(run.id, on: DayKey(year: 2026, month: 11, day: 10))
        try RoutineFile.save(book, to: folder.appendingPathComponent("Calendar/routines.json"))

        let saved = folder.appendingPathComponent("Calendar/routines.json")
        let text = try String(contentsOf: saved, encoding: .utf8)
        XCTAssertTrue(text.contains("\"version\" : 1"), text)
        XCTAssertTrue(text.contains("\"2026-11-10\",\n"), text)  // done days are written in order

        guard case .loaded(let loaded) = RoutineFile.load(from: saved) else { return XCTFail("not loaded") }
        XCTAssertEqual(loaded, book)
    }

    func testMissing() {
        guard case .missing = RoutineFile.load(from: url) else { return XCTFail("expected missing") }
    }

    func testBrokenFileMovedAside() throws {
        try writeRaw("{\"version\":1,\"routines\":[")
        guard case .unreadable(let moved) = RoutineFile.load(from: url) else { return XCTFail("expected unreadable") }
        XCTAssertTrue(moved.lastPathComponent.hasPrefix("routines-unreadable-"))
        XCTAssertEqual(try String(contentsOf: moved, encoding: .utf8), "{\"version\":1,\"routines\":[")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testStuckFileReportedInPlace() throws {
        try writeRaw("broken")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        guard case .unreadableInPlace = RoutineFile.load(from: url) else { return XCTFail("expected unreadableInPlace") }
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "broken")
    }

    func testNewerVersionMovedAside() throws {
        try writeRaw("{\"version\":2,\"routines\":[],\"done\":{}}")
        guard case .unreadable = RoutineFile.load(from: url) else { return XCTFail("expected unreadable") }
    }
}
