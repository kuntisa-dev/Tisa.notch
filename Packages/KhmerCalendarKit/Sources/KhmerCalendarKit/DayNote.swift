//
//  DayNote.swift
//  KhmerCalendarKit
//
//  A note the user wrote on a day, and the set of all notes.
//

import Foundation

public struct DayNote: Identifiable, Codable, Equatable, Sendable {
    public static let maxTitleLength = 200

    public let id: UUID
    /// "2026-11-11": the calendar day, with no time zone.
    public var day: String
    public var title: String
    /// Both nil, or both set.
    public var hour: Int?
    public var minute: Int?
    /// Only true when a time is set.
    public var alert: Bool
    public var createdAt: Date

    /// Nil when the title is empty or the time is not a real time. The title is trimmed and
    /// cut to 200 characters; an alert without a time is dropped.
    public static func make(id: UUID = UUID(), day: DayKey, title: String, time: (hour: Int, minute: Int)?,
                            alert: Bool, createdAt: Date = Date()) -> DayNote? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let time {
            guard (0...23).contains(time.hour), (0...59).contains(time.minute) else { return nil }
        }
        return DayNote(id: id, day: day.string, title: String(trimmed.prefix(maxTitleLength)),
                       hour: time?.hour, minute: time?.minute, alert: alert && time != nil, createdAt: createdAt)
    }

    public var time: (hour: Int, minute: Int)? {
        guard let hour, let minute else { return nil }
        return (hour, minute)
    }
}

public struct DayNoteBook: Equatable, Sendable {
    public private(set) var notes: [DayNote]

    public init(notes: [DayNote] = []) {
        self.notes = notes
    }

    /// A day's notes: those with a time first, in time order, then the rest in the order written.
    public func notes(on day: DayKey) -> [DayNote] {
        notes.filter { $0.day == day.string }.sorted { a, b in
            switch (a.time, b.time) {
            case let (x?, y?):
                return (x.hour, x.minute, a.createdAt) < (y.hour, y.minute, b.createdAt)
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return a.createdAt < b.createdAt
            }
        }
    }

    public var daysWithNotes: Set<String> {
        Set(notes.map(\.day))
    }

    public mutating func upsert(_ note: DayNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
    }

    public mutating func remove(id: UUID) {
        notes.removeAll { $0.id == id }
    }
}
