//
//  AsideFile.swift
//  KhmerCalendarKit
//
//  Moves a file that cannot be read out of the way, under a new name, so the app can start
//  a fresh one without destroying what was there.
//

import Foundation

enum AsideFile {
    /// The new location, or nil when the file could not be moved.
    static func move(_ url: URL, now: Date) -> URL? {
        let aside = asideURL(for: url, now: now)
        do {
            try FileManager.default.moveItem(at: url, to: aside)
            return aside
        } catch {
            return nil
        }
    }

    /// notes-unreadable-20261111-013000.json, with -2, -3... if that name is taken.
    private static func asideURL(for url: URL, now: Date) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let folder = url.deletingLastPathComponent()
        let base = "\(url.deletingPathExtension().lastPathComponent)-unreadable-\(formatter.string(from: now))"

        var candidate = folder.appendingPathComponent("\(base).json")
        var count = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base)-\(count).json")
            count += 1
        }
        return candidate
    }
}
