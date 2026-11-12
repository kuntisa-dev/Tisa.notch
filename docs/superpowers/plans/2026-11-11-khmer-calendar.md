# Khmer Calendar with Day Notes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the notch's Calendar tab with a Khmer lunar calendar where the user can add notes, with optional time and macOS alert, to any day.

**Architecture:** A UI-free local package, `Packages/KhmerCalendarKit`, holds everything testable: the lunar engine, holidays, Khmer formatting, the month grid and the notes file. The app target adds a thin store, a notification scheduler and SwiftUI views in `TisaDynamicIsland/features/KhmerCalendar/`, and `CalendarTabView` is switched to the new view.

**Tech Stack:** Swift 6, SwiftUI, macOS 15, XCTest, UserNotifications, EventKit through the existing `CalendarManager`, Defaults.

**Spec:** `docs/superpowers/specs/2026-11-11-khmer-calendar-design.md`

## Global Constraints

- macOS 15 or later; `KhmerCalendarKit` uses swift-tools-version 6.0 and has no dependencies.
- No network use at runtime, no analytics, no new third-party dependencies. The Chhankitek algorithm is ported, not linked.
- `momentkh` (MIT) is the reference for the port; its copyright notice goes into `THIRD_PARTY_LICENSES`. `LICENSE` and existing notices are not changed.
- Weeks start on Monday (ចន្ទ). Sunday (អាទិត្យ) is the last column and is red.
- Calendar content is in Khmer; buttons and messages are in English.
- Notes file: `~/Library/Application Support/Tisa Dynamic Island/Calendar/notes.json`, shape `{ "version": 1, "notes": [...] }`.
- Note title: trimmed, 1...200 characters. `alert` may be true only when a time is set.
- Notification identifier: `day-note-<uuid>`.
- Engine range: 1900 to 2100.
- Features outside the Calendar tab do not change. The classic layout's week strip (`components/Calendar/TisaCalendar.swift`) is not edited.
- New UI text uses the `ink` modifiers from `features/Home/HomeInk.swift`.
- **No git commits.** The owner commits only on request; tasks end with a passing check instead.
- App code under `TisaDynamicIsland/features/` is an Xcode synchronized folder: new files there need no project file edit.

## Review Focus

1. A leap-month year (two Asadh months): days must not skip or repeat across បឋមាសាឍ → ទុតិយាសាឍ, and lunar holidays after it must land on the right day. Test in Task 2 and Task 3.
2. `notes.json` is unreadable or half-written: the app must keep it as `notes-unreadable-<timestamp>.json` and start empty, never overwrite. Test in Task 4.
3. A note is edited from "time + alert" to "no time": its pending notification must be removed, not left to fire. Test in Task 5 (pure planning function).
4. The Mac's time zone or date changes (travel, midnight): a note stays on the day string it was saved under, and "today" moves at midnight. Test in Task 4 (day key) and by hand in Task 7.
5. Title that is empty, only spaces, or longer than 200 characters, including Khmer text with combining marks: rejected or cut on a character boundary, never a broken glyph. Test in Task 4.

---

### Task 1: Package, Khmer formatting and month grid

**Files:**
- Create: `Packages/KhmerCalendarKit/Package.swift`
- Create: `Packages/KhmerCalendarKit/Sources/KhmerCalendarKit/KhmerFormat.swift`
- Create: `Packages/KhmerCalendarKit/Sources/KhmerCalendarKit/MonthGrid.swift`
- Create: `Packages/KhmerCalendarKit/Tests/KhmerCalendarKitTests/KhmerFormatTests.swift`
- Create: `Packages/KhmerCalendarKit/Tests/KhmerCalendarKitTests/MonthGridTests.swift`
- Modify: `TisaDynamicIsland.xcodeproj/project.pbxproj` (four places, next to every `AIUsageKit` entry: lines ~149, ~368, ~859, ~917, ~1483, ~1647)

