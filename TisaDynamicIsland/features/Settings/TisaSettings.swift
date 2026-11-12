//
//  TisaSettings.swift
//  TisaDynamicIsland
//
//  The Settings window in Tisa's own look: a dusk-colored sidebar with search, pages
//  grouped into Notch, Features and More, and an Overview that shows every feature on
//  one page with its switch. Each page keeps its settings (SettingsView.swift and
//  FeatureSettings.swift) under a header that says what the page is for.
//

import AIUsageKit
import Defaults
import Sparkle
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case overview
    case general, appearance, themes, home, hud
    case media, calendar, khmerCalendar, shelf, clipboard, downloads, photoBooth, fans, aiUsage, battery
    case shortcuts, advanced, about

    var id: String { rawValue }

    enum Group: String, CaseIterable {
        case start = ""
        case notch = "Notch"
        case features = "Features"
        case more = "More"
    }

    var group: Group {
        switch self {
        case .overview: return .start
        case .general, .appearance, .themes, .home, .hud: return .notch
        case .shortcuts, .advanced, .about: return .more
        default: return .features
        }
    }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .general: return "General"
        case .appearance: return "Appearance"
        case .themes: return "Themes"
        case .home: return "Home & Tabs"
        case .hud: return "HUDs"
        case .media: return "Music"
        case .calendar: return "Calendar"
        case .khmerCalendar: return "Khmer Calendar"
        case .shelf: return "Shelf"
        case .clipboard: return "Clipboard"
        case .downloads: return "Downloads"
        case .photoBooth: return "Photo Booth"
        case .fans: return "Fans"
        case .aiUsage: return "AI Usage"
        case .battery: return "Battery"
        case .shortcuts: return "Shortcuts"
        case .advanced: return "Advanced"
        case .about: return "About"
        }
    }

    /// One line under the page title, and on the Overview card.
    var subtitle: String {
        switch self {
        case .overview: return "Everything the notch can do, in one place"
        case .general: return "Menu bar icon, login, displays and how the notch opens"
        case .appearance: return "Colors, glass, album art and the music visualizer"
        case .themes: return "Dress up the notch: Web Hero, Football Legend, Animal City, your own picture…"
        case .home: return "Notch size, which tabs show, and your Home tiles"
        case .hud: return "Volume, brightness and keyboard light in the notch"
        case .media: return "Which music app it follows and its controls"
        case .calendar: return "Which Apple calendars and reminders show"
        case .khmerCalendar: return "Lunar dates, holidays, notes and routines"
        case .shelf: return "Drop files on the notch to keep them or AirDrop them"
        case .clipboard: return "A history of what you copied"
        case .downloads: return "Browser downloads with progress in the notch"
        case .photoBooth: return "Camera, photo strips and the Khmer stamp booth"
        case .fans: return "CPU heat, fan speed, Full Blast and Automatic"
        case .aiUsage: return "How much of your Claude, Codex and other AI plans is left"
        case .battery: return "Charge, charging and low battery in the notch"
        case .shortcuts: return "Keyboard shortcuts for the notch"
        case .advanced: return "Fine-tuning and reset"
        case .about: return "Version, updates and licenses"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .themes: return "theatermasks.fill"
        case .home: return "rectangle.3.group.fill"
        case .hud: return "speaker.wave.2.fill"
        case .media: return "music.note"
        case .calendar: return "calendar"
        case .khmerCalendar: return "moon.stars.fill"
        case .shelf: return "tray.full.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .photoBooth: return "camera.fill"
        case .fans: return "fan.fill"
        case .aiUsage: return "sparkles"
        case .battery: return "battery.100.bolt"
        case .shortcuts: return "command"
        case .advanced: return "slider.horizontal.3"
        case .about: return "info.circle.fill"
        }
    }

    /// Each page's icon tile has its own color, taken from the app icon's dusk.
    var colors: [Color] {
        switch self {
        case .overview, .home: return [TisaPalette.rose, TisaPalette.coral]
        case .general, .advanced: return [Color(white: 0.55), Color(white: 0.36)]
        case .appearance: return [TisaPalette.violet, TisaPalette.rose]
        case .themes: return [TisaPalette.gold, TisaPalette.rose]
        case .hud, .downloads: return [Color(red: 0.36, green: 0.56, blue: 1.0), Color(red: 0.30, green: 0.36, blue: 0.92)]
        case .media: return [Color(red: 1.0, green: 0.38, blue: 0.48), Color(red: 0.88, green: 0.18, blue: 0.36)]
        case .calendar: return [Color(red: 1.0, green: 0.46, blue: 0.36), Color(red: 0.92, green: 0.28, blue: 0.24)]
        case .khmerCalendar: return [TisaPalette.gold, Color(red: 0.86, green: 0.36, blue: 0.22)]
        case .shelf: return [TisaPalette.gold, Color(red: 0.93, green: 0.58, blue: 0.24)]
        case .clipboard: return [Color(red: 0.30, green: 0.82, blue: 0.76), Color(red: 0.16, green: 0.62, blue: 0.62)]
        case .photoBooth: return [TisaPalette.gold, TisaPalette.coral]
        case .fans: return [Color(red: 0.36, green: 0.82, blue: 0.98), Color(red: 0.20, green: 0.56, blue: 0.86)]
        case .aiUsage: return [TisaPalette.violet, Color(red: 0.36, green: 0.22, blue: 0.80)]
        case .battery: return [Color(red: 0.40, green: 0.88, blue: 0.50), Color(red: 0.20, green: 0.66, blue: 0.36)]
        case .shortcuts: return [Color(red: 0.58, green: 0.50, blue: 1.0), Color(red: 0.40, green: 0.34, blue: 0.86)]
        case .about: return [TisaPalette.plumLight, TisaPalette.plum]
        }
    }

    /// The switch that turns the whole feature on or off, for the Overview.
    var masterSwitch: Defaults.Key<Bool>? {
        switch self {
        case .home: return .tisaHome
        case .hud: return .hudReplacement
        case .shelf: return .tisaShelf
        case .clipboard: return .enableClipboardHistory
        case .downloads: return .enableDownloadListener
        case .photoBooth: return .enablePhotoBooth
        case .battery: return .showBatteryIndicator
        default: return nil
        }
    }

    /// Extra words search matches, beyond the title and subtitle.
    var keywords: String {
        switch self {
        case .overview: return "features all"
        case .general: return "menu bar login launch display screen hover haptic gesture swipe notch height size quit"
        case .appearance: return "color accent glass liquid visualizer album art shadow corner"
        case .themes: return "theme skin wallpaper picture background cartoon spider hero football ronaldo zootopia animal neon galaxy candy khmer glass crystal smoky liquid card tile colour color icons readable bianconeri blue red night"
        case .home: return "tabs widgets tiles stack portrait layout recent apps edit large standard"
        case .hud: return "volume brightness keyboard backlight osd progress"
        case .media: return "music player spotify apple music youtube controller now playing sneak peek"
        case .calendar: return "events reminders meeting join apple"
        case .khmerCalendar: return "khmer lunar moon buddhist holiday holy sila notes note schedule alert reminder routine routines habit streak get ready cambodia"
        case .shelf: return "files airdrop drag drop share"
        case .clipboard: return "copy paste history"
        case .downloads: return "progress safari chrome firefox browser"
        case .photoBooth: return "camera mirror khmer stamp strip photo"
        case .fans: return "temperature cpu gpu heat full blast automatic helper fan studio"
        case .aiUsage: return "claude codex cursor tokens limits usage reset weekly"
        case .battery: return "charging percentage low power"
        case .shortcuts: return "keyboard hotkeys keys"
        case .advanced: return "reset debug extra"
        case .about: return "version license gpl update credits"
        }
    }

    func matches(_ query: String) -> Bool {
        let words = query.lowercased().split(separator: " ")
        let text = "\(title) \(subtitle) \(keywords)".lowercased()
        return words.allSatisfy { text.contains($0) }
    }
}

