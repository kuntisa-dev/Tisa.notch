//
//  DayNoteEditor.swift
//  TisaDynamicIsland
//
//  Write or change one note: a title, an optional time, and an optional alert at that time.
//  It takes the keyboard for the notch while it is open (see NotchTyping).
//

import KhmerCalendarKit
import SwiftUI

struct DayNoteEditor: View {
    let day: DayKey
    let editing: DayNote?
    let onClose: () -> Void

    @State private var title: String
    @State private var hasTime: Bool
    @State private var time: Date
    @State private var alert: Bool
    @State private var alertsDenied = false
    @FocusState private var titleFocused: Bool

    init(day: DayKey, editing: DayNote?, onClose: @escaping () -> Void) {
        self.day = day
        self.editing = editing
        self.onClose = onClose
        _title = State(initialValue: editing?.title ?? "")
        _hasTime = State(initialValue: editing?.time != nil)
        _alert = State(initialValue: editing?.alert ?? false)

        let calendar = Calendar.current
        var start = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        start = calendar.date(bySetting: .minute, value: 0, of: start) ?? start
        if let set = editing?.time {
            start = calendar.date(from: DateComponents(hour: set.hour, minute: set.minute)) ?? start
        }
        _time = State(initialValue: start)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeLabel(
                title: editing == nil ? "New note" : "Edit note",
                trailing: "\(KhmerFormat.numerals(day.day, script: .current)) \(KhmerFormat.solarMonthName(day.month, script: .current)) \(KhmerFormat.numerals(day.year, script: .current))"
            )

            TextField("Note", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Ink.rowFill))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                .focused($titleFocused)
                .onSubmit(save)
                .onChange(of: title) { _, new in
                    if new.count > DayNote.maxTitleLength { title = String(new.prefix(DayNote.maxTitleLength)) }
                }

            HStack(spacing: 8) {
                Toggle("Time", isOn: $hasTime)
                if hasTime {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.stepperField)
                        .controlSize(.small)
                        .fixedSize()
                }
                Spacer(minLength: 0)
                Toggle("Alert", isOn: $alert)
                    .disabled(!hasTime)
                    .help(hasTime ? "Show a notification at this time" : "Set a time first")
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .font(.system(size: 11))
            .foregroundStyle(Color(white: 0.9))

            if alertsDenied {
                HStack(spacing: 6) {
                    Text("Alerts are off in System Settings")
                        .font(.system(size: 9.5))
                        .foregroundStyle(HomeStyle.warning)
                        .lineLimit(1)
                    Button("Open") { DayNoteAlerts.openSystemSettings() }
                        .buttonStyle(.plain)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Color.effectiveAccent.mix(with: .white, by: 0.3))
                }
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
                if let editing {
                    Button("Delete") {
                        DayNoteStore.shared.delete(id: editing.id)
                        onClose()
                    }
                    .buttonStyle(HomePillButtonStyle(prominent: false, destructive: true))
                }
            }
        }
        .onExitCommand(perform: onClose)
        .onChange(of: hasTime) { _, on in
            if !on { alert = false }
        }
        .onChange(of: alert) { _, on in
            guard on else { return }
            Task {
                if await DayNoteAlerts.requestPermission() {
                    alertsDenied = false
                    // A note saved while macOS was still asking got no alert; schedule it now.
                    DayNoteStore.shared.syncAlerts()
                } else {
                    alert = false
                    alertsDenied = await DayNoteAlerts.isDenied()
                }
            }
        }
        .onAppear {
            NotchTyping.begin()
            // Focus after the window has become key, or the field stays without a cursor.
            DispatchQueue.main.async { titleFocused = true }
        }
        .onDisappear { NotchTyping.end() }
    }

    private func save() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let chosen = hasTime ? (hour: parts.hour ?? 0, minute: parts.minute ?? 0) : nil
        guard let note = DayNote.make(
            id: editing?.id ?? UUID(), day: day, title: title, time: chosen, alert: alert,
            createdAt: editing?.createdAt ?? Date()
        ) else { return }
        DayNoteStore.shared.save(note)
        onClose()
    }
}