**Interfaces:**
- Produces:
  - `public struct DayKey: Hashable, Comparable, Sendable, Codable { public let year, month, day: Int; public init(year:month:day:); public init?(_ string: String); public var string: String /* "2026-11-11" */; public init(_ date: Date, calendar: Calendar) }`
  - `public enum KhmerFormat { static func numerals(_ value: Int) -> String; static func solarMonthName(_ month: Int) -> String; static func weekdayName(_ weekday: Int, short: Bool) -> String }` where `weekday` is 1 = Monday ... 7 = Sunday.
  - `public struct GridDay: Identifiable, Sendable { public let key: DayKey; public let inMonth: Bool; public let isSunday: Bool; public var id: DayKey }`
  - `public enum MonthGrid { static func days(year: Int, month: Int) -> [GridDay] /* always 42, Monday first */ }`

- [ ] **Step 1: Create `Package.swift`** — name `KhmerCalendarKit`, `platforms: [.macOS(.v15)]`, one `.library(name: "KhmerCalendarKit", type: .static, targets: ["KhmerCalendarKit"])`, a target and a test target `KhmerCalendarKitTests`. Header comment in the style of `Packages/AIUsageKit/Package.swift`, naming `momentkh` as the reference.

- [ ] **Step 2: Write the failing tests**

```swift
func testNumerals() {
    XCTAssertEqual(KhmerFormat.numerals(2570), "២៥៧០")
    XCTAssertEqual(KhmerFormat.numerals(0), "០")
}
func testNames() {
    XCTAssertEqual(KhmerFormat.solarMonthName(1), "មករា")
    XCTAssertEqual(KhmerFormat.solarMonthName(11), "វិច្ឆិកា")
    XCTAssertEqual(KhmerFormat.weekdayName(1, short: false), "ចន្ទ")
    XCTAssertEqual(KhmerFormat.weekdayName(7, short: false), "អាទិត្យ")
    XCTAssertEqual(KhmerFormat.weekdayName(7, short: true), "អា")
}
func testDayKeyRoundTrip() {
    XCTAssertEqual(DayKey(year: 2026, month: 11, day: 11).string, "2026-11-11")
    XCTAssertEqual(DayKey("2026-01-05"), DayKey(year: 2026, month: 1, day: 5))
    XCTAssertNil(DayKey("2026-13-01")); XCTAssertNil(DayKey("2026-02-30")); XCTAssertNil(DayKey("x"))
}
func testNovember2026Grid() {          // 1 Nov 2026 is a Sunday
    let days = MonthGrid.days(year: 2026, month: 11)
    XCTAssertEqual(days.count, 42)
    XCTAssertEqual(days[0].key, DayKey(year: 2026, month: 10, day: 26))
    XCTAssertFalse(days[0].inMonth)
    XCTAssertEqual(days[6].key, DayKey(year: 2026, month: 11, day: 1))
    XCTAssertTrue(days[6].isSunday && days[6].inMonth)
}
func testGridAlwaysStartsMonday() {    // every month 1900...2100: 42 cells, cell 0 is a Monday, contains day 1
}
```

Short weekday names, Monday first: `ច អ ពុ ព្រ សុ ស អា`.

- [ ] **Step 3: Run** `swift test --package-path Packages/KhmerCalendarKit` — expected: build failure, types not defined.
- [ ] **Step 4: Implement** `DayKey`, `KhmerFormat` and `MonthGrid`. All date maths uses a fixed Gregorian calendar in UTC, never `Calendar.current`.
- [ ] **Step 5: Run** the tests — expected: PASS.
- [ ] **Step 6: Wire the package into the app.** In `project.pbxproj` add, mirroring the `AIUsageKit` lines with IDs `FA3300000000000000000001` (XCLocalSwiftPackageReference, `relativePath = Packages/KhmerCalendarKit`), `FA3300000000000000000002` (XCSwiftPackageProductDependency) and `FA3300000000000000000003` (PBXBuildFile in the app's Frameworks phase only; not the helper's).
- [ ] **Step 7: Verify** `xcodebuild -project TisaDynamicIsland.xcodeproj -scheme TisaDynamicIsland -configuration Debug build` — expected: `BUILD SUCCEEDED`.

### Task 2: Lunar engine