enum TisaPalette {
    static let rose = Color(red: 0.96, green: 0.27, blue: 0.47)
    static let coral = Color(red: 1.0, green: 0.56, blue: 0.40)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.42)
    static let violet = Color(red: 0.55, green: 0.32, blue: 0.96)
    static let plum = Color(red: 0.30, green: 0.10, blue: 0.32)
    static let plumLight = Color(red: 0.55, green: 0.22, blue: 0.55)
    static let night = Color(red: 0.075, green: 0.055, blue: 0.095)
    static let sidebar = Color(red: 0.10, green: 0.07, blue: 0.12)
    static let card = Color.white.opacity(0.05)
    static let cardBorder = Color.white.opacity(0.08)
    static let secondary = Color(white: 0.62)
}

// MARK: - Window content

struct TisaSettingsView: View {
    let updaterController: SPUStandardUpdaterController?

    @State private var page: SettingsPage = .overview
    @State private var query = ""

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(page: $page, query: $query)
                .frame(width: 236)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(background)
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .tint(.effectiveAccent)
        .preferredColorScheme(.dark)
        .frame(minWidth: 820, minHeight: 560)
    }

    private var background: some View {
        ZStack {
            TisaPalette.night
            RadialGradient(colors: [TisaPalette.rose.opacity(0.16), .clear],
                           center: UnitPoint(x: 0.35, y: 0), startRadius: 0, endRadius: 520)
            RadialGradient(colors: [TisaPalette.violet.opacity(0.10), .clear],
                           center: UnitPoint(x: 1, y: 1), startRadius: 0, endRadius: 480)
        }
        .ignoresSafeArea()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(page: page)
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 4)
            pageBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .id(page)
        .transition(.opacity)
    }

    @ViewBuilder
    private var pageBody: some View {
        switch page {
        case .overview: SettingsOverview(page: $page)
        case .general: GeneralSettings()
        case .appearance: Appearance()
        case .themes: ThemesSettings()
        case .home: HomeSettings()
        case .hud: HUD()
        case .media: Media()
        case .calendar: CalendarSettings()
        case .khmerCalendar: KhmerCalendarSettings()
        case .shelf: Shelf()
        case .clipboard: ClipboardSettings()
        case .downloads: DownloadsSettings()
        case .photoBooth: PhotoBoothSettings()
        case .fans: FansSettings()
        case .aiUsage: AIUsageSettings()
        case .battery: Charge()
        case .shortcuts: Shortcuts()
        case .advanced: Advanced()
        case .about:
            About(updaterController: updaterController
                ?? SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil))
        }
    }
}

