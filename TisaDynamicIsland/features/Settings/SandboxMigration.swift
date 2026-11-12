//
//  SandboxMigration.swift
//  TisaDynamicIsland
//
//  The app used to run in the App Sandbox, which kept its settings and files in
//  ~/Library/Containers/<bundle id>. Without the sandbox (needed for Fan Studio) it
//  reads the normal locations, so on the first unsandboxed launch the old settings and
//  Application Support files are copied over once. Nothing in the container is changed.
//

import Defaults
import Foundation

enum SandboxMigration {
    static func run() {
        let defaults = UserDefaults.standard
        guard !Defaults[.migratedFromSandbox], let bundleID = Bundle.main.bundleIdentifier else { return }
        Defaults[.migratedFromSandbox] = true

        let fileManager = FileManager.default
        let containerLibrary = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(bundleID)/Data/Library", isDirectory: true)
        guard fileManager.fileExists(atPath: containerLibrary.path) else { return }

        // Settings: copy every key this app hasn't written outside the sandbox yet.
        let oldPreferences = containerLibrary.appendingPathComponent("Preferences/\(bundleID).plist")
        if let old = NSDictionary(contentsOf: oldPreferences) as? [String: Any] {
            let current = defaults.persistentDomain(forName: bundleID) ?? [:]
            for (key, value) in old where current[key] == nil {
                defaults.set(value, forKey: key)
            }
        }

        // Files (Shelf items and the like): copy what isn't already in the real folder.
        let oldSupport = containerLibrary.appendingPathComponent("Application Support", isDirectory: true)
        guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let items = try? fileManager.contentsOfDirectory(at: oldSupport, includingPropertiesForKeys: nil)
        else { return }
        try? fileManager.createDirectory(at: support, withIntermediateDirectories: true)
        for item in items {
            let destination = support.appendingPathComponent(item.lastPathComponent)
            if !fileManager.fileExists(atPath: destination.path) {
                try? fileManager.copyItem(at: item, to: destination)
            }
        }
    }
}
