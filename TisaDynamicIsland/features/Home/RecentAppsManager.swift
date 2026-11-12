//
//  RecentAppsManager.swift
//  TisaDynamicIsland
//
//  Remembers the apps you switch to (macOS posts a notification each time) so
//  Home and the Apps tab can open them again in one click. Kept apps stay first;
//  hidden apps never show. The list is saved in Defaults and stays on this Mac.
//

import AppKit
import Combine
import Defaults

struct RecentAppRecord: Codable, Hashable, Defaults.Serializable {
    let bundleID: String
    var lastUsed: Date
    var uses: Int
}

struct RecentApp: Identifiable, Equatable {
    let bundleID: String
    let name: String
    let url: URL
    let icon: NSImage
    let isRunning: Bool
    let isKept: Bool

    var id: String { bundleID }
}

@MainActor
final class RecentAppsManager: ObservableObject {
    static let shared = RecentAppsManager()

    @Published private(set) var records: [RecentAppRecord] = []
    @Published private(set) var runningIDs: Set<String> = []
    @Published private(set) var keptIDs: [String] = Defaults[.pinnedApps]

    private var observers: [NSObjectProtocol] = []
    private var iconCache: [String: NSImage] = [:]
    private var urlCache: [String: URL] = [:]
    private static let maxRecords = 60

    private init() {}

    func start() {
        guard observers.isEmpty else { return }
        records = Defaults[.recentAppsLog]
        refreshRunning()
        if records.isEmpty {
            seedFromRunningApps()
        }

        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
                .flatMap { $0.activationPolicy == .regular ? $0.bundleIdentifier : nil }
            Task { @MainActor in
                self?.recordUse(of: bundleID)
            }
        })
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshRunning()
                }
            })
        }
    }

    // MARK: - Lists

    /// Kept apps first, then the rest by last use (or by how often they're used).
    func apps(limit: Int, sortByUse: Bool = false) -> [RecentApp] {
        let kept = keptApps()
        return Array((kept + recentApps(sortByUse: sortByUse, excluding: Set(kept.map(\.bundleID)))).prefix(limit))
    }

    func keptApps() -> [RecentApp] {
        keptIDs.compactMap { app(for: $0) }
    }

    func recentApps(sortByUse: Bool, excluding: Set<String> = []) -> [RecentApp] {
        let hidden = Set(Defaults[.hiddenRecentApps])
        let sorted = sortByUse
            ? records.sorted { ($0.uses, $0.lastUsed) > ($1.uses, $1.lastUsed) }
            : records.sorted { $0.lastUsed > $1.lastUsed }
        return sorted
            .filter { !hidden.contains($0.bundleID) && !excluding.contains($0.bundleID) }
            .compactMap { app(for: $0.bundleID) }
    }

    // MARK: - Actions

    /// Works like a click on the Dock icon: brings the app forward, and an app that's open
    /// with no windows makes a new one. (`NSRunningApplication.activate()` can't do this: macOS
    /// ignores it from the notch, which never becomes the active app, and it doesn't reopen windows.)
    func open(_ app: RecentApp) {
        NSApp.yieldActivation(toApplicationWithBundleIdentifier: app.bundleID)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration)
    }

    func toggleKeep(_ app: RecentApp) {
        if let index = keptIDs.firstIndex(of: app.bundleID) {
            keptIDs.remove(at: index)
        } else {
            keptIDs.append(app.bundleID)
        }
        Defaults[.pinnedApps] = keptIDs
    }

    func hide(_ app: RecentApp) {
        var hidden = Defaults[.hiddenRecentApps]
        if !hidden.contains(app.bundleID) { hidden.append(app.bundleID) }
        Defaults[.hiddenRecentApps] = hidden
        keptIDs.removeAll { $0 == app.bundleID }
        Defaults[.pinnedApps] = keptIDs
        objectWillChange.send()
    }

    func quit(_ app: RecentApp) {
        NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).forEach { $0.terminate() }
    }

    func showHiddenApps() {
        Defaults[.hiddenRecentApps] = []
        objectWillChange.send()
    }

    // MARK: - Private

    private func recordUse(of bundleID: String?) {
        guard let bundleID, bundleID != Bundle.main.bundleIdentifier else { return }
        var record = records.first { $0.bundleID == bundleID } ?? RecentAppRecord(bundleID: bundleID, lastUsed: Date(), uses: 0)
        record.lastUsed = Date()
        record.uses += 1
        records.removeAll { $0.bundleID == bundleID }
        records.insert(record, at: 0)
        if records.count > Self.maxRecords {
            records.removeLast(records.count - Self.maxRecords)
        }
        Defaults[.recentAppsLog] = records
        refreshRunning()
    }

    /// First launch: start from the apps that are already open so the list isn't empty.
    private func seedFromRunningApps() {
        let now = Date()
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let ids = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier)
            .filter { $0 != Bundle.main.bundleIdentifier }
        let ordered = ids.sorted { lhs, _ in lhs == frontmost }
        records = ordered.enumerated().map { index, id in
            RecentAppRecord(bundleID: id, lastUsed: now.addingTimeInterval(-Double(index)), uses: 1)
        }
        Defaults[.recentAppsLog] = records
    }

    private func refreshRunning() {
        runningIDs = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier))
    }

    private func app(for bundleID: String) -> RecentApp? {
        let url: URL
        if let cached = urlCache[bundleID] {
            url = cached
        } else if let found = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            urlCache[bundleID] = found
            url = found
        } else {
            return nil
        }
        let icon = iconCache[bundleID] ?? {
            let image = NSWorkspace.shared.icon(forFile: url.path)
            iconCache[bundleID] = image
            return image
        }()
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        return RecentApp(bundleID: bundleID, name: name, url: url, icon: icon,
                         isRunning: runningIDs.contains(bundleID), isKept: keptIDs.contains(bundleID))
    }
}