**Files:**
- Create: `Packages/KhmerCalendarKit/Sources/KhmerCalendarKit/KhmerDate.swift`
- Create: `Packages/KhmerCalendarKit/Sources/KhmerCalendarKit/Chhankitek.swift`
- Create: `Packages/KhmerCalendarKit/Tests/KhmerCalendarKitTests/ChhankitekTests.swift`
- Modify: `Packages/KhmerCalendarKit/Sources/KhmerCalendarKit/KhmerFormat.swift`

**Interfaces:**
- Consumes: `DayKey`, `KhmerFormat.numerals`.
- Produces:
  - `public enum MoonPhase: Sendable { case keit, roach }`
  - `public enum KhmerMonth: Int, CaseIterable, Sendable { case migasir, boss, meakh, phalkun, chetr, pisakh, jesth, asadh, srap, photrobot, assoch, kadeuk, pathamasadh, tutiyasadh; public var name: String }`
  - `public enum AnimalYear: Int, CaseIterable, Sendable { case chhut, chlov, khal, thos, rong, masagn, momee, momae, vok, roka, cho, kor; public var name: String }`
  - `public struct KhmerDate: Equatable, Sendable { lunarDay: Int; phase: MoonPhase; month: KhmerMonth; buddhistYear: Int; animalYear: AnimalYear; isHolyDay: Bool }`
  - `public enum KhmerCalendar { static func date(_ key: DayKey) -> KhmerDate; static func newYearDay(gregorianYear: Int) -> DayKey /* first day of Khmer New Year */ }`
  - `KhmerFormat.lunarDay(_ date: KhmerDate) -> String` ("៣កើត") and `KhmerFormat.lunarLine(_ date: KhmerDate) -> String` ("៣ កើត ខែកត្ដិក ឆ្នាំមមី ព.ស. ២៥៧០").

- [ ] **Step 1: Get the reference.** Download `momentkh` (github.com/ThyrithSor/momentkh, MIT) into a new empty folder in the scratchpad and read its Chhankitek code and its own test dates. Confirm the licence text and copyright line; save them for Task 8. If it cannot be fetched, stop and tell the owner; do not write the algorithm from memory.

- [ ] **Step 2: Confirm the expected dates.** Check each date in the spec's table (and the 2026 equivalents) against the reference's own tests or an official Cambodian holiday list. Use only confirmed dates below; if one in the spec is wrong, correct the spec in the same change.

- [ ] **Step 3: Write the failing tests**

```swift
func testFullMoonFestivals() {      // one assertion per confirmed date, e.g.
    let v = KhmerCalendar.date(DayKey(year: 2025, month: 5, day: 11))     // Visak Bochea
    XCTAssertEqual(v.lunarDay, 15); XCTAssertEqual(v.phase, .keit); XCTAssertEqual(v.month, .pisakh)
    let w = KhmerCalendar.date(DayKey(year: 2025, month: 11, day: 5))     // Water Festival, middle day
    XCTAssertEqual(w.lunarDay, 15); XCTAssertEqual(w.phase, .keit); XCTAssertEqual(w.month, .kadeuk)
    let p = KhmerCalendar.date(DayKey(year: 2025, month: 9, day: 22))     // Pchum Ben, main day
    XCTAssertEqual(p.lunarDay, 15); XCTAssertEqual(p.phase, .roach); XCTAssertEqual(p.month, .photrobot)
}
func testBuddhistYearChangesAfterVisakBochea() {
    XCTAssertEqual(KhmerCalendar.date(DayKey(year: 2025, month: 5, day: 11)).buddhistYear, 2568)
    XCTAssertEqual(KhmerCalendar.date(DayKey(year: 2025, month: 5, day: 12)).buddhistYear, 2569)
}
func testAnimalYearChangesAtNewYear() {     // 2025 is ម្សាញ់, 2026 is មមី
    let ny = KhmerCalendar.newYearDay(gregorianYear: 2026)
    XCTAssertEqual(KhmerCalendar.date(ny).animalYear, .momee)
    // the day before is still .masagn
}
func testNewYearDays() { /* newYearDay for each confirmed year */ }
func testLeapMonthYearHasTwoAsadh() { /* a confirmed leap-month year contains both .pathamasadh and .tutiyasadh and no .asadh */ }
func testEveryDayIsContinuous() {
    // 1900-01-01 ... 2100-12-31: lunarDay in 1...15; next day is +1 in the same phase,
    // or keit 15 -> roach 1, or roach 14/15 -> keit 1 of a different month. Never a skip or repeat.
}
func testHolyDays() { /* 8 keit, 15 keit, 8 roach, and the last roach day of a month are isHolyDay; 7 keit is not */ }
func testLunarLine() { /* exact string for one confirmed date */ }
```

