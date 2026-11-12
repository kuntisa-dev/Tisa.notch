//
//  KhmerCalendarSettings.swift
//  TisaDynamicIsland
//
//  Settings › Khmer Calendar: what the Calendar tab shows, your notes and their alerts.
//

import Defaults
import KhmerCalendarKit
import SwiftUI
import UserNotifications

extension CalendarScript {
    /// The letters the user picked in Settings › Khmer Calendar.
    static var current: CalendarScript { Defaults[.khmerCalendarLatin] ? .latin : .khmer }
}

extension Defaults.Keys {
    /// The lunar day beside each date in the month (២កើត).
    static let khmerShowLunarDay = Key<Bool>("khmerShowLunarDay", default: true)
    /// Holidays in red, with their names on the day.
    static let khmerShowHolidays = Key<Bool>("khmerShowHolidays", default: true)
    /// The small moon on ថ្ងៃសីល.
    static let khmerShowHolyDays = Key<Bool>("khmerShowHolyDays", default: true)
    /// Apple Calendar events above your notes.
    static let khmerShowEvents = Key<Bool>("khmerShowEvents", default: true)
    /// Write the Khmer calendar in English letters and ordinary numbers.
    static let khmerCalendarLatin = Key<Bool>("khmerCalendarLatin", default: false)
    /// The notch drops down when a routine is due. Off pauses every routine reminder.
    static let routineReminders = Key<Bool>("routineReminders", default: true)
    /// A macOS notification one minute later when the notch could not show the reminder.
    static let routineBackupNotification = Key<Bool>("routineBackupNotification", default: true)
    /// Minutes of get-ready warning a new routine starts with.
    static let routineGetReadyDefault = Key<Int>("routineGetReadyDefault", default: 30)
}

struct KhmerCalendarSettings: View {
    @ObservedObject private var store = DayNoteStore.shared
    @ObservedObject private var routineStore = RoutineStore.shared
    @Default(.khmerCalendarLatin) private var latin
    @State private var routineEditor: RoutineEditorTarget?
    @Default(.routineReminders) private var remindersOn
    @Default(.routineBackupNotification) private var backupOn
    @Default(.routineGetReadyDefault) private var getReadyDefault
    @State private var alerts: UNAuthorizationStatus = .notDetermined

    private var today: DayKey { DayKey(Date(), calendar: .current) }

