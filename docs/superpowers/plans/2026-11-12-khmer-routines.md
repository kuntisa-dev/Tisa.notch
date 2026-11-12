# Khmer Calendar Routines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repeating routines on the Khmer calendar. The notch drops down to remind (get ready, then due), they are ticked Done with a streak, and a macOS notification serves as backup.

**Architecture:** All rules (scheduling, status, streak, reminder timing, file safety) live in `Packages/KhmerCalendarKit` as pure, unit-tested code. The app adds a store, a minute clock that opens the notch, a pop-out overlay, calendar UI and a Settings section under `TisaDynamicIsland/features/KhmerCalendar/Routines/`.

**Tech Stack:** Swift 6 (package) / Swift 5 mode (app), SwiftUI, Defaults, UserNotifications, XCTest, macOS 15+, Xcode 26.2.

**Spec:** `docs/superpowers/specs/2026-11-12-khmer-routines-design.md`

## Global Constraints

- **No git commits.** The owner commits only on request. Each task's "Commit" step is replaced by recording the result in `.superpowers/sdd/2026-11-12-khmer-routines/progress.md`.
- `features/` is an Xcode synchronized folder, so new app files need no `project.pbxproj` edit. New package files also need none.
- Package tests: `swift test --package-path Packages/KhmerCalendarKit`. App compile check: `xcodebuild -project TisaDynamicIsland.xcodeproj -scheme TisaDynamicIsland -configuration Debug build` must end `** BUILD SUCCEEDED **`.
- Don't change unrelated features. No analytics. Don't weaken security.
- Routine title: trimmed, non-empty, at most 100 characters. `getReadyMinutes` ∈ {0, 5, 10, 15, 30, 60}. Weekday numbering: 1 = Monday … 7 = Sunday (same as `DayKey.weekday`).
- Catch-up window: 2 hours. Snooze: 10 minutes. Backup notification: occurrence time + 1 minute; look-ahead 48 hours. Notification id prefix `routine-`; category `ROUTINE`; actions `DONE`, `SNOOZE`.
- Defaults keys: `routineReminders` (Bool, true), `routineBackupNotification` (Bool, true), `routineGetReadyDefault` (Int, 30).
- File: `~/Library/Application Support/Tisa Dynamic Island/Calendar/routines.json`.
- Colours from the mockups: done `#38BDF8` (dot), missed `#FF8A3D` (square), get ready `#FFB347`, due/accent `#8FE0FF`, streak `#FFB347`.

## Review Focus

1. **The Mac sleeps across a routine's time and wakes 30 min later.** The pop-out should appear on wake, not at the next minute tick, and not at all if it is more than 2 h late. Test: `testDueNowCatchUpWindow` (Task 3). The wake hook is in Task 5.
2. **A get-ready time before midnight for a routine just after midnight** (00:15 with 30 min → 23:45 the day before). It must belong to the routine's day and fire at 23:45 the previous evening. Test: `testGetReadyCrossesMidnight` (Task 3).
3. **The routine is edited after it was created**, e.g. days changed from every day to weekdays. Past weekends that were done stay done, and past weekends that weren't must not count as missed. Test: `testStatusUsesCurrentDaysOnly` (Task 1).
4. **Two routines due in the same minute.** Both must be shown one after the other ("1 of 2"), and Done on the first must not close the notch while the second waits. Test: `testDueNowReturnsAllInTimeOrder` (Task 3). The queue is in Task 5.
5. **Done pressed in a backup banner while the app is running.** It must tick the routine and remove that occurrence from the notch queue. Done by hand in Task 7; routing in Task 4.

---

### Task 1: Routine model and day rules (package)

**Files:**
- Create: `Packages/KhmerCalendarKit/Sources/KhmerCalendarKit/Routine.swift`
- Test: `Packages/KhmerCalendarKit/Tests/KhmerCalendarKitTests/RoutineTests.swift`