- [ ] **Step 4: Run** `swift test --package-path Packages/KhmerCalendarKit` — expected: FAIL, `KhmerCalendar` not defined.
- [ ] **Step 5: Port the algorithm** into `Chhankitek.swift` (leap-month and leap-day rules, epoch anchoring, New Year time) and expose it through `KhmerCalendar`. Keep the reference's function names in comments so the port can be compared line by line. Cache per-year results in a lock-protected dictionary; a month view asks for 42 days at once.
- [ ] **Step 6: Run** the tests — expected: PASS, and `testEveryDayIsContinuous` finishes in under 10 seconds.

### Task 3: Holidays

**Files:**
- Create: `Packages/KhmerCalendarKit/Sources/KhmerCalendarKit/KhmerHolidays.swift`
- Create: `Packages/KhmerCalendarKit/Tests/KhmerCalendarKitTests/KhmerHolidaysTests.swift`

**Interfaces:**
- Consumes: `KhmerCalendar.date(_:)`, `KhmerCalendar.newYearDay(gregorianYear:)`.
- Produces: `public struct KhmerHoliday: Equatable, Sendable { public let khmerName: String; public let englishName: String; public let isDayOff: Bool }` and `public extension KhmerCalendar { static func holidays(_ key: DayKey) -> [KhmerHoliday] }`.

- [ ] **Step 1: Write the failing tests** — fixed dates (`1 Jan`, `7 Jan`, `8 Mar`, `1 May`, `14 May`, `18 Jun`, `24 Sep`, `15 Oct`, `29 Oct`, `9 Nov`, `29 Dec`) each return one holiday with `isDayOff == true`; the three days of Khmer New Year, Pchum Ben (14 រោច, 15 រោច ភទ្របទ, 1 កើត អស្សុជ) and Water Festival (14 កើត, 15 កើត, 1 រោច កត្ដិក) for each confirmed year; Visak Bochea (15 កើត ពិសាខ); Royal Ploughing (4 រោច ពិសាខ); Meak Bochea (15 កើត មាឃ) with `isDayOff == false`; an ordinary day returns `[]`; a leap-month year still gives exactly 3 Pchum Ben days and 3 Water Festival days.
- [ ] **Step 2: Run** the tests — expected: FAIL.
- [ ] **Step 3: Implement** with two tables at the top of the file (fixed Gregorian, lunar rule) and a header comment saying the official list is set each year by sub-decree and this list is not official.
- [ ] **Step 4: Run** the tests — expected: PASS.

### Task 4: Notes model and file

**Files:**
- Create: `Packages/KhmerCalendarKit/Sources/KhmerCalendarKit/DayNote.swift`
- Create: `Packages/KhmerCalendarKit/Sources/KhmerCalendarKit/DayNoteFile.swift`
- Create: `Packages/KhmerCalendarKit/Tests/KhmerCalendarKitTests/DayNoteTests.swift`

**Interfaces:**
- Produces:
  - `public struct DayNote: Identifiable, Codable, Equatable, Sendable { public let id: UUID; public var day: String; public var title: String; public var hour: Int?; public var minute: Int?; public var alert: Bool; public var createdAt: Date }`
  - `public static func DayNote.make(id: UUID = UUID(), day: DayKey, title: String, time: (hour: Int, minute: Int)?, alert: Bool, createdAt: Date = Date()) -> DayNote?` — trims the title, returns nil when empty, cuts to 200 `Character`s, drops `alert` when `time` is nil, returns nil for hour outside 0...23 or minute outside 0...59.
  - `public struct DayNoteBook: Equatable, Sendable { public private(set) var notes: [DayNote]; public func notes(on day: DayKey) -> [DayNote]; public var daysWithNotes: Set<String>; public mutating func upsert(_ note: DayNote); public mutating func remove(id: UUID) }` — `notes(on:)` returns timed notes by time, then untimed by `createdAt`.
  - `public enum DayNoteFile { public enum LoadResult { case loaded(DayNoteBook), missing, unreadable(movedTo: URL) }; public static func load(from url: URL, now: Date = Date()) -> LoadResult; public static func save(_ book: DayNoteBook, to url: URL) throws }`

