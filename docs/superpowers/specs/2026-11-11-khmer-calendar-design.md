# Khmer Calendar with Day Notes: Design

Date: 2026-11-11
Status: waiting for review

## Goal

The Calendar tab in the notch becomes a Khmer calendar. It shows a month in Khmer, with the lunar date of every day, and lets the user write notes for any day. A note can have a time and a macOS alert.

It is for the app's owner, for personal use on one Mac.

## What the user chose

| Question | Choice |
|---|---|
| What the calendar shows | Full Khmer lunar calendar: Khmer numerals, month and weekday names, lunar date on each day, Buddhist Era year, animal year, ថ្ងៃសីល and Cambodian public holidays |
| Where notes are stored | Inside the app, in a file on this Mac. No iPhone sync |
| What a note holds | Title, optional time, optional macOS alert. Several notes per day |
| Where it lives | It replaces the Calendar tab. Up next and Today stay as Home tiles |

## Out of scope

- A Khmer date tile for Home
- Repeating notes
- Sync with iPhone or iCloud
- A separate large calendar window
- Creating or editing Apple Calendar events (they stay read only)
- Changes to the classic layout's one-week strip

## Parts

There are four parts. Each one can be understood and tested without the others.

### 1. Lunar engine: `Packages/KhmerCalendarKit`

A local Swift package with no UI, wired into the Xcode project the same way as `SMCKit`. It has an XCTest target.

**What it does:** takes a Gregorian day and returns the Khmer date.

```swift
public struct KhmerDate: Equatable, Sendable {
    public let lunarDay: Int            // 1...15
    public let phase: MoonPhase         // .keit (កើត) or .roach (រោច)
    public let month: KhmerMonth        // 12 months plus បឋមាសាឍ and ទុតិយាសាឍ in leap-month years
    public let buddhistYear: Int        // ព.ស.
    public let animalYear: AnimalYear   // ជូត ... កុរ
    public let isHolyDay: Bool          // ថ្ងៃសីល
}

public enum KhmerCalendar {
    public static func date(year: Int, month: Int, day: Int) -> KhmerDate
    public static func holidays(year: Int, month: Int, day: Int) -> [KhmerHoliday]
}

public enum KhmerFormat {
    public static func numerals(_ value: Int) -> String              // 2570 -> "២៥៧០"
    public static func lunarLine(_ date: KhmerDate) -> String        // "៣ កើត ខែកត្ដិក ឆ្នាំមមី ព.ស. ២៥៧០"
    public static func solarMonthName(_ month: Int) -> String        // 11 -> "វិច្ឆិកា"
    public static func weekdayName(_ weekday: Int, short: Bool) -> String
}
```

Inputs are plain year, month and day numbers, so results do not depend on the Mac's time zone.

**Method:** the Chhankitek calculation (leap month and leap day rules), ported to Swift with the open-source `momentkh` project (MIT) as the reference. Its copyright notice goes into `THIRD_PARTY_LICENSES`.

**Rules the engine must follow:**
- The Buddhist Era year changes on ១ រោច ខែពិសាខ, the day after Visak Bochea.
- The animal year changes at Khmer New Year.
- ថ្ងៃសីល are ៨ កើត, ១៥ កើត, ៨ រោច and the last day of the lunar month (១៤ រោច or ១៥ រោច).
- Supported range: 1900 to 2100. Outside it the engine still returns a value but the app does not promise it is right.

**Holidays** come from two sources, both in one file so they are easy to update:
- Calculated from the lunar date: Khmer New Year (3 days), Meak Bochea, Visak Bochea, Royal Ploughing Ceremony, Pchum Ben (3 days), Water Festival (3 days).
- Fixed Gregorian dates: 1 Jan, 7 Jan, 8 Mar, 1 May, 14 May, 18 Jun, 24 Sep, 15 Oct, 29 Oct, 9 Nov, 29 Dec.

Each holiday has a Khmer name, an English name, and a flag for "official day off". Meak Bochea is shown as an observance, not a day off.

**Known limit:** the government sets the official list each year by sub-decree, and adds substitute days. The built-in list can be wrong for a given year. The app shows no claim that the list is official.

**Tests:** the engine is checked against published dates for at least three years. The values below are the starting set and each one must be confirmed against an official source before it is used as a test:

| Event | 2024 | 2025 |
|---|---|---|
| Khmer New Year | 13–16 Apr | 14–16 Apr |
| Visak Bochea | 22 May | 11 May |
| Pchum Ben | 1–3 Oct | 21–23 Sep |
| Water Festival | 14–16 Nov | 4–6 Nov |

2026 dates are added the same way. Further tests: a leap-month year shows បឋមាសាឍ and ទុតិយាសាឍ, the BE year changes on the right day, every day in 1900–2100 returns a lunar day in 1...15, and consecutive days never skip or repeat a lunar day.

### 2. Notes store

`TisaDynamicIsland/features/KhmerCalendar/Services/DayNoteStore.swift`, a `@MainActor` observable singleton.

```swift
struct DayNote: Identifiable, Codable, Equatable {
    let id: UUID
    var day: String        // "2026-11-11", the calendar day, no time zone
    var title: String      // trimmed, 1...200 characters
    var hour: Int?         // both nil, or both set
    var minute: Int?
    var alert: Bool        // only true when a time is set
    var createdAt: Date
}
```

