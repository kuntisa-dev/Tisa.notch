//
//  NotificationRouter.swift
//  TisaDynamicIsland
//
//  macOS has one notification delegate per app. This one handles the routine buttons
//  (Done, Snooze) and hands everything else to whoever was the delegate before it, such
//  as AI Usage.
//

import Foundation
import KhmerCalendarKit
@preconcurrency import UserNotifications

enum RoutineAction {
    case done, snooze, open
}

@MainActor
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    /// Set by RoutineReminders. Receives an occurrence id without any snooze suffix.
    var onRoutineAction: ((_ occurrenceID: String, _ action: RoutineAction) -> Void)?

    private weak var previous: UNUserNotificationCenterDelegate?

    /// Call from applicationDidFinishLaunching, so a button that launched the app still arrives.
    /// Safe to call again: AI Usage may make itself the delegate when it starts later.
    func install() {
        let center = UNUserNotificationCenter.current()
        guard center.delegate !== self else { return }
        previous = center.delegate
        center.delegate = self
        RoutineBackups.registerCategory()
    }

    /// Show banners even while this app is in front: a notch app nearly always is.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request
        guard request.content.categoryIdentifier == "ROUTINE" else {
            Task { @MainActor in
                if let previous = self.previous, previous.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
                    previous.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
                } else {
                    completionHandler()
                }
            }
            return
        }

        var id = request.identifier
        if id.hasSuffix("-snooze") { id = String(id.dropLast("-snooze".count)) }
        let action: RoutineAction
        switch response.actionIdentifier {
        case "DONE": action = .done
        case "SNOOZE": action = .snooze
        default: action = .open
        }
        Task { @MainActor in
            self.onRoutineAction?(id, action)
            completionHandler()
        }
    }
}
