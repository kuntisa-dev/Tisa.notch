# Routines and notch reminders on the Khmer calendar: design

Date: 2026-11-12. Status: approved in conversation; waiting for the owner to review this file.
Mockups: the "Routines & reminders" row on the design canvas
(https://claude.ai/artifact/AQULZMQUftLXKsjLnigx2e): Routines-Calendar, Routines-Editor,
Routines-Popout, Routines-Settings.

## Why
The owner wants to be more disciplined. Repeating routines (run 05:30 every day, study 20:00 on
weekdays) should be planned on the calendar, announced by the notch, ticked off, and tracked with
a streak.

## What the owner decided
- Repeating routines, not one-off tasks. The existing day notes stay as they are.
- At the routine's time the notch drops down and **waits** for Done or Snooze 10 min.
- A **backup macOS notification** 1 minute later, only if the notch could not show it, with Done
  and Snooze buttons.
- **Get ready** reminder before the routine (e.g. 05:00 for 05:30). Settings holds the default;
  each routine can change it.
- **Done marks and streaks.**
- Approach A: routines are their own part of the Khmer calendar, saved in their own file.

## 1. The routine and its rules (KhmerCalendarKit, no UI, unit tested)

`Routine` (Codable, Sendable):
- `id: UUID`, `title: String` (trimmed, not empty, cut to 100 characters, Khmer allowed)
- `hour`, `minute` (0–23, 0–59)
- `weekdays: Set<Int>`: 1 = Monday … 7 = Sunday, never empty. "Every day" = all 7,
  "Weekdays" = 1–5, "Weekend" = 6–7.
- `getReadyMinutes: Int`: one of 0 (off), 5, 10, 15, 30, 60.
- `startDay: String` ("2026-11-12", the day it was created) and `createdAt: Date`.

`RoutineBook`: the routines plus `done: [UUID: Set<String>]`, the days each routine was ticked.

Rules (pure functions, all tested):
- **Scheduled on a day:** the day's weekday is in `weekdays` and the day is on or after `startDay`.
- **Status of a routine on a day,** given today:
  - `done`: the day is in its done set.
  - `missed`: scheduled, before today, not done.
  - `upcoming`: scheduled, today, not done.
  - `none`: not scheduled.
- **Day mark** for the month grid (past days and today only):
  - `allDone`: at least one routine is scheduled and every scheduled one is done.
  - `someMissed`: any scheduled routine on that day is missed.
  - Otherwise no mark. Today never shows "missed", because its routines are at worst upcoming.
- **Who can tick:** today and yesterday only. Ticking toggles: tick again to undo.
- **Streak:** count back over scheduled days from today. A done day adds 1. Today, if it is
  upcoming, is skipped without breaking. The first missed day stops the count. Days that aren't
  scheduled are skipped.
- Changing time or days keeps the done history. Deleting a routine removes its history.

`RoutineFile`: `routines.json`, `{ "version": 1, "routines": [...], "done": {...} }`. It behaves
exactly like `DayNoteFile`: missing → empty; unreadable → moved to
`routines-unreadable-<ts>.json`; cannot be moved → `.unreadableInPlace`, and the store then
never writes.

## 2. Reminder timing (KhmerCalendarKit, unit tested)

An **occurrence** is one routine on one day, of kind `getReady` or `due`.
- Its id is `routine-<uuid>-<yyyy-MM-dd>-ready` or `-due`.
- Fire time: `due` = the routine's time on that day. `getReady` = that time minus
  `getReadyMinutes` (none when 0). A get-ready time that falls on the day before still belongs to
  the routine's day.

`RoutinePlan.dueNow(book, now, calendar, handled: Set<String>, snoozedUntil: [String: Date])`
returns the occurrences to show now, in time order:
- fire time ≤ now and now − fire time ≤ **2 hours** (the catch-up window),
- the routine is not done on that day,
- the occurrence is not handled (answered or replaced),
- and it is not snoozed past now.
- A `getReady` occurrence is dropped once its `due` time has arrived; the due reminder replaces it.

`RoutinePlan.backupNotifications(book, now, calendar)` lists the occurrences between now and
48 hours ahead with fire time + 1 minute. Ids get the prefix `routine-`, so they never clash with
the notes' `day-note-` ids.

## 3. The app side (`TisaDynamicIsland/features/KhmerCalendar/Routines/`)

- **RoutineStore** (`@MainActor`, shared): loads and saves `routines.json` next to `notes.json`.
  Same safety rules as `DayNoteStore`, with `saveFailed` shown in the UI. Methods: save routine,
  delete routine, toggle done (today and yesterday only). Every change re-syncs the backup
  notifications through one serial task (the same pattern as `DayNoteStore.syncAlerts`).
- **RoutineReminders** (`@MainActor`, shared): the clock.
  - It checks on a timer aligned to the start of each minute, at launch, on
    `NSWorkspace.didWakeNotification`, on `.NSCalendarDayChanged`, and after each store change.
  - It keeps `handled` and `snoozedUntil` in memory only. After a relaunch, catch-up may show
    one occurrence again, which is acceptable.
  - It keeps a queue of occurrences from `RoutinePlan.dueNow`. While the queue is not empty and
    reminders are on:
    - It opens the notch on the screen under the mouse.
    - It calls `SharingStateManager.beginInteraction()` so the notch stays open, and ends it when
      the queue empties.
    - It publishes `current` and a "1 of N" position.
  - When an occurrence is shown in the notch, it removes that occurrence's pending backup
    notification.
  - Buttons:
    - **Done** ticks the routine for that day, marks both of the day's occurrences handled and
      shows the next one in the queue.
    - **Snooze 10 min** sets `snoozedUntil` to now + 10 min and schedules a one-off backup for
      then.
    - **OK** (get ready) marks it handled.
    - **Done early** (get ready) ticks the routine and so also cancels the due reminder.
  - If reminders are switched off, the queue is cleared and the interaction ends.
- **Backup notifications:** category `ROUTINE`, actions `DONE` and `SNOOZE`, scheduled with
  `UNCalendarNotificationTrigger`. The app's existing notification delegate (set up by AI Usage)
  forwards responses whose category is `ROUTINE` to `RoutineReminders`. If the backup switch is
  off, all `routine-` requests are removed and none are scheduled. Notification permission is
  asked the first time a routine is saved with the backup switch on.
- **RoutinePopout** view: drawn inside the open notch as an overlay over the current tab while
  `RoutineReminders.current` is set, matching the Routines-Popout mockup. Get ready is amber with
  an hourglass; due is blue with an alarm clock; both show the streak and "1 of N".
- **Calendar tab** (Routines-Calendar mockup):
  - The day card gets a "Routines" section above "Notes", each with a + button.
  - A routine row shows a tick circle, time, name, repeat days and 🔥 streak. The tick is
    disabled for days other than today and yesterday.
  - Clicking a row opens the editor.
  - The month cells get the day mark (blue dot = all done, orange square = missed) and a legend.
  - Visual polish from the mockup: clearer today ring, soft red background on holidays, bigger
    buttons.
- **RoutineEditor** (Routines-Editor mockup): replaces both cards while open, and takes the
  keyboard through `NotchTyping` like the note editor.
  - Fields: name, time stepper, quick choices plus 7 day buttons, get-ready choice (starts at the
    Settings default), and the line "Get-ready reminder at HH:mm".
  - Buttons: Save, Cancel and, when editing, Delete with a confirm step.
- **Settings › Khmer Calendar** (Routines-Settings mockup), a new "Routines" section:
  - "Routine reminders" switch, Defaults key `routineReminders`, default true.
  - "Backup macOS notification" switch, `routineBackupNotification`, default true.
  - "Get ready before" choice, `routineGetReadyDefault`, default 30.
  - The list of routines with streak and Edit (Edit opens the notch's Calendar tab on that
    routine's editor).
  - Show in Finder.

## Error handling
- Damaged `routines.json`: never overwritten (see `RoutineFile`). The UI shows
  "Couldn't save routines".
- Notifications not allowed: the notch reminders still work. Settings shows "Backup notifications
  are off in System Settings" with an Open button.
- Notch window replaced during a pop-out: the queue survives in `RoutineReminders` and is shown
  again on the new window at the next minute check.

## Testing
- KhmerCalendarKit unit tests, written first: routine validation, scheduled-on-day, status, day
  mark, tick window, streak (including non-scheduled gaps, today upcoming, a missed day, and the
  start day), file load/save/unreadable/stuck, occurrence fire times (including get-ready
  crossing midnight), `dueNow` (catch-up window, done, handled, snoozed, get-ready replaced by
  due), and the backup notification list.
- App: Debug build, then a Release build and install, then hand checks by the owner:
  - a routine 2 minutes ahead pops out,
  - Snooze comes back,
  - Done updates the streak,
  - the backup banner appears with the app closed,
  - the Settings switches work.

## Not included
Syncing with iPhone or Apple Reminders, statistics charts, editing days older than yesterday,
custom sounds, one-off tasks with Done/Snooze (notes keep their simple alert).