- File: `~/Library/Application Support/Tisa Dynamic Island/Calendar/notes.json`, shape `{ "version": 1, "notes": [...] }`.
- Every change is written at once, atomically.
- If the file cannot be read, it is renamed to `notes-unreadable-<timestamp>.json` and a new empty file is started. The user's old data is never overwritten.
- If a write fails, the note stays in memory and the day panel shows "Couldn't save notes".
- Notes for a day are sorted: timed notes first by time, then untimed notes by creation time.
- The pure parts (sorting, validation, encode and decode) live in `KhmerCalendarKit` so they have tests; the app target has no test target.

### 3. Alerts

`Services/DayNoteAlerts.swift`, using `UserNotifications`.

- One notification per note with a time and `alert == true`, at that day and time. Identifier: `day-note-<uuid>`.
- Title is the note's title; the body is the Khmer date line.
- Editing a note replaces its notification. Deleting a note, or turning its alert off, removes it.
- A time in the past is not scheduled.
- Permission is asked the first time the user turns an alert on. If the user says no, the note is saved without an alert and the editor shows "Alerts are off in System Settings" with a button that opens that page.
- At launch the app re-syncs all pending note notifications with the store.

### 4. Calendar tab

Files in `TisaDynamicIsland/features/KhmerCalendar/Views/`. `CalendarTabView` in `features/Home/TabPages.swift` is changed to show the new view; `ContentView` and `NotchTab` do not change.

Two cards side by side, using the existing `.homeCard()` style.

**Left card: the month**
- Header: Khmer month name and year, with the BE year (for example `វិច្ឆិកា ២០២៦ · ព.ស. ២៥៧០`), previous and next arrows, and a Today button that appears when another month or day is selected.
- Weekday row in short Khmer names. Weeks start on Monday (ចន្ទ); Sunday (អាទិត្យ) is the last column and is shown in red.
- Six rows of days. Each cell shows the Khmer numeral, and under it the lunar day (for example `៣កើត`).
- Marks: a ring for today, a filled background for the selected day, red numeral for holidays and Sundays, a small dot for days with notes, a small moon mark for ថ្ងៃសីល. Days from the neighbouring months are dimmed.
- The rows share the card's height. If a row is shorter than 22 pt (Standard notch), the lunar day under the numeral is hidden; it is still shown in the day panel.

**Right card: the selected day**
- Line 1: weekday and Gregorian date in Khmer.
- Line 2: the lunar line (`៣ កើត ខែកត្ដិក ឆ្នាំមមី ព.ស. ២៥៧០`).
- Holiday name, if any.
- A scrolling list: Apple Calendar events for that day (read only, from `CalendarManager.events(from:to:)`), then the user's notes.
- A note row shows its time (or a dash), its title, and a bell if it has an alert. Clicking it opens the editor. A delete button appears on hover.
- **+ Add note** at the bottom opens the editor for a new note.

**Editor** (replaces the list inside the right card while open)
- Title field, a "Set time" toggle with hour and minute, an "Alert" toggle (enabled only when a time is set), Save and Cancel. Delete when editing an existing note.
- Return saves, Escape cancels. Save is disabled while the title is empty.
- While the editor is open the notch stays open, using `SharingStateManager.shared.beginInteraction()` and `endInteraction()` as Edit Tabs does.

**Typing inside the notch** is new for this app: no tab takes typed text today. The first UI task is to prove that a text field in the notch receives keys, including the Khmer keyboard. If it does not work reliably, the editor moves to a small floating panel next to the notch, like the Khmer stamp booth's. The rest of the design does not change.

**Themes:** all text uses the existing `ink` modifiers so it stays readable over picture themes. The holiday red and the calendar accent come from `Ink.tab(.calendar)`.

**Fonts:** system font. macOS supplies Khmer glyphs (Khmer Sangam MN) by fallback. No font is added to the app.

**Language:** calendar content is in Khmer. Buttons and messages (Add note, Save, Cancel, Today) are in English, like the rest of the app.

## Data flow

1. The tab holds the selected day and the shown month.
2. For the shown month it asks the engine for 42 `KhmerDate` values and the holidays, once per month change, and keeps them.
3. For the selected day it reads notes from `DayNoteStore` and events from `CalendarManager`.
4. Saving in the editor writes to `DayNoteStore`, which saves the file and tells `DayNoteAlerts` to add, replace or remove the notification.

Nothing runs on a timer. The month is only recalculated when it changes, and at midnight when "today" moves.

## Settings and documents

- Settings › Calendar keeps its current options (they still control which Apple calendars show). Its description changes to mention the Khmer calendar and notes.
- `CUSTOM_FEATURES.md` gets a section for the feature.
- `THIRD_PARTY_LICENSES` gets the `momentkh` MIT notice.

## Constraints

- macOS 15 or later, SwiftUI, Swift 6 for the new package.
- No network use, no analytics.
- No new third-party dependencies; the reference algorithm is ported, not linked.
- Existing features outside the Calendar tab do not change.
- The GPL-3.0 licence and existing notices stay as they are.

## How it is checked

- `swift test` in `Packages/KhmerCalendarKit` passes.
- The app builds with `Scripts/build-release.sh`.
- By hand in the installed app: month navigation, a leap-month year, add, edit and delete a note, a note alert firing, permission denied path, a picture theme, Standard and Large notch, quit and reopen to see notes kept.
- The owner compares one or two months with a printed Khmer calendar. The tests cover the main festivals, but not every day of every year.
