//
//  KhmerCalendarModel.swift
//  TisaDynamicIsland
//
//  What the Khmer calendar tab is showing: the month on the left, the picked day on the
//  right. The month's lunar dates are worked out once, when the month changes.
//

import EventKit
import Foundation
import KhmerCalendarKit

/// Which routine the full-width routine editor is open on.
enum RoutineEditorTarget: Identifiable {
    case new
    case edit(Routine)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let routine): return routine.id.uuidString
        }
    }

    var routine: Routine? {
        if case .edit(let routine) = self { return routine }
        return nil
    }
}

@MainActor
final class KhmerCalendarModel: ObservableObject {
    /// One model for the app, so Settings can open a routine in the Calendar tab.
    static let shared = KhmerCalendarModel()

    struct Cell: Identifiable {
        let grid: GridDay
        let khmer: KhmerDate
        let holidays: [KhmerHoliday]

        var id: DayKey { grid.key }
        var key: DayKey { grid.key }
    }

    @Published private(set) var today: DayKey
    @Published private(set) var selected: DayKey
    @Published private(set) var shownYear: Int
    @Published private(set) var shownMonth: Int
    @Published private(set) var cells: [Cell] = []
    /// Apple Calendar events on the selected day.
    @Published private(set) var events: [EventModel] = []
    /// Set while the routine editor covers the tab.
    @Published var routineEditor: RoutineEditorTarget?

    private var dayChangeObserver: NSObjectProtocol?

    init() {
        let today = DayKey(Date(), calendar: .current)
        self.today = today
        selected = today
        shownYear = today.year
        shownMonth = today.month
        rebuildCells()
        loadEvents()
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshToday() }
        }
    }

    deinit {
        if let dayChangeObserver { NotificationCenter.default.removeObserver(dayChangeObserver) }
    }

    var selectedCell: Cell {
        cells.first { $0.key == selected }
            ?? Cell(grid: GridDay(key: selected, inMonth: true, isSunday: selected.weekday == 7),
                    khmer: KhmerCalendar.date(selected), holidays: KhmerCalendar.holidays(selected))
    }

    /// "វិច្ឆិកា ២០២៦ · ព.ស. ២៥៧០", with the Buddhist year of the middle of the month.
    func monthTitle(_ script: CalendarScript) -> String {
        let middle = KhmerCalendar.date(DayKey(year: shownYear, month: shownMonth, day: 15))
        return KhmerFormat.monthTitle(year: shownYear, month: shownMonth, buddhistYear: middle.buddhistYear, script: script)
    }

    var isShowingToday: Bool {
        selected == today && shownYear == today.year && shownMonth == today.month
    }

    func refreshToday() {
        let now = DayKey(Date(), calendar: .current)
        if now != today { today = now }
    }

    func select(_ day: DayKey) {
        selected = day
        show(year: day.year, month: day.month)
        loadEvents()
    }

    func showPrevious() {
        shownMonth == 1 ? show(year: shownYear - 1, month: 12) : show(year: shownYear, month: shownMonth - 1)
    }

    func showNext() {
        shownMonth == 12 ? show(year: shownYear + 1, month: 1) : show(year: shownYear, month: shownMonth + 1)
    }

    func goToToday() {
        refreshToday()
        select(today)
    }

    private func show(year: Int, month: Int) {
        guard year != shownYear || month != shownMonth else { return }
        shownYear = year
        shownMonth = month
        rebuildCells()
    }

    private func rebuildCells() {
        cells = MonthGrid.days(year: shownYear, month: shownMonth).map {
            Cell(grid: $0, khmer: KhmerCalendar.date($0.key), holidays: KhmerCalendar.holidays($0.key))
        }
    }

    private func loadEvents() {
        let day = selected
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess,
              let start = Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day)),
              let end = Calendar.current.date(byAdding: .day, value: 1, to: start)
        else {
            events = []
            return
        }
        Task {
            let found = await CalendarManager.shared.events(from: start, to: end)
            // The user may have picked another day while this was loading.
            guard day == selected else { return }
            events = found.filter {
                if case .reminder = $0.type { return false }
                return true
            }.sorted { $0.start < $1.start }
        }
    }
}