- [ ] **Step 1: Write the failing tests** — `make` rejects `""` and `"   "`; trims `"  hi \n"` to `"hi"`; a 300-character Khmer title (`String(repeating: "កើ", count: 300)`) is cut to exactly 200 `Character`s with no broken cluster; `alert: true` with `time: nil` gives `alert == false`; hour 24 gives nil. Sorting: 09:00, 14:30, then untimed in creation order. `upsert` replaces by id. Save then load round-trips in a temp directory and the JSON has `"version": 1`. Load of a missing file gives `.missing`. Load of a file containing `{"version":1,"notes":[` gives `.unreadable`, the original bytes exist at the returned URL named `notes-unreadable-<timestamp>.json`, and `notes.json` no longer exists. A file with `"version": 2` is also treated as unreadable. `save` creates missing parent folders.
- [ ] **Step 2: Run** the tests — expected: FAIL.
- [ ] **Step 3: Implement.** Save uses `Data.write(to:options: .atomic)`; dates encode as ISO 8601.
- [ ] **Step 4: Run** the tests — expected: PASS.

### Task 5: App store and alerts

**Files:**
- Create: `Packages/KhmerCalendarKit/Sources/KhmerCalendarKit/DayNoteAlertPlan.swift`
- Create: `Packages/KhmerCalendarKit/Tests/KhmerCalendarKitTests/DayNoteAlertPlanTests.swift`
- Create: `TisaDynamicIsland/features/KhmerCalendar/Services/DayNoteStore.swift`
- Create: `TisaDynamicIsland/features/KhmerCalendar/Services/DayNoteAlerts.swift`
- Modify: `TisaDynamicIsland/TisaDynamicIslandApp.swift:327` (`applicationDidFinishLaunching`)

**Interfaces:**
- Consumes: `DayNote`, `DayNoteBook`, `DayNoteFile`, `KhmerFormat.lunarLine`, `KhmerCalendar.date`.
- Produces:
  - `public enum DayNoteAlertPlan { public struct Change: Equatable { public var schedule: [DayNote]; public var remove: [String] }; public static func identifier(for id: UUID) -> String; public static func fireDate(for note: DayNote, calendar: Calendar) -> Date?; public static func change(book: DayNoteBook, pending: Set<String>, now: Date, calendar: Calendar) -> Change }`
  - `@MainActor final class DayNoteStore: ObservableObject { static let shared; @Published private(set) var book: DayNoteBook; @Published private(set) var saveFailed: Bool; func save(_ note: DayNote); func delete(id: UUID) }`
  - `@MainActor enum DayNoteAlerts { static func sync(with book: DayNoteBook) async; static func requestPermission() async -> Bool; static func isDenied() async -> Bool }`

- [ ] **Step 1: Write the failing tests for the plan** — a future note with time and alert is in `schedule`; the same note with `alert == false`, with no time, or with a fire date before `now` is not; an identifier in `pending` whose note was deleted, lost its time, or had its alert turned off is in `remove`; identifiers not starting with `day-note-` are never in `remove` (AI Usage notifications share the centre); `identifier(for:)` is `"day-note-" + uuidString`.
- [ ] **Step 2: Run** the tests — expected: FAIL.
- [ ] **Step 3: Implement `DayNoteAlertPlan`**; run — expected: PASS.
- [ ] **Step 4: Implement `DayNoteStore`.** File URL follows `features/Fans/Services/ProfileStore.swift:42` (Application Support › Tisa Dynamic Island) plus `Calendar/notes.json`. On `.unreadable`, start empty. Each `save`/`delete` writes the file, sets `saveFailed`, then calls `Task { await DayNoteAlerts.sync(with: book) }`.
- [ ] **Step 5: Implement `DayNoteAlerts`** with `UNUserNotificationCenter`: `sync` reads pending requests, applies `DayNoteAlertPlan.change`, and adds `UNCalendarNotificationTrigger` requests (title = note title, body = `KhmerFormat.lunarLine` of that day, default sound). It always re-adds scheduled notes so an edited title or time replaces the old request. It never asks for permission itself.
- [ ] **Step 6: Launch sync.** In `applicationDidFinishLaunching` add `Task { await DayNoteAlerts.sync(with: DayNoteStore.shared.book) }`.
- [ ] **Step 7: Verify** the Debug build succeeds (command from Task 1 Step 7).

