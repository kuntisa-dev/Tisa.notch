//
//  DayNoteFile.swift
//  KhmerCalendarKit
//
//  Reads and writes notes.json. A file that cannot be read is moved aside, never
//  overwritten, so the notes in it can still be recovered by hand.
//

import Foundation

public enum DayNoteFile {
    public static let version = 1

    public enum LoadResult {
        case loaded(DayNoteBook)
        case missing
        /// The file was renamed to `movedTo` and a new one should be started.
        case unreadable(movedTo: URL)
        /// The file could not be read or moved aside. Nothing may be saved over it.
        case unreadableInPlace
    }

    private struct Contents: Codable {
        var version: Int
        var notes: [DayNote]
    }

    public static func load(from url: URL, now: Date = Date()) -> LoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: url),
           let contents = try? decoder.decode(Contents.self, from: data),
           contents.version == version {
            return .loaded(DayNoteBook(notes: contents.notes))
        }

        guard let aside = AsideFile.move(url, now: now) else { return .unreadableInPlace }
        return .unreadable(movedTo: aside)
    }

    public static func save(_ book: DayNoteBook, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Contents(version: version, notes: book.notes))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
