//
//  NotchTabs.swift
//  TisaDynamicIsland
//
//  Which tabs the notch shows, and in what order. Home is always first; the rest are
//  picked in Edit Tabs (hold or right-click the tab bar). Only as many fit as there is
//  room for next to the camera: 7 in the Large notch, 6 in Standard.
//

import Defaults
import SwiftUI

enum NotchTab: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case apps
    case calendar
    case shelf
    case clipboard
    case downloads
    case aiUsage
    case fans
    case photoBooth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apps: return "Apps"
        case .calendar: return "Calendar"
        case .shelf: return "Shelf"
        case .clipboard: return "Clipboard"
        case .downloads: return "Downloads"
        case .aiUsage: return "AI Usage"
        case .fans: return "Fans"
        case .photoBooth: return "Photo Booth"
        }
    }

    var icon: String {
        switch self {
        case .apps: return "square.grid.2x2.fill"
        case .calendar: return "calendar"
        case .shelf: return "tray.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .aiUsage: return "sparkles"
        case .fans: return "fan.fill"
        case .photoBooth: return "camera.fill"
        }
    }

    var view: NotchViews {
        switch self {
        case .apps: return .apps
        case .calendar: return .calendar
        case .shelf: return .shelf
        case .clipboard: return .clipboard
        case .downloads: return .downloads
        case .aiUsage: return .aiUsage
        case .fans: return .fans
        case .photoBooth: return .photoBooth
        }
    }

    /// Shelf, Clipboard and Photo Booth can be turned off as features in Settings.
    var isAvailable: Bool {
        switch self {
        case .shelf: return Defaults[.tisaShelf]
        case .clipboard: return Defaults[.enableClipboardHistory]
        case .photoBooth: return Defaults[.enablePhotoBooth]
        default: return true
        }
    }

    var unavailableReason: String? {
        switch self {
        case .shelf where !isAvailable: return "Shelf is off in Settings"
        case .clipboard where !isAvailable: return "Clipboard history is off in Settings"
        case .photoBooth where !isAvailable: return "Photo Booth is off in Settings"
        default: return nil
        }
    }

    /// Tabs besides Home that fit next to the camera.
    static var maxVisible: Int { Defaults[.largeNotch] ? 6 : 5 }

    static let defaultOrder: [NotchTab] = [.apps, .shelf, .clipboard, .aiUsage, .fans, .photoBooth]

    /// The tabs the bar shows now, in order.
    static var visible: [NotchTab] {
        Array(Defaults[.notchTabs].filter(\.isAvailable).prefix(maxVisible))
    }
}

@MainActor
final class TabBarEditor: ObservableObject {
    static let shared = TabBarEditor()

    @Published private(set) var isEditing = false

    private init() {}

    /// Editing holds the notch open, like Edit Home.
    func setEditing(_ editing: Bool) {
        guard editing != isEditing else { return }
        if editing { HomeEditor.shared.setEditing(false) }
        isEditing = editing
        if editing {
            HomeHaptics.tap()
            SharingStateManager.shared.beginInteraction()
        } else {
            SharingStateManager.shared.endInteraction()
        }
    }
}
