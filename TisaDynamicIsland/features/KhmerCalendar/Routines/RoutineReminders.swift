//
//  RoutineReminders.swift
//  TisaDynamicIsland
//
//  The clock behind routine reminders. Each minute (and on wake, a new day, or any change)
//  it asks KhmerCalendarKit which reminders are due, drops the notch down for the first one
//  and keeps the notch open until every due reminder has been answered.
//

import AppKit
import Combine
import Defaults
import KhmerCalendarKit

@MainActor
final class RoutineReminders: ObservableObject {
    static let shared = RoutineReminders()

    enum Answer {
        case done, snooze, ok
    }

    /// The reminders waiting in the notch, oldest first.
    @Published private(set) var queue: [RoutineOccurrence] = []

    var current: RoutineOccurrence? { queue.first }
    var count: Int { queue.count }

    /// Answered or replaced in this run of the app. A relaunch may show one again within
    /// the catch-up window, which is acceptable.
    private var handled: Set<String> = []
    private var snoozedUntil: [String: Date] = [:]
    /// Shown in the notch at least once in this run.
    private var shown: Set<String> = []

    /// Reminders that need no backup notification: shown, answered or snoozed (a snoozed
    /// one has its own copy).
    var noBackupNeeded: Set<String> {
        shown.union(handled).union(snoozedUntil.keys)
    }
    /// Whether this holds the notch open through SharingStateManager.
    private var holdsNotch = false
    private weak var shownOn: TisaViewModel?
    private var clock: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var settingsWatch: AnyCancellable?

    private init() {}

    func start() {
        guard clock == nil else { return }
        NotificationRouter.shared.onRoutineAction = { [weak self] id, action in
            switch action {
            case .done: self?.answer(id: id, .done)
            case .snooze: self?.answer(id: id, .snooze)
            case .open: self?.recheck()
            }
        }
        clock = Task { [weak self] in
            while !Task.isCancelled {
                let now = Date().timeIntervalSince1970
                let next = (now / 60).rounded(.down) * 60 + 60.5
                try? await Task.sleep(for: .seconds(next - now))
                self?.recheck()
            }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in RoutineReminders.shared.recheck() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { _ in
            Task { @MainActor in
                RoutineStore.shared.syncBackups()
                RoutineReminders.shared.recheck()
            }
        })
        settingsWatch = Defaults.publisher(.routineReminders, options: []).sink { _ in
            Task { @MainActor in
                RoutineStore.shared.syncBackups()
                RoutineReminders.shared.recheck()
            }
        }
        recheck()
    }

    func recheck() {
        NotificationRouter.shared.install()
        let now = Date()
        snoozedUntil = snoozedUntil.filter { $0.value > now.addingTimeInterval(-RoutinePlan.catchUp) }

        let found = Defaults[.routineReminders]
            ? RoutinePlan.dueNow(book: RoutineStore.shared.book, now: now, calendar: .current,
                                 handled: handled, snoozedUntil: snoozedUntil)
            : []
        if found != queue { queue = found }

        guard let head = found.first else {
            release()
            return
        }
        // The notch is showing it, so the backup notification is not needed.
        shown.insert(head.id)
        RoutineBackups.remove(ids: [head.id])
        if !holdsNotch {
            holdsNotch = true
            SharingStateManager.shared.beginInteraction()
        }
        // Also after the notch window was replaced (screens changed) or closed some other way.
        if shownOn?.notchState != .open, let app = NSApp.delegate as? AppDelegate {
            shownOn = app.openNotchUnderMouse()
        }
    }

    func answer(id: String, _ answer: Answer) {
        guard let parts = RoutinePlan.occurrenceID(parsing: id) else { return }
        let dayIDs = [RoutineOccurrence.Kind.getReady, .due].map {
            "\(RoutinePlan.identifierPrefix)\(parts.routineID.uuidString)-\(parts.day.string)-\($0.rawValue)"
        }
        switch answer {
        case .done:
            handled.formUnion(dayIDs)
            RoutineBackups.remove(ids: dayIDs)
            RoutineStore.shared.markDone(parts.routineID, on: parts.day)
        case .ok:
            handled.insert(id)
            RoutineBackups.remove(ids: [id])
        case .snooze:
            let until = Date().addingTimeInterval(RoutinePlan.snooze)
            snoozedUntil[id] = until
            RoutineBackups.remove(ids: [id])
            if let routine = RoutineStore.shared.book.routines.first(where: { $0.id == parts.routineID }),
               let occurrence = queue.first(where: { $0.id == id })
                ?? RoutinePlan.occurrences(of: routine, on: parts.day, calendar: .current).first(where: { $0.id == id }) {
                Task { await RoutineBackups.scheduleSnooze(occurrence, routine: routine, at: until) }
            }
        }
        recheck()
    }

    /// Lets the notch close again once nothing is waiting.
    private func release() {
        guard holdsNotch else { return }
        holdsNotch = false
        shownOn = nil
        // Reaching zero lets the notch close, as after sharing.
        SharingStateManager.shared.endInteraction()
    }
}
