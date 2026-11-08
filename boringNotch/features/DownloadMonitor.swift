//
//  DownloadMonitor.swift
//  boringNotch
//
//  Watches ~/Downloads for in-progress browser downloads:
//    • Safari:   "name.download" bundles (Info.plist inside carries bytes so far and total)
//    • Chromium: "name.crdownload" files (Chrome, Edge, Brave, Arc, Vivaldi, Opera) — size only
//    • Firefox:  "name.part" files — size only
//  Needs the com.apple.security.files.downloads.read-only entitlement (the app is sandboxed).
//

import AppKit
import Combine
import Darwin
import Defaults

struct ActiveDownload: Identifiable, Equatable {
    enum Source: Equatable {
        case safari
        case chromium
        case firefox

        var fallbackBundleID: String {
            switch self {
            case .safari: return "com.apple.Safari"
            case .chromium: return "com.google.Chrome"
            case .firefox: return "org.mozilla.firefox"
            }
        }
    }

    /// The partial file's path; stable for the life of the download.
    let id: String
    let name: String
    let source: Source
    let bundleID: String
    var bytesSoFar: Int64
    var totalBytes: Int64?

    /// 0...1 when the total size is known, otherwise nil.
    var progress: Double? {
        guard let total = totalBytes, total > 0 else { return nil }
        return min(1, max(0, Double(bytesSoFar) / Double(total)))
    }
}

@MainActor
final class DownloadMonitor: ObservableObject {
    static let shared = DownloadMonitor()

    @Published private(set) var downloads: [ActiveDownload] = []
    /// Name of a download that just finished; cleared after a few seconds.
    @Published private(set) var recentlyCompleted: String?

    var isActive: Bool { !downloads.isEmpty }

    /// The download shown in the notch: the one with the most data still to come.
    var primary: ActiveDownload? {
        downloads.max { lhs, rhs in
            let l = (lhs.totalBytes ?? lhs.bytesSoFar) - lhs.bytesSoFar
            let r = (rhs.totalBytes ?? rhs.bytesSoFar) - rhs.bytesSoFar
            return l < r
        }
    }

    private var loopTask: Task<Void, Never>?
    private var completedTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private static let chromiumBundleIDs = [
        "com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser",
        "company.thebrowser.Browser", "com.vivaldi.Vivaldi", "com.operasoftware.Opera",
    ]

    /// The real ~/Downloads. Inside the sandbox, FileManager's home points at the app container,
    /// so read the home directory from the user database instead.
    private let downloadsURL: URL = {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir)).appendingPathComponent("Downloads", isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
    }()

    private init() {
        Defaults.publisher(.enableDownloadListener, options: [])
            .sink { [weak self] change in
                Task { @MainActor in
                    if change.newValue { self?.start() } else { self?.stop() }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Monitoring

    func start() {
        guard loopTask == nil, Defaults[.enableDownloadListener] else { return }
        loopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }
                self.scan()
                // Poll quickly while something is downloading, slowly otherwise.
                let interval: Duration = self.isActive ? .milliseconds(500) : .seconds(2)
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        downloads = []
    }

    private func scan() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var found: [ActiveDownload] = []
        for url in items {
            switch url.pathExtension.lowercased() {
            case "download":
                guard Defaults[.enableSafariDownloads] else { continue }
                if let item = safariDownload(at: url) { found.append(item) }
            case "crdownload":
                found.append(sizeOnlyDownload(at: url, source: .chromium, bundleID: runningChromiumBundleID()))
            case "part":
                found.append(sizeOnlyDownload(at: url, source: .firefox, bundleID: ActiveDownload.Source.firefox.fallbackBundleID))
            default:
                continue
            }
        }
        found.sort { $0.id < $1.id }

        // Anything that disappeared and left its final file behind has finished.
        let finished = downloads.filter { old in !found.contains(where: { $0.id == old.id }) }
        if let done = finished.first(where: { fm.fileExists(atPath: downloadsURL.appendingPathComponent($0.name).path) }) {
            showCompleted(done.name)
        }

        if found != downloads {
            downloads = found
        }
    }

    private func showCompleted(_ name: String) {
        recentlyCompleted = name
        completedTask?.cancel()
        completedTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.recentlyCompleted = nil
        }
    }

    // MARK: - Parsers

    private func safariDownload(at bundleURL: URL) -> ActiveDownload? {
        let name = bundleURL.deletingPathExtension().lastPathComponent
        var bytes: Int64 = 0
        var total: Int64?

        let plistURL = bundleURL.appendingPathComponent("Info.plist")
        if let data = try? Data(contentsOf: plistURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            bytes = (plist["DownloadEntryProgressBytesSoFar"] as? NSNumber)?.int64Value ?? 0
            if let t = (plist["DownloadEntryProgressTotalToLoad"] as? NSNumber)?.int64Value, t > 0 {
                total = t
            }
        }

        // Safari doesn't rewrite Info.plist on every chunk, so the partial file inside is fresher.
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: bundleURL, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]
        ) {
            let largest = contents
                .filter { $0.lastPathComponent != "Info.plist" }
                .compactMap { (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } }
                .max() ?? 0
            bytes = max(bytes, largest)
        }

        return ActiveDownload(
            id: bundleURL.path,
            name: name,
            source: .safari,
            bundleID: ActiveDownload.Source.safari.fallbackBundleID,
            bytesSoFar: bytes,
            totalBytes: total
        )
    }

    private func sizeOnlyDownload(at url: URL, source: ActiveDownload.Source, bundleID: String) -> ActiveDownload {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
        return ActiveDownload(
            id: url.path,
            name: url.deletingPathExtension().lastPathComponent,
            source: source,
            bundleID: bundleID,
            bytesSoFar: size,
            totalBytes: nil
        )
    }

    /// .crdownload doesn't say which Chromium browser wrote it; guess the frontmost or first running one.
    private func runningChromiumBundleID() -> String {
        if let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Self.chromiumBundleIDs.contains(front) {
            return front
        }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return Self.chromiumBundleIDs.first(where: running.contains) ?? ActiveDownload.Source.chromium.fallbackBundleID
    }
}