**Interfaces:**
- Consumes: `DayKey` (`string`, `weekday`, `adding(days:)`, `init?(_ string:)`, `Comparable`).
- Produces:
  - `public struct Routine: Identifiable, Codable, Equatable, Sendable`, with `id: UUID`, `title: String`, `hour: Int`, `minute: Int`, `weekdays: Set<Int>`, `getReadyMinutes: Int`, `startDay: String`, `createdAt: Date`.
  - `static let maxTitleLength = 100`, `static let getReadyChoices = [0, 5, 10, 15, 30, 60]`.
  - `static func make(id: UUID = UUID(), title: String, hour: Int, minute: Int, weekdays: Set<Int>, getReadyMinutes: Int, startDay: DayKey, createdAt: Date = Date()) -> Routine?`
  - `func isScheduled(on day: DayKey) -> Bool`
  - `public enum RoutineStatus: Equatable, Sendable { case done, missed, upcoming, none }`
  - `public enum DayMark: Equatable, Sendable { case allDone, someMissed }`
  - `public struct RoutineBook: Equatable, Sendable`, with `public private(set) var routines: [Routine]`, `public private(set) var done: [UUID: Set<String>]`, `init(routines: [Routine] = [], done: [UUID: Set<String>] = [:])` and:
    - `mutating func upsert(_ routine: Routine)` (keeps history)
    - `mutating func remove(id: UUID)` (drops history too)
    - `func isDone(_ id: UUID, on day: DayKey) -> Bool`
    - `func status(of routine: Routine, on day: DayKey, today: DayKey) -> RoutineStatus`
    - `func mark(on day: DayKey, today: DayKey) -> DayMark?`
    - `static func canTick(_ day: DayKey, today: DayKey) -> Bool`
    - `@discardableResult mutating func toggleDone(_ id: UUID, on day: DayKey, today: DayKey) -> Bool`: returns false and changes nothing when `canTick` is false or the routine is unknown.
    - `mutating func setDone(_ id: UUID, on day: DayKey)`: always marks done. Used by reminders, which may act on today only.
    - `func streak(of routine: Routine, today: DayKey) -> Int`
    - `func routines(on day: DayKey) -> [Routine]`: scheduled ones, sorted by time then `createdAt`.

- [ ] **Step 1: Write the failing tests** (in `RoutineTests`, `today = DayKey(year: 2026, month: 11, day: 12)`, a Thursday)
  - `testMakeValidates`: an empty or whitespace-only title → nil; a 150-character Khmer title is cut to 100 characters; hour 24 → nil; minute 60 → nil; empty weekdays → nil; weekday 0 or 8 → nil; getReady 20 → nil.
  - `testScheduledRespectsWeekdaysAndStart`: a weekdays routine starting 2026-11-10 is scheduled on 11-12 (Thu), not on 11-14 (Sat), and not on 11-09 (Mon, before start).
  - `testStatus`: done day → `.done`; past scheduled day not done → `.missed`; today not done → `.upcoming`; day not scheduled → `.none`.
  - `testStatusUsesCurrentDaysOnly`: an every-day routine with a done Saturday, edited to weekdays (via `upsert`). Saturday is still `.done`, a different past Saturday that wasn't done is `.none`.
  - `testDayMark`: two routines on a past day, both done → `.allDone`; one missed → `.someMissed`; today with one upcoming → nil; a day with no scheduled routine → nil.
  - `testTickWindow`: `canTick` is true for today and yesterday and false for 2 days ago and for tomorrow. `toggleDone` on 2 days ago returns false and leaves `done` unchanged. Toggling today twice ends not done.
  - `testStreak`: an every-day routine starting 11-01, done 11-05…11-11, today upcoming → 7. Then done today → 8.
  - `testStreakSkipsUnscheduledDays`: a Mon/Wed/Fri routine done on Mon 11-09 and Wed 11-11, today Thu → 2.
  - `testStreakStopsAtMissedAndStart`: done 11-10 and 11-11, 11-09 missed → 2. A routine that started today and isn't done yet → 0.
  - `testRemoveDropsHistory`: after `remove`, `done[id]` is nil.
  - `testRoutinesOnDaySorted`: 20:00 and 05:30 → 05:30 first.

