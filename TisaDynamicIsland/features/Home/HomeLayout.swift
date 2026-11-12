//
//  HomeLayout.swift
//  TisaDynamicIsland
//
//  The Home grid: tiles of different sizes, each showing one widget or a stack of
//  widgets you swipe through. The layout is saved in Defaults.
//

import Defaults
import Foundation

enum HomeWidget: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case nowPlaying
    case upNext
    case today
    case recentApps
    case quick
    case clipboard
    case downloads
    case battery
    case fans
    case aiUsage
    case dropZone
    case mirror

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: return "Now playing"
        case .upNext: return "Up next"
        case .today: return "Today"
        case .recentApps: return "Recent apps"
        case .quick: return "Quick"
        case .clipboard: return "Recent copies"
        case .downloads: return "Downloads"
        case .battery: return "Battery"
        case .fans: return "Fans"
        case .aiUsage: return "AI Usage"
        case .dropZone: return "Drop zone"
        case .mirror: return "Mirror view"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: return "music.note"
        case .upNext: return "calendar"
        case .today: return "list.bullet"
        case .recentApps: return "square.grid.2x2"
        case .quick: return "switch.2"
        case .clipboard: return "doc.on.doc"
        case .downloads: return "arrow.down.circle"
        case .battery: return "battery.75percent"
        case .fans: return "fan"
        case .aiUsage: return "sparkles"
        case .dropZone: return "tray.and.arrow.down"
        case .mirror: return "web.camera"
        }
    }

    /// The sizes this widget comes in, smallest first.
    var sizes: [HomeBoxSize] {
        switch self {
        case .nowPlaying: return [.small, .wide, .tall, .medium, .large, .extraLarge]
        case .upNext: return [.wide, .tall, .medium, .large]
        case .today: return [.tall, .medium, .large]
        case .recentApps: return [.wide, .tall, .medium, .large]
        case .quick: return [.small, .wide, .tall]
        case .clipboard: return [.wide, .tall, .medium, .large]
        case .downloads: return [.wide, .tall, .medium, .large]
        case .battery: return [.small, .wide, .tall]
        case .fans: return [.small, .wide, .tall, .medium]
        case .aiUsage: return [.small, .wide, .tall, .medium, .large]
        case .dropZone: return [.small, .wide, .tall, .medium]
        case .mirror: return [.tall, .medium, .large]
        }
    }

    var defaultSize: HomeBoxSize {
        switch self {
        case .nowPlaying, .today, .mirror: return .medium
        case .quick, .battery, .fans, .dropZone: return .small
        default: return .wide
        }
    }

    /// The nearest size this widget offers, for when it replaces another widget.
    func closestSize(to size: HomeBoxSize) -> HomeBoxSize {
        if sizes.contains(size) { return size }
        return sizes.min { abs($0.cells - size.cells) < abs($1.cells - size.cells) } ?? defaultSize
    }

    /// One line for Edit Home.
    var summary: String {
        switch self {
        case .nowPlaying: return "Song, controls, progress"
        case .upNext: return "Next event, Join, later today"
        case .today: return "Events and reminders"
        case .recentApps: return "Your latest apps"
        case .quick: return "Mic, Mirror and a live bar"
        case .clipboard: return "Last things you copied"
        case .downloads: return "Progress and new files"
        case .battery: return "Charge and time left"
        case .fans: return "CPU heat, fan speed, Auto or Full Blast"
        case .aiUsage: return "Claude, Codex, Cursor limits"
        case .dropZone: return "Drop files for the Shelf"
        case .mirror: return "Camera preview"
        }
    }
}

