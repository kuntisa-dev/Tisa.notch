//
//  RoutineStore.swift
//  TisaDynamicIsland
//
//  The routines and the days they were done. They live in one file on this Mac:
//  Application Support › Tisa Dynamic Island › Calendar › routines.json.
//

import Foundation
import KhmerCalendarKit

@MainActor
final class RoutineStore: ObservableObject {
    static let shared = RoutineStore()

    @Published private(set) var book = RoutineBook()
    /// True when the last change could not be written; it is still shown until the app quits.
    @Published private(set) var saveFailed = false

    /// Set when routines.json could not be read or moved aside, so saving would destroy it.
    private var mustNotWrite = false
    /// The last backup sync. Each one waits for the one before, so an older list of
    /// routines can never put back a notification a newer one took away.
    private var backupSync: Task<Void, Never>?

    static var fileURL: URL {
        DayNoteStore.fileURL.deletingLastPathComponent().appendingPathComponent("routines.json")
    }

    private init() {
        switch RoutineFile.load(from: Self.fileURL) {
        case .loaded(let book):
            self.book = book
        case .missing:
            break
        case .unreadable(let movedTo):
            NSLog("Khmer calendar: routines.json could not be read and was kept as %@", movedTo.lastPathComponent)
        case .unreadableInPlace:
            NSLog("Khmer calendar: routines.json could not be read or moved; routines will not be saved")
            mustNotWrite = true
            saveFailed = true
        }
    }

    private var today: DayKey { DayKey(Date(), calendar: .current) }

    func save(_ routine: Routine) {
        book.upsert(routine)
        persist()
    }

    func delete(id: UUID) {
        book.remove(id: id)
        persist()
    }

    /// Ticks or unticks today or yesterday; other days are left alone.
    func toggleDone(_ id: UUID, on day: DayKey) {
        guard book.toggleDone(id, on: day, today: today) else { return }
        persist()
    }

    /// Marks a day done from a reminder.
    func markDone(_ id: UUID, on day: DayKey) {
        guard book.routines.contains(where: { $0.id == id }), !book.isDone(id, on: day) else { return }
        book.setDone(id, on: day)
        persist()
    }

    /// Makes the pending backup notifications match the routines, after any sync running.
    func syncBackups() {
        let previous = backupSync
        backupSync = Task {
            await previous?.value
            await RoutineBackups.sync(with: book)
        }
    }

    private func persist() {
        if !mustNotWrite {
            do {
                try RoutineFile.save(book, to: Self.fileURL)
                saveFailed = false
            } catch {
                saveFailed = true
            }
        }
        syncBackups()
        RoutineReminders.shared.recheck()
    }
}