/// A rounded tile with the page's symbol on its gradient.
struct SettingsIcon: View {
    let page: SettingsPage
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: page.symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(LinearGradient(colors: page.colors, startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
    }
}

private struct PageHeader: View {
    let page: SettingsPage

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(page: page, size: 44)
                .shadow(color: page.colors[0].opacity(0.45), radius: 12, y: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title)
                    .font(.system(size: 22, weight: .bold))
                Text(page.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(TisaPalette.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Sidebar

private struct SettingsSidebar: View {
    @Binding var page: SettingsPage
    @Binding var query: String
    @FocusState private var searching: Bool

    private var results: [SettingsPage] {
        query.isEmpty ? SettingsPage.allCases : SettingsPage.allCases.filter { $0.matches(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Room for the window's traffic lights.
            Color.clear.frame(height: 22)
            brand
            searchField
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    if query.isEmpty {
                        ForEach(SettingsPage.Group.allCases, id: \.self) { group in
                            if !group.rawValue.isEmpty {
                                Text(group.rawValue.uppercased())
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundStyle(TisaPalette.secondary.opacity(0.8))
                                    .padding(.horizontal, 10)
                                    .padding(.top, 12)
                                    .padding(.bottom, 3)
                            }
                            ForEach(SettingsPage.allCases.filter { $0.group == group }) { item in
                                row(item)
                            }
                        }
                    } else if results.isEmpty {
                        Text("Nothing matches “\(query)”")
                            .font(.system(size: 11))
                            .foregroundStyle(TisaPalette.secondary)
                            .padding(10)
                    } else {
                        ForEach(results) { item in
                            row(item)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Tisa Dynamic Island", systemImage: "power")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TisaPalette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .background(
            TisaPalette.sidebar.opacity(0.85)
                .overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1) }
                .ignoresSafeArea()
        )
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 0) {
                Text("Tisa Dynamic Island")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Text("Settings")
                    .font(.system(size: 11))
                    .foregroundStyle(TisaPalette.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TisaPalette.secondary)
            TextField("Search settings", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($searching)
                .onSubmit {
                    if let first = results.first { page = first }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TisaPalette.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(searching ? Color.effectiveAccent.opacity(0.7) : Color.white.opacity(0.06)))
    }

    private func row(_ item: SettingsPage) -> some View {
        let selected = item == page
        return Button {
            withAnimation(.smooth(duration: 0.18)) { page = item }
        } label: {
            HStack(spacing: 9) {
                SettingsIcon(page: item, size: 22)
                Text(item.title)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.white : Color(white: 0.86))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .frame(height: 30)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [Color.effectiveAccent.opacity(0.42), Color.effectiveAccent.opacity(0.22)],
                                             startPoint: .leading, endPoint: .trailing))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.effectiveAccent.opacity(0.45), lineWidth: 1))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overview

private struct SettingsOverview: View {
    @Binding var page: SettingsPage
    @ObservedObject private var fans = FanStudio.shared.environment
    @Default(.homeBoxes) private var homeBoxes
    @Default(.notchTabs) private var notchTabs

    private let columns = [GridItem(.adaptive(minimum: 250), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                status
                section("Notch", pages: [.general, .appearance, .themes, .home, .hud])
                section("Features", pages: [.media, .calendar, .khmerCalendar, .shelf, .clipboard, .downloads, .photoBooth, .fans, .aiUsage, .battery])
                section("More", pages: [.shortcuts, .advanced, .about])
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        }
    }

    /// Three numbers at a glance.
    private var status: some View {
        HStack(spacing: 12) {
            statusTile("On Home", "\(homeBoxes.count) tiles", symbol: "rectangle.3.group.fill", target: .home)
            statusTile("Tabs", "\(NotchTab.visible.count + 1) of \(NotchTab.maxVisible + 1)", symbol: "square.split.2x1.fill", target: .home)
            statusTile("Fan control", fans.canControlFans ? "Ready" : "Not set up", symbol: "fan.fill", target: .fans,
                       warn: !fans.canControlFans)
            statusTile("CPU", fans.temperatureText(fans.cpuTemperature), symbol: "thermometer.medium", target: .fans)
        }
    }

    private func statusTile(_ title: String, _ value: String, symbol: String, target: SettingsPage, warn: Bool = false) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.18)) { page = target }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: symbol)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(TisaPalette.secondary)
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(warn ? HomeStyle.warning : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(TisaPalette.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(TisaPalette.cardBorder))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func section(_ title: String, pages: [SettingsPage]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(TisaPalette.secondary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(pages) { item in
                    FeatureCard(page: item, status: status(of: item)) {
                        withAnimation(.smooth(duration: 0.18)) { page = item }
                    }
                }
            }
        }
    }

    private func status(of item: SettingsPage) -> String? {
        switch item {
        case .fans: return fans.canControlFans ? "Ready" : "Set up"
        case .themes: return NotchTheme.current.title
        case .aiUsage:
            let count = AIUsageCenter.shared.providers.count
            return count == 0 ? nil : "\(count) tool\(count == 1 ? "" : "s")"
        default: return nil
        }
    }
}

/// A feature on the Overview: its icon, what it does, its switch, and a way in.
private struct FeatureCard: View {
    let page: SettingsPage
    let status: String?
    let open: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            SettingsIcon(page: page, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(page.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(page.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(TisaPalette.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 6) {
                if let key = page.masterSwitch {
                    Defaults.Toggle(key: key) { EmptyView() }
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .help("Turn \(page.title) on or off")
                } else if let status {
                    Text(status)
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(TisaPalette.secondary.opacity(hovering ? 1 : 0.5))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(hovering ? Color.white.opacity(0.08) : TisaPalette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(hovering ? page.colors[0].opacity(0.5) : TisaPalette.cardBorder)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(perform: open)
        .onHover { inside in withAnimation(.smooth(duration: 0.15)) { hovering = inside } }
        .help("Open \(page.title) settings")
    }
}