- [ ] **Step 2: Run and see the tests fail**
  - Run: `swift test --package-path Packages/KhmerCalendarKit --filter RoutineTests`
  - Expected: a compile error, "cannot find 'Routine' in scope".

- [ ] **Step 3: Write `Routine.swift`** with the interfaces above. Streak: walk back from today with `adding(days: -1)`. Stop when `day < startDay`. Skip unscheduled days, and skip today when it's upcoming. Stop at the first `.missed`.

- [ ] **Step 4: Run the tests and see them pass**
  - Run: `swift test --package-path Packages/KhmerCalendarKit`
  - Expected: all tests pass (53 existing + 11 new).

- [ ] **Step 5: Record in the ledger.** No commit.

### Task 2: routines.json file (package)

**Files:**
- Create: `Packages/KhmerCalendarKit/Sources/KhmerCalendarKit/RoutineFile.swift`
- Test: `Packages/KhmerCalendarKit/Tests/KhmerCalendarKitTests/RoutineFileTests.swift`

**Interfaces:**
- Consumes: `RoutineBook` (Task 1). Copies the behaviour of `DayNoteFile` (`DayNoteFile.swift`), including `.unreadableInPlace`.
- Produces: `public enum RoutineFile`, with `static let version = 1`, `enum LoadResult { case loaded(RoutineBook), missing, unreadable(movedTo: URL), unreadableInPlace }`, `static func load(from url: URL, now: Date = Date()) -> LoadResult` and `static func save(_ book: RoutineBook, to url: URL) throws`.
- On disk: `{"version":1,"routines":[...],"done":{"<uuid>":["2026-11-11",...]}}`, ISO-8601 dates, pretty-printed with sorted keys, and `done` arrays sorted.

- [ ] **Step 1: Write the failing tests**
  - `testRoundTrip`: two routines and done days are saved and loaded back as an equal book. The text contains `"version" : 1`.
  - `testMissing`
  - `testBrokenFileMovedAside`: the name starts with `routines-unreadable-` and the bytes are kept.
  - `testStuckFileReportedInPlace`: same as `DayNoteTests.testUnreadableFileThatCannotBeMovedIsReportedAsStuck`.
  - `testNewerVersionMovedAside`

- [ ] **Step 2: Run and see the tests fail.** `--filter RoutineFileTests` gives a compile error.

- [ ] **Step 3: Write `RoutineFile.swift`.** Move `asideURL` out of `DayNoteFile` into an internal helper both files use, so it isn't duplicated.

- [ ] **Step 4: Run the whole package and see it pass.** The `DayNoteTests` must still pass.

- [ ] **Step 5: Record in the ledger.**

### Task 3: Reminder timing (package)

**Files:**
- Create: `Packages/KhmerCalendarKit/Sources/KhmerCalendarKit/RoutinePlan.swift`
- Test: `Packages/KhmerCalendarKit/Tests/KhmerCalendarKitTests/RoutinePlanTests.swift`

**Interfaces:**
- Consumes: `Routine`, `RoutineBook` (Task 1).
- Produces:
  - `public struct RoutineOccurrence: Equatable, Hashable, Sendable`:
    - `enum Kind: String, Sendable { case getReady = "ready", due }`
    - `let routineID: UUID`, `let day: DayKey`, `let kind: Kind`, `let fireDate: Date`
    - `var id: String`, which is `"routine-<UUID uuidString>-<day.string>-<kind.rawValue>"`.
  - `public enum RoutinePlan`:
    - `static let catchUp: TimeInterval = 7200`, `static let snooze: TimeInterval = 600`, `static let backupDelay: TimeInterval = 60`, `static let lookAhead: TimeInterval = 172_800`, `static let identifierPrefix = "routine-"`
    - `static func occurrences(of routine: Routine, on day: DayKey, calendar: Calendar) -> [RoutineOccurrence]`: get-ready (if `getReadyMinutes > 0`), then due. Fire dates are built with `calendar` from the day plus hour and minute, minus the lead.
    - `static func dueNow(book: RoutineBook, now: Date, calendar: Calendar, handled: Set<String>, snoozedUntil: [String: Date]) -> [RoutineOccurrence]`: checks yesterday, today and tomorrow (a get-ready can fall on the previous evening), applies the spec §2 rules, sorted by `fireDate`.
    - `static func backups(book: RoutineBook, now: Date, calendar: Calendar) -> [RoutineOccurrence]`: occurrences with `fireDate + backupDelay` in `(now, now + lookAhead]` whose routine is not done that day.
    - `static func occurrenceID(parsing id: String) -> (routineID: UUID, day: DayKey, kind: RoutineOccurrence.Kind)?`, used to route notification responses.