### Task 6: Note editor and typing in the notch

**Files:**
- Create: `TisaDynamicIsland/features/KhmerCalendar/Views/DayNoteEditor.swift`
- Possibly modify: `TisaDynamicIsland/components/Notch/TisaDynamicIslandWindow.swift:43` (`canBecomeKey`)
- Fallback only: Create `TisaDynamicIsland/features/KhmerCalendar/Views/DayNoteEditorPanel.swift`

**Interfaces:**
- Consumes: `DayNote.make`, `DayNoteStore.shared`, `DayNoteAlerts.requestPermission()`, `DayNoteAlerts.isDenied()`, `SharingStateManager.shared.beginInteraction()` / `endInteraction()`.
- Produces: `struct DayNoteEditor: View { init(day: DayKey, editing: DayNote?, onClose: @escaping () -> Void) }`.

- [ ] **Step 1: Prove typing works.** Put a bare `TextField` in `CalendarTabView` temporarily, build Debug, run, open the Calendar tab, click the field and type with the ABC and Khmer keyboards. Record what happens. If keys do not arrive, check `canBecomeKey` and whether the window needs `makeKey()` on focus; make the smallest change that fixes it and confirm that hovering the notch without clicking still does not steal focus from the front app.
- [ ] **Step 2: Decide.** If typing works in the notch, the editor is shown inside the right card. If it cannot be made reliable without stealing focus on hover, show the same `DayNoteEditor` in a small floating panel modelled on `features/PhotoBooth/KhmerStamp/KhmerStampPanel.swift`, and tell the owner which path was taken. Remove the temporary field.
- [ ] **Step 3: Build `DayNoteEditor`.** Title `TextField` focused on appear; "Set time" toggle with a compact hour:minute `DatePicker` (default: next full hour); "Alert" toggle disabled without a time; Save (disabled while the trimmed title is empty), Cancel, and Delete when `editing != nil`. Return saves, Escape cancels. Turning Alert on calls `requestPermission()`; if denied, the toggle goes back off and the text "Alerts are off in System Settings" appears with an "Open" button for `x-apple.systempreferences:com.apple.Notifications-Settings.extension`. `beginInteraction()` in `onAppear`, `endInteraction()` in `onDisappear`.
- [ ] **Step 4: Verify** the Debug build succeeds; by hand: add a note with a Khmer title, see it in `notes.json`, and confirm the notch stays open while typing and closes normally after Cancel.

### Task 7: Month grid, day panel and the tab

**Files:**
- Create: `TisaDynamicIsland/features/KhmerCalendar/Views/KhmerCalendarTab.swift`
- Create: `TisaDynamicIsland/features/KhmerCalendar/Views/KhmerMonthCard.swift`
- Create: `TisaDynamicIsland/features/KhmerCalendar/Views/KhmerDayCard.swift`
- Create: `TisaDynamicIsland/features/KhmerCalendar/KhmerCalendarModel.swift`
- Modify: `TisaDynamicIsland/features/Home/TabPages.swift:86-105` (`CalendarTabView` body)

**Interfaces:**
- Consumes: `MonthGrid.days`, `KhmerCalendar.date`, `KhmerCalendar.holidays`, `KhmerFormat`, `DayNoteStore`, `DayNoteEditor`, `CalendarManager.shared.events(from:to:)`, `.homeCard()`, `Ink.tab(.calendar)`, `ink` modifiers.
- Produces: `struct KhmerCalendarTab: View` (no parameters; reads `TisaViewModel` from the environment).

