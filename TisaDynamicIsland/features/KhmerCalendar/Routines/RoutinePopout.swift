//
//  RoutinePopout.swift
//  TisaDynamicIsland
//
//  What the open notch shows while a routine reminder waits: "get ready" before the time,
//  then the routine itself with Done and Snooze. It covers the tab until answered.
//

import KhmerCalendarKit
import SwiftUI

struct RoutinePopout: View {
    @ObservedObject private var reminders = RoutineReminders.shared
    @ObservedObject private var store = RoutineStore.shared

    static let readyColor = Color(red: 1.0, green: 0.70, blue: 0.28)    // #FFB347
    static let dueColor = Color(red: 0.56, green: 0.88, blue: 1.0)      // #8FE0FF

    var body: some View {
        if let occurrence = reminders.current,
           let routine = store.book.routines.first(where: { $0.id == occurrence.routineID }) {
            content(occurrence, routine)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .homeCard(highlight: occurrence.kind == .due ? Self.dueColor : Self.readyColor)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        }
    }

    private func content(_ occurrence: RoutineOccurrence, _ routine: Routine) -> some View {
        let isDue = occurrence.kind == .due
        let tint = isDue ? Self.dueColor : Self.readyColor
        let streak = store.book.streak(of: routine, today: DayKey(Date(), calendar: .current))
        return HStack(spacing: 14) {
            Image(systemName: isDue ? "alarm" : "hourglass")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.16)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.5), lineWidth: 1))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(kicker(occurrence, routine))
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(tint)
                    if reminders.count > 1 {
                        Text("1 of \(reminders.count)")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                            .foregroundStyle(Color(white: 0.85))
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(routine.title)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .ink(Color.white, Ink.title)
                    if !isDue {
                        Text(RoutineBackups.timeText(routine))
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .inkColor(HomeStyle.secondary, Ink.time)
                    }
                }
                if isDue {
                    HStack(spacing: 5) {
                        Text(RoutineRepeatText.text(routine.weekdays))
                            .inkColor(HomeStyle.secondary, Ink.time)
                        if streak > 0 {
                            Image(systemName: "flame.fill").foregroundStyle(Self.readyColor)
                            Text("\(streak) \(streak == 1 ? "day" : "days")")
                                .fontWeight(.bold)
                                .foregroundStyle(Self.readyColor)
                        }
                    }
                    .font(.system(size: 11))
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                if isDue {
                    Button { reminders.answer(id: occurrence.id, .done) } label: {
                        Label("Done", systemImage: "checkmark")
                    }
                    .buttonStyle(HomePillButtonStyle(prominent: true))
                    Button("Snooze 10 min") { reminders.answer(id: occurrence.id, .snooze) }
                        .buttonStyle(HomePillButtonStyle(prominent: false))
                } else {
                    Button("OK") { reminders.answer(id: occurrence.id, .ok) }
                        .buttonStyle(HomePillButtonStyle(prominent: true))
                    Button("Done early") { reminders.answer(id: occurrence.id, .done) }
                        .buttonStyle(HomePillButtonStyle(prominent: false))
                }
            }
            .controlSize(.large)
        }
    }

    /// "GET READY · IN 30 MIN" or "05:30 · NOW" ("05:30 · 40 MIN AGO" after a sleep).
    private func kicker(_ occurrence: RoutineOccurrence, _ routine: Routine) -> String {
        let late = Int(Date().timeIntervalSince(occurrence.fireDate) / 60)
        switch occurrence.kind {
        case .getReady:
            let left = max(0, routine.getReadyMinutes - late)
            return left > 0 ? "GET READY · IN \(left) MIN" : "GET READY · NOW"
        case .due:
            let time = RoutineBackups.timeText(routine).uppercased()
            return late >= 2 ? "\(time) · \(late) MIN AGO" : "\(time) · NOW"
        }
    }
}
