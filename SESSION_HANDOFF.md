# Session Handoff — Tisa Dynamic Island

Last updated 2026-11-12. Read `CUSTOM_FEATURES.md` for the full feature list. The project memory file has the owner's preferences.

## Project
- The owner's personal fork of **Boring Notch** (GPL-3.0), a macOS notch app. Display name "Tisa Dynamic Island"; in code, `TisaDynamicIsland`.
- Bundle ID `com.kuntisa.tisadynamicisland`. Signing team `PG4QURV7Y5` (free Apple Development certificate).
- Project `TisaDynamicIsland.xcodeproj`, scheme `TisaDynamicIsland`, branch `master`.
- **Only 2 commits so far.** About 220 changed or new files are uncommitted, including the whole Khmer calendar. Commit only when the owner asks, and end the message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Tech stack
- Swift and SwiftUI, macOS 15+ (app `MACOSX_DEPLOYMENT_TARGET = 15.0`, app Swift 5 mode), built with Xcode 26.2.
- Settings use the Defaults library. EventKit for calendars, UserNotifications for alerts. App Sandbox is off.
- Local Swift packages in `Packages/`, wired through `project.pbxproj` as XCLocalSwiftPackageReference:
  - `SMCKit`: fan and sensor access, shared with `TisaFanHelper`.
  - `AIUsageKit`: AI usage engine, Swift 6.
  - `KhmerCalendarKit`: new. Swift 6, no UI, pbxproj IDs `FA33…`.

## Architecture and key files
- `TisaDynamicIsland/features/`: all custom code, one folder per feature. It is an Xcode synchronized folder, so new files there need no pbxproj edit.
  - Folders: AIUsage, Audio, Clipboard, Downloads, Fans, Home, KhmerCalendar, PhotoBooth, Settings, Tabs, Themes.
  - Other top-level folders keep Boring Notch's layout so upstream changes can still be merged.
- Tabs:
  - `features/Tabs/NotchTabs.swift` lists the tabs.
  - `ContentView.swift` (around line 392) maps each tab to its view.
  - Tab pages live in `features/Home/TabPages.swift`.
- Settings:
  - `features/Settings/TisaSettings.swift` holds the page enum `SettingsPage` (title, subtitle, symbol, colors, keywords, page body, Overview sections).
  - Page views are in `FeatureSettings.swift` and `components/Settings/SettingsView.swift`.
- Readable text over picture themes: `features/Home/HomeInk.swift` (`ink`, `inkColor`, `inkPlate`, `Ink.*`).
- Home tile styling: `HomeStyle`, `.homeCard()` and `HomePillButtonStyle`, all in `features/Home/TisaHomeView.swift`.
- Notch window: `components/Notch/TisaDynamicIslandSkyLightWindow.swift`, a non-activating NSPanel.
- Notch sizes: `sizing/matters.swift`. Large is 720×220, Standard is 640×190.

## Khmer calendar (newest feature, built 2026-11-11/12)
Spec: `docs/superpowers/specs/2026-11-11-khmer-calendar-design.md`. Plan: `docs/superpowers/plans/2026-11-11-khmer-calendar.md`.

What it does:
- It replaces the **Calendar tab**: `CalendarTabView` now shows `KhmerCalendarTab()`.
- Left card: the month, Monday first, Sunday in red. Each date shows its Khmer numeral with the lunar day beside it. Today has a ring, holidays are red, a moon marks ថ្ងៃសីល, and a bar marks days with notes.
- Right card: the picked day's Khmer date and lunar line, its holidays, Apple Calendar events (read only) and the owner's notes. A note has a title, an optional time and an optional macOS alert.
- Up next and Today remain available as Home tiles only. The classic layout's week strip is unchanged.

`Packages/KhmerCalendarKit` (52 tests; run `swift test --package-path Packages/KhmerCalendarKit`):
- `Chhankitek.swift`: the lunar maths, ported from **momentkh** (MIT, ThyrithSor). The notice is in `THIRD_PARTY_LICENSES` and the package `LICENSE`. The test fixtures `conversion.json` and `new-year.json` come from momentkh, and the engine matches them for 1900–2100.
- `KhmerHolidays.swift`: two editable tables, fixed-date and lunar. **Not an official list.**
- `DayKey`: a date with no time zone. Also `KhmerFormat`, `MonthGrid`, `DayNote` / `DayNoteBook`, `DayNoteFile` and `DayNoteAlertPlan`.

`features/KhmerCalendar/`:
- `KhmerCalendarModel`: the shown month and selected day.
- `Views/`: `KhmerCalendarTab`, `KhmerMonthCard`, `KhmerDayCard`, `DayNoteEditor`.
- `Services/DayNoteStore`: saves notes to `~/Library/Application Support/Tisa Dynamic Island/Calendar/notes.json`. An unreadable file is renamed `notes-unreadable-<ts>.json`, never overwritten.
- `Services/DayNoteAlerts`: notification identifiers `day-note-<uuid>`. Synced at launch from `TisaDynamicIslandApp.applicationDidFinishLaunching`.
- `Services/NotchTyping`: the notch window's `canBecomeKey` returns `NotchTyping.isActive`, so the notch takes the keyboard only while the note editor is open.
- `KhmerCalendarSettings.swift`: the page Settings › **Khmer Calendar**. Defaults keys `khmerShowLunarDay`, `khmerShowHolidays`, `khmerShowHolyDays` and `khmerShowEvents` (all default true), plus the note count, alert status and Show in Finder.

Decisions that differ from the spec:
- The lunar day sits beside the date, not under it, because the rows are too short.
- Khmer New Year shows 3 or 4 days, whichever the calculation gives.
- The animal year changes on New Year's Day, not at the exact minute.
- A note whose day text can't be read is kept in the file but shown on no day.

