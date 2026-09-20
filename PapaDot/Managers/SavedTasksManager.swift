// Managers/SavedTasksManager.swift
import Foundation

/// Persists named task presets so players don't need to re-enter custom tasks each game.
@Observable
final class SavedTasksManager {
    private let defaults: UserDefaults
    private let storageKey = "savedTaskPresets"

    var presets: [TaskPreset] = []

    /// `defaults` is injectable (defaults to `.standard`) so tests can exercise seeding/CRUD
    /// against an isolated UserDefaults suite instead of the app's real shared storage.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        seedBuiltInsIfNeeded()
    }

    // MARK: - CRUD

    func save(name: String, tasks: [CustomTask], teamLowPoints: Int = 2) {
        // Built-ins are identified by a stable id, not name, so a user can't silently
        // overwrite one (e.g. "Save As" using the literal name "Skins").
        guard !presets.contains(where: { $0.isBuiltIn && $0.name == name }) else { return }
        let preset = TaskPreset(name: name, tasks: tasks, teamLowPoints: teamLowPoints)
        // Replace existing preset with same name, or append
        if let idx = presets.firstIndex(where: { $0.name == name }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
        persist()
    }

    func delete(_ preset: TaskPreset) {
        guard !preset.isBuiltIn else { return }
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    func rename(_ preset: TaskPreset, to newName: String) {
        guard !preset.isBuiltIn else { return }
        guard let idx = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[idx] = TaskPreset(id: preset.id, name: newName, tasks: preset.tasks, teamLowPoints: preset.teamLowPoints)
        persist()
    }

    // MARK: - Built-in Presets
    //
    // Curated, one-tap "named game" formats shipped with the app (distinct from a user's own
    // saved presets). Seeded once on first launch, matching the seed-once guard pattern
    // PersistenceManager.migrateToAppGroup() already uses. Identified by a stable literal id
    // (not name) so re-seeding can detect "already present" reliably even if the user renames
    // their own unrelated preset to the same display name.

    private func seedBuiltInsIfNeeded() {
        guard !defaults.bool(forKey: "didSeedBuiltInPresets") else { return }
        for builtIn in TaskPreset.builtIns where !presets.contains(where: { $0.id == builtIn.id }) {
            presets.append(builtIn)
        }
        persist()
        defaults.set(true, forKey: "didSeedBuiltInPresets")
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([TaskPreset].self, from: data) else { return }
        presets = saved
    }
}

// MARK: - Model

struct TaskPreset: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var tasks: [CustomTask]
    var teamLowPoints: Int
    var isBuiltIn: Bool

    init(id: String = UUID().uuidString, name: String, tasks: [CustomTask], teamLowPoints: Int = 2, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.tasks = tasks
        self.teamLowPoints = teamLowPoints
        self.isBuiltIn = isBuiltIn
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, tasks, teamLowPoints, isBuiltIn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decodeIfPresent(String.self,     forKey: .id)            ?? UUID().uuidString
        name          = try c.decode(String.self,              forKey: .name)
        tasks         = try c.decode([CustomTask].self,        forKey: .tasks)
        teamLowPoints = try c.decodeIfPresent(Int.self,        forKey: .teamLowPoints) ?? 2
        isBuiltIn     = try c.decodeIfPresent(Bool.self,       forKey: .isBuiltIn)     ?? false
    }
}

// MARK: - Built-in "Named Game" Presets
//
// Curated formats that map exactly onto the existing task model with zero new scoring
// mechanics. Skins is precisely what the default "Low Hole" task already does (lowest score
// on a hole wins a carry-over pot, exclusive winner) — so the underlying CustomTask.name here
// stays literally "Low Hole". GameManager, Helpers.swift, ScoreEntryView, GameOverView, and
// StatisticsView all hardcode that exact string for auto-award/carry-over detection and score
// dictionary keys; renaming it would silently break the entire mechanic. Only this preset's
// display name is "Skins" — the in-round scorecard/stats still read "Low Hole".
extension TaskPreset {
    static var builtIns: [TaskPreset] {
        [
            TaskPreset(
                id: "builtin-skins",
                name: "Skins",
                tasks: [
                    CustomTask(name: "Low Hole", points: 2, isExclusive: true, isNegative: false,
                               hasCarryOver: true, isRepeatable: false)
                ],
                teamLowPoints: 2,
                isBuiltIn: true
            )
        ]
    }
}
