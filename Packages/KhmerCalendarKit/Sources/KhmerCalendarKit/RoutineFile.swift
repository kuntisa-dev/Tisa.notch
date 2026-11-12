//
//  RoutineFile.swift
//  KhmerCalendarKit
//
//  Reads and writes routines.json, with the same safety as notes.json: a file that cannot be
//  read is moved aside, never overwritten.
//

import Foundation

public enum RoutineFile {
    public static let version = 1

    public enum LoadResult {
        case loaded(RoutineBook)
        case missing
        /// The file was renamed to `movedTo` and a new one should be started.
        case unreadable(movedTo: URL)
        /// The file could not be read or moved aside. Nothing may be saved over it.
        case unreadableInPlace
    }

    private struct Contents: Codable {
        var version: Int
        var routines: [Routine]
        /// Routine id → the days it was done, in order.
        var done: [String: [String]]
    }

    public static func load(from url: URL, now: Date = Date()) -> LoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: url),
           let contents = try? decoder.decode(Contents.self, from: data),
           contents.version == version {
            var done: [UUID: Set<String>] = [:]
            for (key, days) in contents.done {
                if let id = UUID(uuidString: key) { done[id] = Set(days) }
            }
            return .loaded(RoutineBook(routines: contents.routines, done: done))
        }

        guard let aside = AsideFile.move(url, now: now) else { return .unreadableInPlace }
        return .unreadable(movedTo: aside)
    }

    public static func save(_ book: RoutineBook, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let done = Dictionary(uniqueKeysWithValues: book.done.map { ($0.key.uuidString, $0.value.sorted()) })
        let data = try encoder.encode(Contents(version: version, routines: book.routines, done: done))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