- [ ] **Step 1: Write the failing tests.** Use a calendar with `TimeZone(identifier: "Asia/Phnom_Penh")` and dates built with it.
  - `testOccurrencesWithAndWithoutGetReady`: 05:30 with 30 → [ready 05:00, due 05:30]; lead 0 → [due].
  - `testGetReadyCrossesMidnight`: 00:15 with 30 on 11-13 → ready fires at 11-12 23:45 and `day` is 11-13. `dueNow` at 11-12 23:46 returns it.
  - `testDueNowCatchUpWindow`: due 05:30. now 05:29 → []; 05:30 → [due]; 07:30 → [due]; 07:31 → [].
  - `testDueNowSkipsDoneHandledSnoozed`: done that day → []; id in `handled` → []; `snoozedUntil[id]` = 05:40 at now 05:35 → [] and at 05:40 → [due].
  - `testGetReadyReplacedByDue`: at 05:31 with nothing handled → only the due occurrence, not ready.
  - `testDueNowReturnsAllInTimeOrder`: two routines at 05:30 created at different times → both, stable order by `createdAt`.
  - `testBackupsWindowAndDone`: at now 11-12 04:00, an every-day 05:30 routine (lead 30) → ids for 11-12 ready and due, 11-13 ready and due; when 11-12 is done → only 11-13's. Fire + 60 s is in the window.
  - `testIDRoundTrip`: `occurrenceID(parsing: occ.id)` gives back the same parts; `"day-note-x"` → nil.

- [ ] **Step 2: Run and see the tests fail.**

- [ ] **Step 3: Write `RoutinePlan.swift`.** Parse the id by removing the prefix, taking the first 36 characters as the UUID, then splitting the rest.

- [ ] **Step 4: Run the whole package and see it pass.**

- [ ] **Step 5: Record in the ledger.**

### Task 4: Store, backup notifications, notification routing (app)

**Files:**
- Create: `TisaDynamicIsland/features/KhmerCalendar/Routines/RoutineStore.swift`
- Create: `TisaDynamicIsland/features/KhmerCalendar/Routines/RoutineBackups.swift`
- Create: `TisaDynamicIsland/features/KhmerCalendar/Routines/NotificationRouter.swift`
- Modify: `TisaDynamicIsland/features/KhmerCalendar/KhmerCalendarSettings.swift` (the `Defaults.Keys` extension at the top): add the three keys from Global Constraints.
- Modify: `TisaDynamicIsland/TisaDynamicIslandApp.swift`, next to `DayNoteStore.shared.syncAlerts()` (around line 336). After the AI Usage start, call `NotificationRouter.shared.install()`, then `RoutineStore.shared.syncBackups()`.