- [ ] **Step 1: `KhmerCalendarModel`** (`@MainActor ObservableObject`): `selected: DayKey`, `shownYear`, `shownMonth`, `today: DayKey`, `cells: [Cell]` where `Cell` = `GridDay` + `KhmerDate` + `[KhmerHoliday]`, `events: [EventModel]` for the selected day. `cells` is rebuilt only when the shown month changes. `today` is refreshed on `NSCalendarDayChanged` and when the tab appears. `showPrevious()`, `showNext()`, `goToToday()`, `select(_:)` (selecting a dimmed day also switches month).
- [ ] **Step 2: `KhmerMonthCard`.** Header `វិច្ឆិកា ២០២៦ · ព.ស. ២៥៧០` (BE year of the 15th of the shown month), chevron buttons, and a Today button shown when the month or selected day is not today. Weekday row Monday first, Sunday in red. A 7 × 6 grid sharing the card height through `GeometryReader`; each cell shows the Khmer numeral and, when row height ≥ 22 pt, `KhmerFormat.lunarDay`. Marks: ring for today, filled background for selected, red numeral for Sundays and holidays, a dot for days in `book.daysWithNotes`, a small `moon.fill` for `isHolyDay`, 35% opacity for days outside the month. Each cell has an accessibility label with the full Khmer date.
- [ ] **Step 3: `KhmerDayCard`.** Line 1: weekday, day, month, year in Khmer. Line 2: `KhmerFormat.lunarLine`. Holiday names in red. A scroll list of Apple Calendar events (time or "All day", title; read only), then note rows (time or "–", title, bell when `alert`; click opens the editor; a trash button on hover deletes). "No notes yet" when both are empty. "+ Add note" pinned at the bottom. "Couldn't save notes" when `store.saveFailed`. When the editor is open it replaces the list (or opens the panel, per Task 6).
- [ ] **Step 4: `KhmerCalendarTab`** — `HStack(alignment: .top, spacing: 8)` of the two cards, each in `.homeCard()`, month card about 55% of the width, `.padding(.top, 2)`, and `.onHover { vm.isHoveringCalendar = $0 }` as the old tab had.
- [ ] **Step 5: Switch the tab.** Replace the body of `CalendarTabView` with `KhmerCalendarTab()`. Leave `UpNextBox`, `TodayBox` and `CalendarView` in place; Home and the classic layout still use them.
- [ ] **Step 6: Verify** the Debug build succeeds, then by hand in Large and Standard notch: grid starts on Monday with Sunday red; today is ringed; previous/next/Today work; a leap-month year shows បឋមាសាឍ and ទុតិយាសាឍ; add, edit and delete a note and see the dot appear and go; a note set two minutes ahead with Alert fires a notification; a picture theme keeps all text readable; quit and reopen keeps the notes.

### Task 8: Documents, licence notice and install

**Files:**
- Modify: `THIRD_PARTY_LICENSES`
- Modify: `CUSTOM_FEATURES.md`
- Modify: `TisaDynamicIsland/features/Settings/TisaSettings.swift:73,155`
- Create: `Packages/KhmerCalendarKit/LICENSE` (the momentkh MIT text, as `Packages/AIUsageKit/LICENSE` does for its source)

- [ ] **Step 1:** Add the `momentkh` MIT notice (copyright line saved in Task 2 Step 1) to `THIRD_PARTY_LICENSES` and the package `LICENSE`.
- [ ] **Step 2:** Settings: the Calendar page description becomes "Khmer calendar, notes, and which calendars show"; add `khmer lunar notes alert` to its keywords.
- [ ] **Step 3:** Add a "Khmer calendar and day notes" section to `CUSTOM_FEATURES.md`: what it shows, where notes are stored, that the holiday list is not official, and the file locations.
- [ ] **Step 4: Run** `swift test --package-path Packages/KhmerCalendarKit` — expected: all tests pass.
- [ ] **Step 5: Release and install** with the project's usual workflow: `Scripts/build-release.sh`, quit the app, move the old app in `/Applications` to `~/.Trash`, `ditto` the new one in, `codesign --verify --deep --strict`, `rm -rf build`, `open` it. Expected: codesign prints nothing and the Calendar tab shows the Khmer calendar.
- [ ] **Step 6:** Ask the owner to compare one or two months with a printed Khmer calendar.