/// A tile's size on the Home grid, in cells (columns × rows). Home is two rows tall; Small
/// and Wide tiles are one row, so two of them stack where one tall tile would go.
enum HomeBoxSize: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case small
    case wide
    case tall
    case medium
    case large
    case extraLarge

    var id: String { rawValue }

    var columns: Int {
        switch self {
        case .small, .tall: return 1
        case .wide, .medium: return 2
        case .large: return 3
        case .extraLarge: return 4
        }
    }

    var rows: Int {
        switch self {
        case .small, .wide: return 1
        case .tall, .medium, .large, .extraLarge: return 2
        }
    }

    /// One row high: widgets show their compact version.
    var isCompact: Bool { rows == 1 }

    var label: String { "\(columns)×\(rows)" }

    var title: String {
        switch self {
        case .small: return "Small"
        case .wide: return "Wide"
        case .tall: return "Portrait"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra large"
        }
    }

    var cells: Int { columns * rows }
}

struct HomeBox: Codable, Hashable, Identifiable, Defaults.Serializable {
    var id = UUID()
    var widget: HomeWidget
    var size: HomeBoxSize
    /// More widgets sharing this tile, after `widget`. Swipe sideways on the tile to switch.
    var stack: [HomeWidget] = []

    /// Every widget in the tile, in order.
    var members: [HomeWidget] { [widget] + stack }

    var isStack: Bool { !stack.isEmpty }

    /// The sizes every widget in the tile comes in, smallest first.
    var sizes: [HomeBoxSize] {
        widget.sizes.filter { size in stack.allSatisfy { $0.sizes.contains(size) } }
    }

    /// Whether `other` comes in this tile's size, so it can join the stack.
    func canStack(_ other: HomeWidget) -> Bool {
        !members.contains(other) && other.sizes.contains(size)
    }

    /// This tile showing just one of its widgets, for drawing it.
    func showing(_ member: HomeWidget) -> HomeBox {
        var box = self
        box.widget = member
        box.stack = []
        return box
    }

    /// Swaps one widget in the tile for another.
    mutating func replace(_ member: HomeWidget, with other: HomeWidget) {
        if widget == member {
            widget = other
        } else if let index = stack.firstIndex(of: member) {
            stack[index] = other
        }
    }

    /// Takes a widget out of a stack; the next one moves up if it was the first.
    mutating func remove(_ member: HomeWidget) {
        guard isStack else { return }
        if widget == member {
            widget = stack.removeFirst()
        } else {
            stack.removeAll { $0 == member }
        }
    }

    init(id: UUID = UUID(), widget: HomeWidget, size: HomeBoxSize, stack: [HomeWidget] = []) {
        self.id = id
        self.widget = widget
        self.size = size
        self.stack = stack
    }

    private enum CodingKeys: String, CodingKey {
        case id, widget, size, stack
    }

    /// Layouts saved before stacks existed have no `stack`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        widget = try container.decode(HomeWidget.self, forKey: .widget)
        size = try container.decode(HomeBoxSize.self, forKey: .size)
        stack = try container.decodeIfPresent([HomeWidget].self, forKey: .stack) ?? []
    }

    static let defaultLayout: [HomeBox] = [
        HomeBox(widget: .nowPlaying, size: .medium),
        HomeBox(widget: .upNext, size: .wide),
        HomeBox(widget: .aiUsage, size: .wide),
        HomeBox(widget: .fans, size: .small),
        HomeBox(widget: .battery, size: .small),
        HomeBox(widget: .quick, size: .tall),
    ]
}

extension HomeBox {
    /// Home used to be one row of up to three full-height boxes sized S/M/L/XL. On the grid
    /// those sizes mean something else, so convert them once: narrow boxes become Tall, the
    /// rest Medium (Extra large becomes Large), then shrink the biggest until all fit.
    static func migrateToGridIfNeeded() {
        guard !Defaults[.homeGridMigrated] else { return }
        Defaults[.homeGridMigrated] = true
        guard Defaults[.homeBoxes] != defaultLayout else { return }
        var boxes = Defaults[.homeBoxes].map { box -> HomeBox in
            var box = box
            let wanted: HomeBoxSize
            switch box.size {
            case .small: wanted = .tall
            case .extraLarge: wanted = .large
            default: wanted = .medium
            }
            box.size = box.widget.closestSize(to: wanted)
            return box
        }
        let columns = HomeGrid.columns(largeNotch: Defaults[.largeNotch])
        while !HomeGrid.fits(boxes, columns: columns),
              let index = boxes.indices.filter({ boxes[$0].widget.sizes.first != boxes[$0].size })
                .max(by: { boxes[$0].size.cells < boxes[$1].size.cells }) {
            let sizes = boxes[index].widget.sizes
            if let current = sizes.firstIndex(of: boxes[index].size), current > 0 {
                boxes[index].size = sizes[current - 1]
            } else {
                boxes[index].size = sizes[0]
            }
        }
        Defaults[.homeBoxes] = boxes
    }
}

