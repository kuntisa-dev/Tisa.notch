//
//  RoutineSettingsEditor.swift
//  TisaDynamicIsland
//
//  The routine editor for the Settings window: the same fields as the notch editor, with
//  room to read them.
//

import Defaults
import KhmerCalendarKit
import SwiftUI

struct RoutineSettingsEditor: View {
    let target: RoutineEditorTarget
    let onClose: () -> Void

    @Default(.khmerCalendarLatin) private var latin
    @State private var title: String
    @State private var time: Date
    @State private var weekdays: Set<Int>
    @State private var getReady: Int
    @State private var confirmDelete = false

    init(target: RoutineEditorTarget, onClose: @escaping () -> Void) {
        self.target = target
        self.onClose = onClose
        let routine = target.routine
        _title = State(initialValue: routine?.title ?? "")
        _weekdays = State(initialValue: routine?.weekdays ?? Set(1...7))
        _getReady = State(initialValue: RoutineDraft.initialGetReady(for: routine))
        _time = State(initialValue: RoutineDraft.initialTime(for: routine))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $title, prompt: Text("e.g. Run, Study English"))
                        .onChange(of: title) { _, new in
                            if new.count > Routine.maxTitleLength { title = String(new.prefix(Routine.maxTitleLength)) }
                        }
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                }

                Section {
                    Picker("Repeat", selection: presetBinding) {
                        ForEach(RoutineDraft.presets, id: \.name) { preset in
                            Text(preset.name).tag(preset.name)
                        }
                        Text("Custom").tag("Custom")
                    }
                    .pickerStyle(.segmented)
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { day in dayToggle(day) }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } header: {
                    Text("Days")
                } footer: {
                    Text(RoutineRepeatText.text(weekdays)).foregroundStyle(.secondary)
                }

                Section {
                    Picker("Get ready before", selection: $getReady) {
                        ForEach(Routine.getReadyChoices, id: \.self) { minutes in
                            Text(minutes == 0 ? "Off" : "\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(RoutineDraft.getReadyNote(time: time, getReady: getReady)).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                if let routine = target.routine {
                    Button(confirmDelete ? "Delete with its streak?" : "Delete", role: .destructive) {
                        if confirmDelete {
                            RoutineStore.shared.delete(id: routine.id)
                            onClose()
                        } else {
                            confirmDelete = true
                        }
                    }
                }
                Spacer()
                Button("Cancel", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    if RoutineDraft.save(existing: target.routine, title: title, time: time,
                                         weekdays: weekdays, getReady: getReady) {
                        onClose()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!RoutineDraft.canSave(title: title, weekdays: weekdays))
            }
            .padding(16)
        }
        .frame(width: 520, height: 470)
        .navigationTitle(target.routine == nil ? "New routine" : "Edit routine")
    }

    /// The quick choice that matches the days, or "Custom".
    private var presetBinding: Binding<String> {
        Binding {
            RoutineDraft.presets.first { $0.days == weekdays }?.name ?? "Custom"
        } set: { name in
            if let preset = RoutineDraft.presets.first(where: { $0.name == name }) { weekdays = preset.days }
        }
    }

    private func dayToggle(_ day: Int) -> some View {
        let on = weekdays.contains(day)
        let script: CalendarScript = latin ? .latin : .khmer
        let label = latin
            ? String(KhmerFormat.weekdayName(day, short: false, script: .latin).prefix(3))
            : KhmerFormat.weekdayName(day, short: true, script: script)
        return Button {
            // At least one day stays on.
            if on, weekdays.count > 1 { weekdays.remove(day) } else { weekdays.insert(day) }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 40, height: 28)
                .foregroundStyle(on ? Color.white : (day == 7 ? Color.red : Color.primary))
                .background(RoundedRectangle(cornerRadius: 7).fill(on ? (day == 7 ? Color.red : Color.accentColor) : Color.secondary.opacity(0.12)))
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(KhmerFormat.weekdayName(day, short: false, script: .latin))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
