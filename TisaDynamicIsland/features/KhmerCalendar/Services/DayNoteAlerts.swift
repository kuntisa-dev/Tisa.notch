//
//  DayNoteAlerts.swift
//  TisaDynamicIsland
//
//  macOS notifications for notes that have a time and Alert turned on. KhmerCalendarKit
//  decides which alerts should exist; this applies that to the notification center.
//

import AppKit
import Foundation
import KhmerCalendarKit
import UserNotifications

@MainActor
enum DayNoteAlerts {
    /// Makes the pending notifications match the notes. Never asks for permission.
    static func sync(with book: DayNoteBook) async {
        let center = UNUserNotificationCenter.current()
        let pending = Set(await center.pendingNotificationRequests().map(\.identifier))
        let change = DayNoteAlertPlan.change(book: book, pending: pending, now: Date(), calendar: .current)
        center.removePendingNotificationRequests(withIdentifiers: change.remove)

        guard !change.schedule.isEmpty, await isAllowed() else { return }
        for note in change.schedule {
            guard let day = DayKey(note.day), let time = note.time else { continue }
            let content = UNMutableNotificationContent()
            content.title = note.title
            content.body = KhmerFormat.lunarLine(KhmerCalendar.date(day), script: .current)
            content.sound = .default
            let when = DateComponents(year: day.year, month: day.month, day: day.day, hour: time.hour, minute: time.minute)
            // Adding a request with an identifier that is already pending replaces it.
            let request = UNNotificationRequest(
                identifier: DayNoteAlertPlan.identifier(for: note.id),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            )
            try? await center.add(request)
        }
    }

    /// Asks macOS for permission the first time; afterwards answers from the saved choice.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        if await isAllowed() { return true }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    private static func isAllowed() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