**Interfaces:**
- Consumes: `RoutineBook`, `RoutineFile`, `RoutinePlan` (Tasks 1–3). The pattern is `DayNoteStore` (serial `alertSync` task, `mustNotWrite`, `saveFailed`).
- Produces:
  - `@MainActor final class RoutineStore: ObservableObject`, with:
    - `static let shared`, `@Published private(set) var book: RoutineBook`, `@Published private(set) var saveFailed: Bool`, `static var fileURL: URL`
    - `func save(_ routine: Routine)`, `func delete(id: UUID)`
    - `func toggleDone(_ id: UUID, on day: DayKey)`: today is `DayKey(Date(), calendar: .current)`.
    - `func markDone(_ id: UUID, on day: DayKey)`, `func syncBackups()`
  - `@MainActor enum RoutineBackups`:
    - `static func sync(with book: RoutineBook) async`: when `Defaults[.routineBackupNotification]` is false or permission isn't granted, removes all pending `routine-` requests. Otherwise it makes the pending `routine-` requests equal `RoutinePlan.backups`, with trigger date `fireDate + 60 s`, category `ROUTINE`, title = routine title, and body "Get ready · 05:30" or "Now · 05:30 · 🔥 N".
    - `static func remove(ids: [String])`, `static func scheduleSnooze(_ occ: RoutineOccurrence, at: Date) async`, `static func registerCategory()`
    - `static func requestPermissionIfNeeded() async`: the editor calls it on first save.
  - `enum RoutineAction { case done, snooze, open }`.
  - `@MainActor final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate`, with `static let shared`, `func install()` and `var onRoutineAction: ((_ occurrenceID: String, _ action: RoutineAction) -> Void)?`. Task 5 sets that closure.
    - `install()` keeps `center.delegate` as `previous` (it may be AI Usage's), sets itself as the delegate and calls `RoutineBackups.registerCategory()`. It must run in `applicationDidFinishLaunching`, so a banner button that launched the app still reaches it.
    - `willPresent` answers `[.banner, .sound]`.
    - `didReceive`:
      - category `ROUTINE` + `DONE` → `onRoutineAction?(requestID, .done)`
      - `SNOOZE` → `.snooze`
      - the default tap → `.open`
      - anything else is forwarded to `previous`.
    - Snooze copies get the id `<occurrence id>-snooze`; remove that suffix before calling the closure.

- [ ] **Step 1: Write the three files and the Defaults keys.** No unit tests: these are system wrappers. All their rules are already tested in Tasks 1–3.

- [ ] **Step 2: Build.** Run the Debug `xcodebuild` and expect `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Record in the ledger.**

### Task 5: The minute clock and the notch pop-out (app)

**Files:**
- Create: `TisaDynamicIsland/features/KhmerCalendar/Routines/RoutineReminders.swift`
- Create: `TisaDynamicIsland/features/KhmerCalendar/Routines/RoutinePopout.swift`
- Modify: `TisaDynamicIsland/ContentView.swift:380-407`. Wrap the `if tabEditor.isEditing … switch coordinator.currentView …` block in a `ZStack`. Overlay `RoutinePopout()` when `RoutineReminders.shared.current != nil`, observed with `@ObservedObject private var routineReminders = RoutineReminders.shared`.
- Modify: `TisaDynamicIsland/TisaDynamicIslandApp.swift`: at launch, after Task 4's calls, `RoutineReminders.shared.start()`.

**Interfaces:**
- Consumes: `RoutineStore`, `RoutineBackups` (Task 4); `RoutinePlan.dueNow` (Task 3); `SharingStateManager.shared.beginInteraction()` and `endInteraction()`; the app delegate's `viewModels: [String: TisaViewModel]` keyed by `screen.displayUUID`, with `TisaViewModel.open()`.
- Produces:
  - `@MainActor final class RoutineReminders: ObservableObject`, with:
    - `static let shared`, `@Published private(set) var queue: [RoutineOccurrence]`, `var current: RoutineOccurrence? { queue.first }`, `var position: (index: Int, count: Int)`
    - `func start()`, `func recheck()`
    - `enum Answer { case done, snooze, ok }`, `func answer(id: String, _ answer: Answer)`
  - `start()` sets `NotificationRouter.shared.onRoutineAction`: `.done` → `answer(id:, .done)`, `.snooze` → `.snooze`, `.open` → `recheck()`. A `.done` for an occurrence that isn't in the queue still ticks the routine through `RoutineStore.markDone`.
  - `start()` also sets up a timer firing at each minute boundary, plus observers for `NSWorkspace.didWakeNotification`, `.NSCalendarDayChanged` and `Defaults.publisher(.routineReminders)`. All of them call `recheck()`.
  - `recheck()`: when reminders are off, it clears the queue. Otherwise it sets `queue = RoutinePlan.dueNow(...)` with in-memory `handled` and `snoozedUntil`. For each new head:
    - It removes that occurrence's backup.
    - If the queue went from empty to non-empty, it calls `beginInteraction()` and opens the notch on the screen under `NSEvent.mouseLocation` (fallback `NSScreen.main`), reached through `NSApp.delegate as? AppDelegate`.
    - If the queue went from non-empty to empty, it calls `endInteraction()`.
  - `answer`:
    - `.done` → `RoutineStore.shared.markDone(routineID, on: day)` and add both of that day's ids to `handled`.
    - `.ok` → `handled.insert(id)`.
    - `.snooze` → `snoozedUntil[id] = now + 600` and `RoutineBackups.scheduleSnooze`.
    - Then `recheck()`.
  - `RoutinePopout`: the Routines-Popout mockup, scaled to the notch.
    - Get ready: hourglass `hourglass` SF Symbol in `#FFB347`; "GET READY · IN N MIN"; title and time; buttons **OK** and **Done early**. Done early → `.done`.
    - Due: `alarm` symbol in `#8FE0FF`; "HH:mm · NOW" with a "1 of N" capsule when the count is more than 1; title; repeat-days text and 🔥 streak; buttons **Done** and **Snooze 10 min**.
    - It uses `HomePillButtonStyle` and `.homeCard()`, so picture themes stay readable.

- [ ] **Step 1: Write both files and the `ContentView` and launch hooks.**

- [ ] **Step 2: Build** and expect `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Smoke check by rendering.** Render `RoutinePopout` for both kinds offscreen to PNG at 696×172 and 616×142, the same method as the Khmer calendar Task 7, and look at the images. Text must not clip.

- [ ] **Step 4: Record in the ledger.**

### Task 6: Calendar tab UI and routine editor (app)

**Files:**
- Create: `TisaDynamicIsland/features/KhmerCalendar/Routines/RoutineRow.swift`
- Create: `TisaDynamicIsland/features/KhmerCalendar/Routines/RoutineEditor.swift`
- Modify: `TisaDynamicIsland/features/KhmerCalendar/Views/KhmerDayCard.swift`
  - Add a "Routines" section above the notes. Its header carries the "N OF M DONE" count and a + Routine button; the notes header gets a + Note button, replacing the bottom "Add note" button.
  - + Routine and a row tap set `model.routineEditor`. The note editor (`Editing`) is unchanged.
- Modify: `TisaDynamicIsland/features/KhmerCalendar/KhmerCalendarModel.swift`: add `@Published var routineEditor: RoutineEditorTarget?` with `enum RoutineEditorTarget: Identifiable { case new, edit(Routine) }`, so Settings can open it (Task 7).
- Modify: `TisaDynamicIsland/features/KhmerCalendar/Views/KhmerCalendarTab.swift`: while `model.routineEditor != nil`, show only `RoutineEditor` full width in place of the two cards.
- Modify: `TisaDynamicIsland/features/KhmerCalendar/Views/KhmerMonthCard.swift`
  - `KhmerDayCell` gains `mark: DayMark?`: a 5 pt `#38BDF8` circle for `.allDone`, a 5 pt `#FF8A3D` rounded square for `.someMissed`, bottom-trailing. The existing note bar stays.
  - The header gains the two-item legend when the width allows (≥ 300 pt).
  - Today's ring becomes 1.5 pt with a 16% fill. Holiday cells get an 8% red fill.

**Interfaces:**
- Consumes: `RoutineStore` (Task 4), `RoutineBook.status/mark/streak/canTick/routines(on:)` (Task 1), `NotchTyping.begin/end`, `HomeLabel`, `HomePillButtonStyle`, `Ink.*`, `.ink`, `.inkPlate()`.
- Produces: `RoutineEditor(target: RoutineEditorTarget, onClose: () -> Void)`, a view; `KhmerCalendarModel.routineEditor`.
- The editor follows the Routines-Editor mockup:
  - name `TextField` (cut to 100 characters), time `DatePicker(.stepperField)`, a Every day / Weekdays / Weekend capsule, 7 day toggles (Sunday in red, at least one always on)
  - get-ready capsule Off / 5 / 10 / 15 / 30 / 60, starting at `Defaults[.routineGetReadyDefault]` for a new routine
  - the line "Get-ready reminder at HH:mm" or "No get-ready reminder"
  - Save (disabled when invalid), Cancel and, when editing, Delete with a second "Delete? Yes" press
  - On the first save, if the backup switch is on, `await RoutineBackups.requestPermissionIfNeeded()`.
  - `NotchTyping.begin()` in `onAppear`, `.end()` in `onDisappear`.
- Row: a tick circle (disabled with help "Only today and yesterday can be ticked" when `!canTick`), time, title (struck through when done), repeat text ("Every day", "Mon–Fri", "Weekend" or "Mon, Wed, Fri"), and a `flame.fill` streak. Tapping the row opens the editor.

- [ ] **Step 1: Add `RoutineRepeatText.text(_ weekdays: Set<Int>) -> String` to the package** (`Routine.swift`), with a test written first: `testRepeatText`. All 7 → "Every day"; 1–5 → "Mon–Fri"; 6–7 → "Weekend"; {1, 3, 5} → "Mon, Wed, Fri". Run it, see it fail, implement, see it pass.

- [ ] **Step 2: Write the views and changes listed above.**

- [ ] **Step 3: Build** and expect `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Render the Calendar tab offscreen** with a sample `RoutineBook` at both notch sizes (696×172, 616×142), in the dark theme and one picture theme. Check that nothing clips and the marks are visible.

- [ ] **Step 5: Record in the ledger.**

### Task 7: Settings section, docs, release and install

**Files:**
- Modify: `TisaDynamicIsland/features/KhmerCalendar/KhmerCalendarSettings.swift`: add a "Routines" `Section` first, following the Routines-Settings mockup:
  - "Routine reminders" `Toggle` (`routineReminders`), with detail text that changes when paused
  - "Backup macOS notification" `Toggle` (`routineBackupNotification`); turning it on calls `requestPermissionIfNeeded`, and when permission is denied it shows "Backup notifications are off in System Settings" plus Open (`DayNoteAlerts.openSystemSettings()`)
  - "Get ready before" segmented `Picker` (`routineGetReadyDefault`)
  - the list of routines (time, title, repeat text, streak, Edit) and Show in Finder for the `Calendar` folder
  - "Couldn't save routines" when `saveFailed`
  - Changing either toggle calls `RoutineStore.shared.syncBackups()` and `RoutineReminders.shared.recheck()`.
- Edit: sets `coordinator.currentView = .calendar`, opens the notch on the main screen, and sets the tab model's `routineEditor = .edit(routine)`. To make the model reachable, change `KhmerCalendarTab`'s `@StateObject` into a `KhmerCalendarModel.shared` used through `@ObservedObject`.
- Modify: `CUSTOM_FEATURES.md` (a Routines section) and `SESSION_HANDOFF.md` (the Khmer calendar section: the new files, the new Defaults keys, the delegate router, the hand checks still to do).

- [ ] **Step 1: Write the Settings section and the Edit routing.**

- [ ] **Step 2: Run the package tests and the Debug build.** Expect all passing and `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Update the docs.**

- [ ] **Step 4: Release build and install, following `SESSION_HANDOFF.md` steps 1–7.** Expect codesign to verify and the app to be running.

- [ ] **Step 5: Hand checks for the owner**, listed in the final message:
  1. Make a routine 2 minutes ahead with get ready 0. The notch drops down and stays; pressing Done makes the streak 1.
  2. Make one with get ready 5 and the time 7 minutes ahead. The get-ready pop-out appears; press OK, then the due one appears.
  3. Snooze: it comes back 10 minutes later.
  4. Quit the app before a routine's time: the backup banner arrives 1 minute after it. Press Done in the banner, then open the app: the routine is ticked.
  5. Turn the Settings switches off and on.

- [ ] **Step 6: Record in the ledger.** No commit unless the owner asks.
