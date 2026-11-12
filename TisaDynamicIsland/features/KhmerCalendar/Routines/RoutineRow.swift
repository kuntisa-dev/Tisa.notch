//
//  RoutineRow.swift
//  TisaDynamicIsland
//
//  One routine on the picked day: a tick circle, its time and name, the days it repeats and
//  its streak. Today and yesterday can be ticked; tapping the rest opens the editor.
//

import KhmerCalendarKit
import SwiftUI

struct RoutineRow: View {
    let routine: Routine
    let day: DayKey
    let today: DayKey
    let onEdit: () -> Void

    @ObservedObject private var store = RoutineStore.shared

    var body: some View {
        let status = store.book.status(of: routine, on: day, today: today)
        let done = status == .done
        let canTick = RoutineBook.canTick(day, today: today)
        let streak = store.book.streak(of: routine, today: today)

        HStack(spacing: 6) {
            Button {
                store.toggleDone(routine.id, on: day)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(done ? KhmerCalendarStyle.done : tickRing(status), lineWidth: 1.3)
                        .background(Circle().fill(done ? KhmerCalendarStyle.done : Color.clear))
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7.5, weight: .heavy))
                            .foregroundStyle(Color(red: 0.02, green: 0.13, blue: 0.17))
                    }
                }
                .frame(width: 14, height: 14)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canTick)
            .help(canTick ? (done ? "Mark not done" : "Mark done") : "Only today and yesterday can be ticked")
            .accessibilityLabel(done ? "Mark \(routine.title) not done" : "Mark \(routine.title) done")

            Button(action: onEdit) {
                HStack(spacing: 6) {
                    Text(RoutineBackups.timeText(routine))
                        .inkColor(HomeStyle.secondary, Ink.reset)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .leading)
                    Text(routine.title)
                        .fontWeight(.medium)
                        .strikethrough(done)
                        .opacity(done ? 0.6 : 1)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(RoutineRepeatText.text(routine.weekdays))
                        .font(.system(size: 9))
                        .inkColor(HomeStyle.secondary, Ink.detail)
                        .lineLimit(1)
                    if streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                            Text("\(streak)")
                        }
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(RoutinePopout.readyColor)
                        .accessibilityLabel("\(streak) day streak")
                    }
                }
                .font(.system(size: 11))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Edit routine")
        }
        .padding(.horizontal, 5)
        .frame(height: 20)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Ink.rowFill))
    }

    /// A missed day gets an orange ring, so it reads differently from one still to do.
    private func tickRing(_ status: RoutineStatus) -> Color {
        status == .missed ? KhmerCalendarStyle.missed : Color.white.opacity(0.45)
    }
}
