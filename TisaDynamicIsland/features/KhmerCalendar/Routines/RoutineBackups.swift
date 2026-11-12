//
//  RoutineBackups.swift
//  TisaDynamicIsland
//
//  The macOS notifications that back up the notch: each fires one minute after a routine
//  reminder, and the app takes it away as soon as the notch has shown that reminder. If the
//  app is closed or the Mac was asleep, the notification still arrives.
//

import Defaults
import Foundation
import KhmerCalendarKit
@preconcurrency import UserNotifications

@MainActor
enum RoutineBackups {
    nonisolated static let category = "ROUTINE"
    nonisolated static let doneAction = "DONE"
    nonisolated static let snoozeAction = "SNOOZE"
    nonisolated static let snoozeSuffix = "-snooze"

    static func registerCategory() {
        let center = UNUserNotificationCenter.current()
        let done = UNNotificationAction(identifier: doneAction, title: "Done", options: [])
        let snooze = UNNotificationAction(identifier: snoozeAction, title: "Snooze 10 min", options: [])
        let routine = UNNotificationCategory(identifier: category, actions: [done, snooze], intentIdentifiers: [])
        Task {
            let others = await center.notificationCategories().filter { $0.identifier != category }
            center.setNotificationCategories(others.union([routine]))
        }
    }

    /// Makes the pending `routine-` notifications match the routines. Never asks for permission.
    static func sync(with book: RoutineBook) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(RoutinePlan.identifierPrefix) && !$0.hasSuffix(snoozeSuffix) }

        guard Defaults[.routineBackupNotification], Defaults[.routineReminders], await isAllowed() else {
            center.removePendingNotificationRequests(withIdentifiers: pending)
            return
        }

        let wanted = RoutinePlan.backups(book: book, now: Date(), calendar: .current,
                                         excluding: RoutineReminders.shared.noBackupNeeded)
        let wantedIDs = Set(wanted.map(\.id))
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { !wantedIDs.contains($0) })
        let today = DayKey(Date(), calendar: .current)
        // Added again every time: a request with the same id replaces the old one, so a
        // routine whose time changed gets its new time.
        for occurrence in wanted {
            guard let routine = book.routines.first(where: { $0.id == occurrence.routineID }) else { continue }
            let body = text(for: occurrence, routine: routine, streak: book.streak(of: routine, today: today))
            try? await center.add(request(id: occurrence.id, title: routine.title, body: body,
                                          at: occurrence.fireDate.addingTimeInterval(RoutinePlan.backupDelay)))
        }
    }

    /// Takes away pending and already shown notifications, including snoozed copies.
    static func remove(ids: [String]) {
        let all = ids + ids.map { $0 + snoozeSuffix }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: all)
        center.removeDeliveredNotifications(withIdentifiers: all)
    }

    /// A one-off copy of a snoozed reminder, shown at `date` + the backup delay if the notch
    /// cannot show it then.
    static func scheduleSnooze(_ occurrence: RoutineOccurrence, routine: Routine, at date: Date) async {
        guard Defaults[.routineBackupNotification], await isAllowed() else { return }
        let body = text(for: occurrence, routine: routine, streak: nil)
        try? await UNUserNotificationCenter.current().add(
            request(id: occurrence.id + snoozeSuffix, title: routine.title, body: body,
                    at: date.addingTimeInterval(RoutinePlan.backupDelay)))
    }

    /// Asks macOS once; afterwards answers from the saved choice.
    @discardableResult
    static func requestPermissionIfNeeded() async -> Bool {
        if await isAllowed() { return true }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        if granted { RoutineStore.shared.syncBackups() }
        return granted
    }

    static func isAllowed() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    /// "05:30", in this Mac's time style.
    static func timeText(_ routine: Routine) -> String {
        guard let date = Calendar.current.date(from: DateComponents(hour: routine.hour, minute: routine.minute))
        else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private static func text(for occurrence: RoutineOccurrence, routine: Routine, streak: Int?) -> String {
        switch occurrence.kind {
        case .getReady:
            return "Get ready · \(timeText(routine))"
        case .due:
            if let streak, streak > 0 { return "Now · \(timeText(routine)) · 🔥 \(streak)" }
            return "Now · \(timeText(routine))"
        }
    }

    private static func request(id: String, title: String, body: String, at date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.threadIdentifier = "routines"
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return UNNotificationRequest(identifier: id, content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
    }
}
