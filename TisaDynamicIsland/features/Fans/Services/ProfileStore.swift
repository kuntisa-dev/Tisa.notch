//
//  ProfileStore.swift
//  Tisa Fan Studio
//
//  Profile CRUD + persistence (PROMPT.md §6.4, R5/R6).
//
//  JSON at ~/Library/Application Support/TisaFanStudio/profiles.json. The file is
//  inspectable and hand-editable on purpose; every load runs through
//  `ProfileDocument.migrate` so an older or hand-mangled file is repaired rather than
//  rejected, and the built-in profiles can never be redefined by editing the file.
//

import Foundation

/// Main-actor isolated on purpose.
///
/// `document` is observable state that SwiftUI renders, and it is mutated from several
/// places (profile edits, applying a profile at launch, persisting a fan-card change). Marking
/// the type `@MainActor` makes writing it from a background thread a *compile* error rather
/// than a runtime "Publishing changes from background threads is not allowed" — which froze
/// the whole UI, because the environment re-emits child changes into SwiftUI.
@MainActor
final class ProfileStore: ObservableObject {

    @Published private(set) var document: ProfileDocument
    /// Warnings produced by the last load (migration, fan-count mismatch).
    @Published private(set) var warnings: [String] = []
    @Published private(set) var lastError: String?

    private let fileManager = FileManager.default
    private let fanCount: () -> Int

    // MARK: - Locations

