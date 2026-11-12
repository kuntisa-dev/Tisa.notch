//
//  RoutineEditor.swift
//  TisaDynamicIsland
//
//  Make or change a routine: its name, time, the days it repeats and how long before it
//  the get-ready reminder comes. It covers the Calendar tab and takes the keyboard while
//  open (see NotchTyping).
//

import Defaults
import KhmerCalendarKit
import SwiftUI

struct RoutineEditor: View {
    let target: RoutineEditorTarget
    let onClose: () -> Void

    @State private var title: String
    @State private var time: Date
    @State private var weekdays: Set<Int>
    @State private var getReady: Int
    @State private var confirmDelete = false
    @FocusState private var titleFocused: Bool

    init(target: RoutineEditorTarget, onClose: @escaping () -> Void) {
        self.target = target
        self.onClose = onClose
        let routine = target.routine
        _title = State(initialValue: routine?.title ?? "")
        _weekdays = State(initialValue: routine?.weekdays ?? Set(1...7))
        _getReady = State(initialValue: RoutineDraft.initialGetReady(for: routine))
        _time = State(initialValue: RoutineDraft.initialTime(for: routine))
    }

    private var canSave: Bool {
        RoutineDraft.canSave(title: title, weekdays: weekdays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                fieldLabel(target.routine == nil ? "NEW ROUTINE" : "EDIT ROUTINE")
                TextField("Name, e.g. Run", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Ink.rowFill))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(RoutinePopout.dueColor.opacity(titleFocused ? 0.7 : 0.25), lineWidth: 1))
                    .focused($titleFocused)
                    .onSubmit(save)
                    .onChange(of: title) { _, new in
                        if new.count > Routine.maxTitleLength { title = String(new.prefix(Routine.maxTitleLength)) }
                    }
            }

            HStack(spacing: 10) {
                fieldLabel("TIME")
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.stepperField)
                    .controlSize(.small)
                    .fixedSize()
                capsuleChoices(RoutineDraft.presets.map { preset in
                    (preset.name, weekdays == preset.days, { weekdays = preset.days })
                }, tint: .white)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    ForEach(1...7, id: \.self) { day in dayToggle(day) }
                }
            }

            HStack(spacing: 10) {
                fieldLabel("GET READY")
                capsuleChoices(Routine.getReadyChoices.map { minutes in
                    (minutes == 0 ? "Off" : "\(minutes) min", getReady == minutes, { getReady = minutes })
                }, tint: RoutinePopout.readyColor)
                Text(RoutineDraft.getReadyNote(time: time, getReady: getReady))
                    .font(.system(size: 10.5))
                    .inkColor(HomeStyle.secondary, Ink.detail)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Button("Save", action: save)
                    .buttonStyle(HomePillButtonStyle(prominent: true))
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
                Button("Cancel", action: onClose)
                    .buttonStyle(HomePillButtonStyle(prominent: false))
                Spacer(minLength: 0)
                if let routine = target.routine {
                    Button(confirmDelete ? "Delete with its streak?" : "Delete") {
                        if confirmDelete {
                            RoutineStore.shared.delete(id: routine.id)
                            onClose()
                        } else {
                            confirmDelete = true
                        }
                    }
                    .buttonStyle(HomePillButtonStyle(prominent: false, destructive: true))
                }
            }
        }
        .onExitCommand(perform: onClose)
        .onAppear {
            NotchTyping.begin()
            // Focus after the window has become key, or the field stays without a cursor.
            DispatchQueue.main.async { titleFocused = true }
        }
        .onDisappear { NotchTyping.end() }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .inkColor(HomeStyle.secondary, Ink.detail)
            .lineLimit(1)
            .fixedSize()
            .frame(width: 86, alignment: .leading)
    }

    private func capsuleChoices(_ choices: [(String, Bool, () -> Void)], tint: Color) -> some View {
        HStack(spacing: 2) {
            ForEach(choices.indices, id: \.self) { index in
                let (label, on, pick) = choices[index]
                Button(action: pick) {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(on ? Color.black : Color(white: 0.9))
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(Capsule().fill(on ? tint : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(Ink.rowFill))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        .fixedSize()
    }

    private func dayToggle(_ day: Int) -> some View {
        let on = weekdays.contains(day)
        let sunday = day == 7
        return Button {
            // At least one day stays on.
            if on, weekdays.count > 1 { weekdays.remove(day) } else { weekdays.insert(day) }
        } label: {
            Text(KhmerFormat.weekdayName(day, short: true, script: .current))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(on ? Color.black : (sunday ? KhmerCalendarStyle.red : Color(white: 0.85)))
                .frame(width: 21, height: 21)
                .background(Circle().fill(on ? (sunday ? KhmerCalendarStyle.red : RoutinePopout.dueColor) : Color.clear))
                .overlay(Circle().strokeBorder(on ? Color.clear : Color.white.opacity(0.25), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(KhmerFormat.weekdayName(day, short: false))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func save() {
        if RoutineDraft.save(existing: target.routine, title: title, time: time, weekdays: weekdays, getReady: getReady) {
            onClose()
        }
    }
}
