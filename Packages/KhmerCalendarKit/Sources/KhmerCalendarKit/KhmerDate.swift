//
//  KhmerDate.swift
//  KhmerCalendarKit
//
//  One day in the Khmer lunar calendar.
//

import Foundation

public enum MoonPhase: Sendable {
    /// កើត, the waxing half: days 1 to 15.
    case keit
    /// រោច, the waning half: days 1 to 14 or 15.
    case roach

    public var name: String {
        self == .keit ? "កើត" : "រោច"
    }
}

/// The lunar months. A leap-month year has បឋមាសាឍ and ទុតិយាសាឍ in place of អាសាឍ.
public enum KhmerMonth: Int, CaseIterable, Sendable {
    case migasir, boss, meakh, phalkun, chetr, pisakh, jesth, asadh, srap, photrobot, assoch, kadeuk
    case pathamasadh, tutiyasadh

    public var name: String {
        ["មិគសិរ", "បុស្ស", "មាឃ", "ផល្គុន", "ចេត្រ", "ពិសាខ", "ជេស្ឋ", "អាសាឍ",
         "ស្រាពណ៍", "ភទ្របទ", "អស្សុជ", "កត្ដិក", "បឋមាសាឍ", "ទុតិយាសាឍ"][rawValue]
    }
}

public enum AnimalYear: Int, CaseIterable, Sendable {
    case chhut, chlov, khal, thos, rong, masagn, momee, momae, vok, roka, cho, kor

    public var name: String {
        ["ជូត", "ឆ្លូវ", "ខាល", "ថោះ", "រោង", "ម្សាញ់", "មមី", "មមែ", "វក", "រកា", "ច", "កុរ"][rawValue]
    }

    public var latinName: String {
        ["Rat", "Ox", "Tiger", "Rabbit", "Dragon", "Snake", "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig"][rawValue]
    }
}

public struct KhmerDate: Equatable, Sendable {
    /// 1...15 within the phase.
    public let lunarDay: Int
    public let phase: MoonPhase
    public let month: KhmerMonth
    /// ព.ស. It changes on ១ រោច ខែពិសាខ, the day after Visak Bochea.
    public let buddhistYear: Int
    /// It changes on the first day of Khmer New Year.
    public let animalYear: AnimalYear
    /// ថ្ងៃសីល: ៨ កើត, ១៥ កើត, ៨ រោច and the last day of the month.
    public let isHolyDay: Bool
}

public extension KhmerFormat {
    /// "៣កើត", or "3កើត" in Latin: the calendar's own words stay Khmer.
    static func lunarDay(_ date: KhmerDate, script: CalendarScript = .khmer) -> String {
        numerals(date.lunarDay, script: script) + date.phase.name
    }

    /// "៣ កើត ខែកត្ដិក ឆ្នាំមមី ព.ស. ២៥៧០", or "3 កើត · ខែកត្ដិក · Year of the Horse · BE 2570".
    static func lunarLine(_ date: KhmerDate, script: CalendarScript = .khmer) -> String {
        switch script {
        case .khmer:
            return "\(numerals(date.lunarDay)) \(date.phase.name) ខែ\(date.month.name) ឆ្នាំ\(date.animalYear.name) ព.ស. \(numerals(date.buddhistYear))"
        case .latin:
            return "\(date.lunarDay) \(date.phase.name) · ខែ\(date.month.name) · Year of the \(date.animalYear.latinName) · BE \(date.buddhistYear)"
        }
    }
}
