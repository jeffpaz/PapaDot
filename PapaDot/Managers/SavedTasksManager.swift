// Managers/SavedTasksManager.swift
import Foundation

/// Persists named task presets so players don't need to re-enter custom tasks each game.
@Observable
final class SavedTasksManager {
    private let defaults = UserDefaults.standard
    private let storageKey = "savedTaskPresets"

    var presets: [TaskPreset] = []

    init() {
        load()
    }

    // MARK: - CRUD

    func save(name: String, tasks: [CustomTask]) {
        let preset = TaskPreset(name: name, tasks: tasks)
        // Replace existing preset with same name, or append
        if let idx = presets.firstIndex(where: { $0.name == name }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
        persist()
    }

    func delete(_ preset: TaskPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    func rename(_ preset: TaskPreset, to newName: String) {
        guard let idx = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[idx] = TaskPreset(id: preset.id, name: newName, tasks: preset.tasks)
        persist()
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
    var id: String = UUID().uuidString
    var name: String
    var tasks: [CustomTask]
}
