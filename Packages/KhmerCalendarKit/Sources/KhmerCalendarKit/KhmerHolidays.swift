//
//  KhmerHolidays.swift
//  KhmerCalendarKit
//
//  Cambodian holidays and observances.
//
//  This list is NOT official. The government sets each year's public holidays by
//  sub-decree, moves substitute days, and now and then adds or drops one. To update it,
//  edit the two tables below: `fixed` for Gregorian dates and `lunar` for lunar dates.
//

import Foundation

public struct KhmerHoliday: Equatable, Sendable {
    public let khmerName: String
    public let englishName: String
    /// False for days that are observed but are not a day off, such as Meak Bochea.
    public let isDayOff: Bool
}

public extension KhmerCalendar {
    /// Holidays on a day, or an empty list.
    static func holidays(_ key: DayKey) -> [KhmerHoliday] {
        var found = HolidayTable.fixed.filter { $0.month == key.month && $0.day == key.day }.map(\.holiday)

        let year = Chhankitek.yearInfo(key.year)
        if key >= year.newYear && key < year.newYear.adding(days: year.newYearLength) {
            found.append(HolidayTable.newYear)
        }

        let lunar = KhmerCalendar.date(key)
        found += HolidayTable.lunar
            .filter { $0.month == lunar.month && $0.phase == lunar.phase && $0.day == lunar.lunarDay }
            .map(\.holiday)
        return found
    }
}

enum HolidayTable {
    static let newYear = KhmerHoliday(khmerName: "ចូលឆ្នាំខ្មែរ", englishName: "Khmer New Year", isDayOff: true)

    static let fixed: [(month: Int, day: Int, holiday: KhmerHoliday)] = [
        (1, 1, .init(khmerName: "ចូលឆ្នាំសកល", englishName: "International New Year", isDayOff: true)),
        (1, 7, .init(khmerName: "ទិវាជ័យជម្នះលើរបបប្រល័យពូជសាសន៍", englishName: "Victory over Genocide Day", isDayOff: true)),
        (3, 8, .init(khmerName: "ទិវានារីអន្តរជាតិ", englishName: "International Women's Day", isDayOff: true)),
        (5, 1, .init(khmerName: "ទិវាពលកម្មអន្តរជាតិ", englishName: "International Labour Day", isDayOff: true)),
        (5, 14, .init(khmerName: "ចម្រើនព្រះជន្ម ព្រះមហាក្សត្រ", englishName: "King's Birthday", isDayOff: true)),
        (6, 18, .init(khmerName: "ចម្រើនព្រះជន្ម ព្រះវររាជមាតា", englishName: "Queen Mother's Birthday", isDayOff: true)),
        (9, 24, .init(khmerName: "ទិវាប្រកាសរដ្ឋធម្មនុញ្ញ", englishName: "Constitution Day", isDayOff: true)),
        (10, 15, .init(khmerName: "ទិវាគោរពព្រះវិញ្ញាណក្ខន្ធ ព្រះបរមរតនកោដ្ឋ", englishName: "Commemoration Day of the King Father", isDayOff: true)),
        (10, 29, .init(khmerName: "គ្រងព្រះបរមរាជសម្បត្តិ", englishName: "Coronation Day", isDayOff: true)),
        (11, 9, .init(khmerName: "បុណ្យឯករាជ្យជាតិ", englishName: "Independence Day", isDayOff: true)),
        (12, 29, .init(khmerName: "ទិវាសន្តិភាព", englishName: "Peace Day", isDayOff: true))
    ]

    private static let pchumBen = KhmerHoliday(khmerName: "បុណ្យភ្ជុំបិណ្ឌ", englishName: "Pchum Ben", isDayOff: true)
    private static let waterFestival = KhmerHoliday(khmerName: "បុណ្យអុំទូក", englishName: "Water Festival", isDayOff: true)

    static let lunar: [(month: KhmerMonth, phase: MoonPhase, day: Int, holiday: KhmerHoliday)] = [
        (.meakh, .keit, 15, .init(khmerName: "មាឃបូជា", englishName: "Meak Bochea", isDayOff: false)),
        (.pisakh, .keit, 15, .init(khmerName: "វិសាខបូជា", englishName: "Visak Bochea", isDayOff: true)),
        (.pisakh, .roach, 4, .init(khmerName: "ព្រះរាជពិធីច្រត់ព្រះនង្គ័ល", englishName: "Royal Ploughing Ceremony", isDayOff: true)),
        (.photrobot, .roach, 14, pchumBen),
        (.photrobot, .roach, 15, pchumBen),
        (.assoch, .keit, 1, pchumBen),
        (.kadeuk, .keit, 14, waterFestival),
        (.kadeuk, .keit, 15, waterFestival),
        (.kadeuk, .roach, 1, waterFestival)
    ]
}