## Routines and notch reminders (built 2026-11-12)
Spec: `docs/superpowers/specs/2026-11-12-khmer-routines-design.md`. Plan: `docs/superpowers/plans/2026-11-12-khmer-routines.md`. Ledger: `.superpowers/sdd/2026-11-12-khmer-routines/progress.md`. Canvas mockups: the "Routines & reminders" row.
- Package (79 tests in total): `Routine.swift` (Routine, RoutineBook: status, day mark, tick window, streak, RoutineRepeatText), `RoutinePlan.swift` (occurrences, dueNow with 2 h catch-up, backups), `RoutineFile.swift` (`routines.json`), `AsideFile.swift` (shared with DayNoteFile).
- App, `features/KhmerCalendar/Routines/`:
  - `RoutineStore` saves the file.
  - `RoutineReminders` is the minute clock. It also checks on wake and when the day changes, opens the notch through `AppDelegate.openNotchUnderMouse` and holds it open with `SharingStateManager`.
  - `RoutinePopout` is overlaid on the tab content in `ContentView`.
  - `RoutineBackups` books the `routine-` notifications, with category ROUTINE and Done/Snooze buttons.
  - `NotificationRouter` is the notification delegate. It is installed at launch and reclaimed every minute, and it passes non-routine notifications to AI Usage.
  - `RoutineRow` and `RoutineEditor` are the Calendar tab pieces.
- `KhmerCalendarModel` is now `.shared`. It has `routineEditor`, which Settings › Khmer Calendar › Routines › Edit uses.
- Defaults keys: `routineReminders`, `routineBackupNotification`, `routineGetReadyDefault` (30).
- **Not tested by hand yet:**
  - the pop-out firing at a routine's time
  - Snooze
  - the backup banner with the app closed, and Done in the banner
  - typing in the routine editor
  - Settings › Edit opening the notch

## Other completed features (details in CUSTOM_FEATURES.md)
- New Home (tiles, stacks, Edit Home) and editable tabs.
- Tisa Settings window.
- Notch themes, including the picture themes Bianconeri, Blue Crystal and Red Night with readable "ink" text, card glass and colour icons.
- Fans (Tisa Fan Studio, root helper) and AI Usage (adapted from OpenUsage).
- Photo Booth and the Khmer stamp booth, clipboard history, download progress, mic mute.
- Performance pass: idle CPU about 1–2%, about 108 MB of memory.

## Build and install (one copy only, in /Applications)
1. Build: `Scripts/build-release.sh` (signed, hardened Release).
2. Quit the app.
3. Move the old `/Applications/Tisa Dynamic Island.app` to `~/.Trash`.
4. Copy the new build in: `ditto build/Build/Products/Release/Tisa\ Dynamic\ Island.app /Applications/`.
5. Check the signature: `codesign --verify --deep --strict`.
6. Clean up: `rm -rf build`, and delete any Debug `.app` in DerivedData.
7. `open` the app.

The fan helper trusts any build signed by the team, so rebuilding does not require reinstalling the helper. For an unsigned compile check: `xcodebuild -project TisaDynamicIsland.xcodeproj -scheme TisaDynamicIsland -configuration Debug build`.

## Rules from the owner
- Commit only when asked. Don't change unrelated features.
- Keep the GPL `LICENSE`, `THIRD_PARTY_LICENSES`, `Packages/AIUsageKit/LICENSE` and the Boring Notch credit. Add a notice for any third-party code that is ported in.
- Never use the "OpenUsage" name or logo; the feature is called "AI Usage". No analytics or telemetry.
- Don't weaken security: no disable-library-validation, and no loosening the helper checks.
- No copyrighted characters or celebrity likenesses in app code. The owner's photos stay in `~/Library/Application Support/Tisa Dynamic Island/Themes/`, never in the app bundle.
- The owner likes to design on the artifact canvas first (https://claude.ai/artifact/AQULZMQUftLXKsjLnigx2e), then say "build it". Explain things plainly.

## Known issues and unverified
- **Review done 2026-11-12.** Fixed:
  - If an unreadable `notes.json` couldn't be moved aside, the next save would overwrite it. Now `DayNoteFile.load` returns `.unreadableInPlace` and `DayNoteStore` stops writing (test added, 53 tests).
  - Quick saves could race and bring back a deleted note's alert. `DayNoteStore.syncAlerts()` now runs syncs one after another; launch and the permission grant use it too.
  - `NotchTyping` also ends when its notch window closes (screen changes), so the notch can't get stuck open.
  - Checked and fine: leap-month years (119 reference dates in the two Asadh months match; no holiday falls in Asadh).
  - Open question: after the editor closes, the notch may keep the keyboard until the owner clicks another app (`resignKey()` doesn't hand the keyboard back). Check this by hand.
- **Not tested in the running app:**
  - Typing a note in the notch with the ABC and Khmer keyboards. If keys don't arrive, fall back to a floating panel like `features/PhotoBooth/KhmerStamp/KhmerStampPanel.swift`.
  - A note alert firing.
  - The new Settings page.
  - The layout on picture themes.
- Notification banners while the app is in front rely on AI Usage having registered itself as the notification delegate.
- The owner should compare a month or two with a printed Khmer calendar.

## Next steps
1. ~~Re-run the review~~ Done 2026-11-12; rebuilt and reinstalled.
2. Have the owner test typing, alerts and Settings › Khmer Calendar, and whether typing goes back to the front app after a note is saved.
3. Ask whether to commit. The execution ledger is `.superpowers/sdd/2026-11-11-khmer-calendar/progress.md`; it is git-excluded and can be deleted after the review.