/// Where each tile sits on the Home grid. Tiles are placed in order into the first free spot,
/// going down each column then across, so small tiles pair up in a column.
struct HomeGrid {
    static let rows = 2

    struct Slot: Equatable {
        let column: Int
        let row: Int
        let size: HomeBoxSize
    }

    let columns: Int
    private(set) var slots: [UUID: Slot] = [:]
    /// Tiles that didn't fit, in order.
    private(set) var overflow: [UUID] = []

    /// Six columns in the Large notch, five in Standard.
    static func columns(largeNotch: Bool) -> Int { largeNotch ? 6 : 5 }

    init(_ boxes: [HomeBox], columns: Int) {
        self.columns = columns
        var taken = Array(repeating: Array(repeating: false, count: Self.rows), count: columns)
        for box in boxes {
            let size = box.size
            var placed = false
            search: for column in 0..<columns {
                for row in 0..<Self.rows {
                    guard column + size.columns <= columns, row + size.rows <= Self.rows else { continue }
                    let free = (column..<(column + size.columns)).allSatisfy { c in
                        (row..<(row + size.rows)).allSatisfy { !taken[c][$0] }
                    }
                    guard free else { continue }
                    for c in column..<(column + size.columns) {
                        for r in row..<(row + size.rows) { taken[c][r] = true }
                    }
                    slots[box.id] = Slot(column: column, row: row, size: size)
                    placed = true
                    break search
                }
            }
            if !placed { overflow.append(box.id) }
        }
    }

    var fitsAll: Bool { overflow.isEmpty }

    static func fits(_ boxes: [HomeBox], columns: Int) -> Bool {
        HomeGrid(boxes, columns: columns).fitsAll
    }

    /// The tile's frame for a grid `total` points wide and tall, with `gap` between cells.
    func frame(of id: UUID, in total: CGSize, gap: CGFloat) -> CGRect? {
        guard let slot = slots[id] else { return nil }
        let unit = Self.unit(in: total, columns: columns, gap: gap)
        return CGRect(
            x: CGFloat(slot.column) * (unit.width + gap),
            y: CGFloat(slot.row) * (unit.height + gap),
            width: CGFloat(slot.size.columns) * unit.width + CGFloat(slot.size.columns - 1) * gap,
            height: CGFloat(slot.size.rows) * unit.height + CGFloat(slot.size.rows - 1) * gap
        )
    }

    static func unit(in total: CGSize, columns: Int, gap: CGFloat) -> CGSize {
        CGSize(
            width: max(0, (total.width - gap * CGFloat(columns - 1)) / CGFloat(columns)),
            height: max(0, (total.height - gap * CGFloat(rows - 1)) / CGFloat(rows))
        )
    }
}

/// The buttons in the Quick box.
enum HomeQuickTile: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case mic
    case mirror
    case photoBooth
    case shelf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mic: return "Mic"
        case .mirror: return "Mirror"
        case .photoBooth: return "Booth"
        case .shelf: return "Shelf"
        }
    }

    var symbol: String {
        switch self {
        case .mic: return "mic"
        case .mirror: return "web.camera"
        case .photoBooth: return "camera"
        case .shelf: return "tray"
        }
    }

    /// These already have a tab in the top bar, so Edit Home suggests removing them.
    var isAlsoATab: Bool { self == .photoBooth || self == .shelf }
}
