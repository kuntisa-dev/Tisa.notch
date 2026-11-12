//
//  HomeFeeds.swift
//  TisaDynamicIsland
//
//  Data for Home's boxes and the Calendar and Downloads tabs: today's events and
//  reminders, and the newest files in ~/Downloads. Each refreshes only while a
//  view that shows it is on screen.
//

import AppKit
import Combine
import Darwin
import EventKit

// MARK: - Today

@MainActor
final class TodayFeed: ObservableObject {
    static let shared = TodayFeed()

    /// Timed events from now until the end of tomorrow, soonest first.
    @Published private(set) var upcoming: [EventModel] = []
    /// Everything on today's calendar, all-day events first.
    @Published private(set) var today: [EventModel] = []
    /// Open reminders due today or earlier.
    @Published private(set) var reminders: [EventModel] = []
    @Published private(set) var hasAccess = EKEventStore.authorizationStatus(for: .event) == .fullAccess

    private var viewers = 0
    private var loop: Task<Void, Never>?
    private var storeObserver: NSObjectProtocol?

    private init() {}

    func begin() {
        viewers += 1
        guard viewers == 1 else { return }
        storeObserver = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        loop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func end() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        loop?.cancel()
        loop = nil
        if let storeObserver { NotificationCenter.default.removeObserver(storeObserver) }
        storeObserver = nil
    }

    func requestAccess() {
        Task { @MainActor in
            await CalendarManager.shared.checkCalendarAuthorization()
            await refresh()
        }
    }

    func complete(_ reminder: EventModel) {
        Task { @MainActor in
            await CalendarManager.shared.setReminderCompleted(reminderID: reminder.id, completed: true)
            await refresh()
        }
    }

    func refresh() async {
        hasAccess = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        guard hasAccess else {
            upcoming = []
            today = []
            reminders = []
            return
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: start),
              let end = calendar.date(byAdding: .day, value: 2, to: start) else { return }
        let all = await CalendarManager.shared.events(from: start, to: end)
        let now = Date()

        upcoming = all
            .filter { $0.type.isEvent && !$0.isAllDay && $0.end > now }
            .sorted { $0.start < $1.start }
        today = all
            .filter { !$0.type.isReminder && $0.start < tomorrow }
            .sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
        reminders = all
            .filter {
                if case .reminder(let completed) = $0.type { return !completed && $0.start < tomorrow }
                return false
            }
            .sorted { $0.start < $1.start }
    }
}

extension EventModel {
    /// The video-call link: the event's URL, or the first meeting link in its location or notes.
    var meetingURL: URL? {
        if let url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            return url
        }
        let hosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com",
                     "whereby.com", "facetime.apple.com", "meet.jit.si"]
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for text in [location, notes].compactMap({ $0 }) {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                if let url = match.url, let host = url.host?.lowercased(),
                   hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
                    return url
                }
            }
        }
        return nil
    }
}

// MARK: - Downloads folder

struct DownloadedFile: Identifiable, Equatable {
    let url: URL
    let name: String
    let added: Date
    let size: Int64

    var id: URL { url }
}

@MainActor
final class DownloadsFolderFeed: ObservableObject {
    static let shared = DownloadsFolderFeed()

    @Published private(set) var files: [DownloadedFile] = []

    /// The real ~/Downloads (inside the sandbox FileManager's home is the app container).
    let folder: URL = {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir)).appendingPathComponent("Downloads", isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
    }()

    nonisolated private static let partialExtensions: Set<String> = ["download", "crdownload", "part", "partial"]

    private init() {}

    func refresh() {
        let folder = folder
        Task.detached(priority: .utility) {
            let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .contentModificationDateKey, .fileSizeKey, .isDirectoryKey]
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
            let found: [DownloadedFile] = urls.compactMap { url in
                guard !Self.partialExtensions.contains(url.pathExtension.lowercased()),
                      let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
                let added = values.addedToDirectoryDate ?? values.contentModificationDate ?? .distantPast
                return DownloadedFile(url: url, name: url.lastPathComponent, added: added,
                                      size: Int64(values.fileSize ?? 0))
            }
            let newest = Array(found.sorted { $0.added > $1.added }.prefix(24))
            await MainActor.run {
                DownloadsFolderFeed.shared.files = newest
            }
        }
    }
}