    var body: some View {
        Form {
            Section {
                let date = KhmerCalendar.date(today)
                VStack(alignment: .leading, spacing: 3) {
                    let script: CalendarScript = latin ? .latin : .khmer
                    Text(KhmerFormat.dateLine(today, script: script))
                        .font(.system(size: 15, weight: .semibold))
                    Text(KhmerFormat.lunarLine(date, script: script) + (date.isHolyDay ? " · ថ្ងៃសីល" : ""))
                        .foregroundStyle(.secondary)
                    ForEach(KhmerCalendar.holidays(today), id: \.englishName) { holiday in
                        Text(latin ? holiday.englishName : "\(holiday.khmerName) · \(holiday.englishName)")
                            .foregroundStyle(Ink.tab(.calendar))
                    }
                }
                .padding(.vertical, 2)
            } header: {
                Text("Today")
            }

            routinesSection

            Section {
                Toggle(isOn: $latin) {
                    Label {
                        Text("Show in English letters")
                        Text("Dates, weekdays, months and numbers in English; the calendar's own words stay Khmer: \"3កើត\", \"3 កើត · ខែកត្ដិក · Year of the Horse · BE 2570\", ថ្ងៃសីល.")
                    } icon: {
                        Image(systemName: "translate")
                    }
                }
                Defaults.Toggle(key: .khmerShowLunarDay) {
                    Text("Show the lunar day beside each date")
                }
                Defaults.Toggle(key: .khmerShowHolidays) {
                    Text("Show holidays")
                }
                Defaults.Toggle(key: .khmerShowHolyDays) {
                    Text("Mark ថ្ងៃសីល with a moon")
                }
                Defaults.Toggle(key: .khmerShowEvents) {
                    Text("Show Apple Calendar events with your notes")
                }
            } header: {
                Text("Calendar tab")
            } footer: {
                Text("Weeks start on Monday and Sundays are red. Which Apple calendars show is set on the Calendar page.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                HStack {
                    Text("Notes")
                    Spacer()
                    Text(noteCount)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                HStack {
                    Text("Alerts")
                    Spacer()
                    alertStatus
                }
                Button("Show notes file in Finder") {
                    let url = DayNoteStore.fileURL
                    if FileManager.default.fileExists(atPath: url.path) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } else {
                        NSWorkspace.shared.open(url.deletingLastPathComponent().deletingLastPathComponent())
                    }
                }
                if store.saveFailed {
                    Text("The last change couldn't be saved to the notes file.")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Your notes")
            } footer: {
                Text("Add a note from the Calendar tab: click a day, then Add note. Notes stay on this Mac in Application Support › Tisa Dynamic Island › Calendar › notes.json and are not synced. A note with a time and Alert on shows a macOS notification at that time.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                Text("Lunar dates use the Chhankitek calculation, checked for 1900 to 2100. Khmer New Year, Visak Bochea, the Royal Ploughing Ceremony, Pchum Ben and the Water Festival are worked out from the lunar calendar; the other holidays have fixed dates. The government sets each year's official list and any substitute days, so a year can differ from what is shown here.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("Lunar calculation ported from momentkh by ThyrithSor (MIT).")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } header: {
                Text("About the dates")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Khmer Calendar")
        .sheet(item: $routineEditor) { target in
            RoutineSettingsEditor(target: target) { routineEditor = nil }
        }
        .task { await refreshAlerts() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshAlerts() }
        }
    }

    private var routinesSection: some View {
        Section {
            Toggle(isOn: $remindersOn) {
                Text("Routine reminders")
                Text(remindersOn ? "The notch drops down when a routine is due." : "Paused. Routines and streaks are kept.")
            }
            Toggle(isOn: $backupOn) {
                Text("Backup macOS notification")
                Text("One minute later, only if the notch could not show it.")
            }
            .onChange(of: backupOn) { _, on in
                Task {
                    if on { await RoutineBackups.requestPermissionIfNeeded() }
                    RoutineStore.shared.syncBackups()
                    await refreshAlerts()
                }
            }
            if backupOn && alerts == .denied {
                HStack(spacing: 8) {
                    Text("Backup notifications are off in System Settings").foregroundStyle(.orange)
                    Spacer()
                    Button("Open") { DayNoteAlerts.openSystemSettings() }
                }
            }
            Picker(selection: $getReadyDefault) {
                ForEach(Routine.getReadyChoices, id: \.self) { minutes in
                    Text(minutes == 0 ? "Off" : "\(minutes) min").tag(minutes)
                }
            } label: {
                Text("Get ready before")
                Text("The default for new routines. Each routine can change it.")
            }
            .pickerStyle(.segmented)

            HStack {
                Text(routineStore.book.routines.isEmpty ? "No routines yet" : "Your routines")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    routineEditor = .new
                } label: {
                    Label("New routine", systemImage: "plus")
                }
            }
            ForEach(routineStore.book.routines.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }) { routine in
                HStack(spacing: 10) {
                    Text(RoutineBackups.timeText(routine))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Text(routine.title).fontWeight(.medium).lineLimit(1)
                    Spacer()
                    Text(RoutineRepeatText.text(routine.weekdays)).foregroundStyle(.secondary)
                    Text(routine.getReadyMinutes == 0 ? "No get ready" : "Get ready \(routine.getReadyMinutes) min")
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .trailing)
                    let streak = routineStore.book.streak(of: routine, today: today)
                    Label("\(streak)", systemImage: "flame.fill")
                        .foregroundStyle(streak > 0 ? Color.orange : Color.secondary)
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                        .accessibilityLabel("\(streak) day streak")
                    Button("Edit") { routineEditor = .edit(routine) }
                }
            }
            Button("Show routines file in Finder") {
                let url = RoutineStore.fileURL
                if FileManager.default.fileExists(atPath: url.path) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } else {
                    NSWorkspace.shared.open(url.deletingLastPathComponent().deletingLastPathComponent())
                }
            }
            if routineStore.saveFailed {
                Text("The last change couldn't be saved to the routines file.")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Routines")
        } footer: {
            Text("Make routines here or with + Routine in the notch's Calendar tab, and tick them in the notch. Today and yesterday can be ticked. Routines stay on this Mac in Application Support › Tisa Dynamic Island › Calendar › routines.json and are not synced.")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private var noteCount: String {
        let notes = store.book.notes.count
        let days = store.book.daysWithNotes.count
        if notes == 0 { return "None yet" }
        return "\(notes) on \(days) \(days == 1 ? "day" : "days")"
    }

    @ViewBuilder
    private var alertStatus: some View {
        switch alerts {
        case .authorized, .provisional, .ephemeral:
            Text("Allowed").foregroundStyle(.secondary)
        case .denied:
            HStack(spacing: 8) {
                Text("Off in System Settings").foregroundStyle(.orange)
                Button("Open") { DayNoteAlerts.openSystemSettings() }
            }
        default:
            Button("Allow alerts") {
                Task {
                    _ = await DayNoteAlerts.requestPermission()
                    await refreshAlerts()
                }
            }
        }
    }

    private func refreshAlerts() async {
        alerts = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
