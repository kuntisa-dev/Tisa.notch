//
//  DayNoteStore.swift
//  TisaDynamicIsland
//
//  The notes written on the Khmer calendar. They live in one file on this Mac:
//  Application Support › Tisa Dynamic Island › Calendar › notes.json.
//

import Foundation
import KhmerCalendarKit

@MainActor
final class DayNoteStore: ObservableObject {
    static let shared = DayNoteStore()

    @Published private(set) var book = DayNoteBook()
    /// True when the last change could not be written; the note is still shown until the app quits.
    @Published private(set) var saveFailed = false

    /// Set when notes.json could not be read or moved aside, so saving would destroy it.
    private var mustNotWrite = false
    /// The last alert sync. Each one waits for the one before, so an older list of notes
    /// can never re-add an alert that a newer one took away.
    private var alertSync: Task<Void, Never>?

    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Tisa Dynamic Island/Calendar/notes.json")
    }

    private init() {
        switch DayNoteFile.load(from: Self.fileURL) {
        case .loaded(let book):
            self.book = book
        case .missing:
            break
        case .unreadable(let movedTo):
            // The old file is kept under its new name; a fresh one starts with the next note.
            NSLog("Khmer calendar: notes.json could not be read and was kept as %@", movedTo.lastPathComponent)
        case .unreadableInPlace:
            // New notes are shown but not written, so the file is left as it is.
            NSLog("Khmer calendar: notes.json could not be read or moved; notes will not be saved")
            mustNotWrite = true
            saveFailed = true
        }
    }

    func save(_ note: DayNote) {
        book.upsert(note)
        persist()
    }

    func delete(id: UUID) {
        book.remove(id: id)
        persist()
    }

    /// Makes the pending macOS alerts match the notes, after any sync already running.
    func syncAlerts() {
        let previous = alertSync
        alertSync = Task {
            await previous?.value
            await DayNoteAlerts.sync(with: book)
        }
    }

    private func persist() {
        if !mustNotWrite {
            do {
                try DayNoteFile.save(book, to: Self.fileURL)
                saveFailed = false
            } catch {
                saveFailed = true
            }
        }
        syncAlerts()
    }
}