    static var directoryURL: URL {
        // Under test, never the user's real Application Support: the hosted test bundle
        // writes through this path, and doing so polluted a real profiles.json with junk
        // profiles and changed the active profile.
        if FanTestEnvironment.isRunningTests {
            return FanTestEnvironment.isolatedSupportDirectory
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Tisa Fan Studio", isDirectory: true)
    }

    static var profilesURL: URL { directoryURL.appendingPathComponent("profiles.json") }

    // MARK: - Init

    init(fanCount: @escaping () -> Int) {
        self.fanCount = fanCount
        self.document = ProfileDocument.makeDefault(fanCount: fanCount())
        load()
    }

    // MARK: - Load / save

    func load() {
        var notes: [String] = []
        let count = fanCount()

        if let data = try? Data(contentsOf: Self.profilesURL) {
            do {
                // `applyAtLaunch` and `version` are defaulted for hand-written v0 files.
                let decoder = JSONDecoder()
                let decoded = try decoder.decode(ProfileDocument.self, from: data)
                let migrated = ProfileDocument.migrate(decoded, fanCount: count)
                document = migrated.document
                notes = migrated.notes
            } catch {
                lastError = "profiles.json could not be read (\(error.localizedDescription)); "
                    + "the built-in profiles were restored."
                document = ProfileDocument.makeDefault(fanCount: count)
                notes.append(lastError ?? "")
                // Keep the unreadable file for forensics instead of destroying it.
                let backup = Self.directoryURL.appendingPathComponent("profiles.corrupt.json")
                try? fileManager.removeItem(at: backup)
                try? fileManager.copyItem(at: Self.profilesURL, to: backup)
            }
        } else {
            document = ProfileDocument.makeDefault(fanCount: count)
            save()
        }

        warnings = notes.filter { !$0.isEmpty }
        for note in warnings { NSLog("[TisaFanStudio] profiles: \(note)") }
    }

    func save() {
        do {
            try fileManager.createDirectory(at: Self.directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(document).write(to: Self.profilesURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Could not save profiles: \(error.localizedDescription)"
            NSLog("[TisaFanStudio] \(lastError ?? "")")
        }
    }

    // MARK: - Queries

    var profiles: [Profile] { document.profiles }

    var activeProfile: Profile {
        document.activeProfile ?? Profile.automatic(fanCount: fanCount())
    }

    var activeProfileName: String {
        buildInNameFallback(activeProfile)
    }

    var applyAtLaunch: Bool {
        get { document.applyAtLaunch }
        set {
            document.applyAtLaunch = newValue
            save()
        }
    }

    func profile(id: String) -> Profile? {
        document.profiles.first { $0.id == id }
    }

    /// The active profile reconciled with this machine's fan count.
    func reconciledActiveProfile() -> (profile: Profile, warning: String?) {
        activeProfile.reconcile(withFanCount: fanCount())
    }

    private func buildInNameFallback(_ profile: Profile) -> String {
        profile.name.isEmpty ? "Automatic" : profile.name
    }

    // MARK: - Mutations

    /// Switches the active profile. Returns the reconciled profile to apply.
    @discardableResult
    func setActive(id: String) -> (profile: Profile, warning: String?)? {
        guard let profile = profile(id: id) else { return nil }
        document.activeProfileID = id
        if profile.builtIn { document.profiles.removeAll { $0.id == Profile.temporaryID } }
        save()
        return profile.reconcile(withFanCount: fanCount())
    }

    /// Creates an editable profile and returns it.
    @discardableResult
    func createProfile(name: String, defaultSensorKey: String?, defaultSensorName: String?) -> Profile {
        let profile = Profile.newCustom(
            name: uniqueName(base: name),
            fanCount: fanCount(),
            defaultSensorKey: defaultSensorKey,
            defaultSensorName: defaultSensorName
        )
        document.profiles.append(profile)
        save()
        return profile
    }

    /// Duplicates any profile (including a built-in) into an editable copy.
    @discardableResult
    func duplicate(id: String) -> Profile? {
        guard let source = profile(id: id) else { return nil }
        let copy = Profile(
            id: UUID().uuidString,
            name: uniqueName(base: "\(source.name) copy"),
            builtIn: false,
            fans: source.fans
        )
        document.profiles.append(copy)
        save()
        return copy
    }

    /// Per-fan edits made from a built-in profile live in a temporary profile.
    @discardableResult
    func setTemporaryProfile(fans: [FanSetting]) -> Profile {
        let profile = Profile(id: Profile.temporaryID, name: "Custom*", builtIn: false, fans: fans)
        document.profiles.removeAll { $0.id == profile.id }
        document.profiles.append(profile)
        document.activeProfileID = profile.id
        save()
        return profile
    }

    @discardableResult
    func saveCurrentProfile(as name: String) -> Profile? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let profile = Profile(id: UUID().uuidString, name: uniqueName(base: trimmed),
                              builtIn: false, fans: activeProfile.fans)
        document.profiles.append(profile)
        document.activeProfileID = profile.id
        document.profiles.removeAll { $0.id == Profile.temporaryID }
        save()
        return profile
    }

    func rename(id: String, to newName: String) {
        guard let index = document.profiles.firstIndex(where: { $0.id == id }),
              !document.profiles[index].builtIn,
              !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        document.profiles[index].name = newName.trimmingCharacters(in: .whitespaces)
        save()
    }

    func delete(id: String) {
        guard let profile = profile(id: id), !profile.builtIn else { return }
        document.profiles.removeAll { $0.id == id }
        if document.activeProfileID == id {
            document.activeProfileID = Profile.automaticID
        }
        save()
    }

    /// Replaces one fan's setting inside a profile (the fan card edits this).
    func updateFanSetting(profileID: String, setting: FanSetting) {
        guard let profileIndex = document.profiles.firstIndex(where: { $0.id == profileID }),
              !document.profiles[profileIndex].builtIn else {
            // Editing a built-in is not allowed; callers duplicate it first.
            return
        }
        var profile = document.profiles[profileIndex]
        if let fanIndex = profile.fans.firstIndex(where: { $0.index == setting.index }) {
            profile.fans[fanIndex] = setting
        } else {
            profile.fans.append(setting)
            profile.fans.sort { $0.index < $1.index }
        }
        document.profiles[profileIndex] = profile
        save()
    }

    /// Full replacement of a profile (used by the fan cards' batched edits).
    func replaceProfile(_ profile: Profile) {
        guard let index = document.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        if document.profiles[index].builtIn { return }
        document.profiles[index] = profile
        save()
    }

    // MARK: - Helpers

    private func uniqueName(base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        let candidate = trimmed.isEmpty ? "New profile" : trimmed
        guard document.profiles.contains(where: { $0.name == candidate }) else { return candidate }
        var counter = 2
        while document.profiles.contains(where: { $0.name == "\(candidate) \(counter)" }) {
            counter += 1
        }
        return "\(candidate) \(counter)"
    }
}
