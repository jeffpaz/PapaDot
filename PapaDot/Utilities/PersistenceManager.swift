//  Utilities/PersistenceManager.swift
import Foundation

@Observable
final class PersistenceManager {
    // Use shared app group for persistence across updates and widget access
    private let defaults = UserDefaults(suiteName: "group.com.jeffpaz.PapaDot") ?? UserDefaults.standard

    init() {
        migrateToAppGroup()
    }

    // Migrate existing data from UserDefaults.standard to app group
    private func migrateToAppGroup() {
        let standardDefaults = UserDefaults.standard

        // Only migrate if app group is available and migration hasn't happened yet
        guard let groupDefaults = UserDefaults(suiteName: "group.com.jeffpaz.PapaDot"),
              !groupDefaults.bool(forKey: "didMigrateToAppGroup") else {
            return
        }

        // Migrate current game
        if let currentGameData = standardDefaults.data(forKey: "currentGame") {
            groupDefaults.set(currentGameData, forKey: "currentGame")
            standardDefaults.removeObject(forKey: "currentGame")
        }

        // Migrate game history
        if let historyData = standardDefaults.data(forKey: "gameHistory") {
            groupDefaults.set(historyData, forKey: "gameHistory")
            standardDefaults.removeObject(forKey: "gameHistory")
        }

        // Mark migration as complete
        groupDefaults.set(true, forKey: "didMigrateToAppGroup")
        groupDefaults.synchronize()
    }

    func saveCurrent(_ game: GameState) {
        if let data = try? JSONEncoder().encode(game) {
            defaults.set(data, forKey: "currentGame")
        }
    }
    
    func loadCurrent() -> GameState? {
        guard let data = defaults.data(forKey: "currentGame"),
              let game = try? JSONDecoder().decode(GameState.self, from: data) else { return nil }
        return game
    }
    
    func clearCurrent() { defaults.removeObject(forKey: "currentGame") }
    
    func saveToHistory(_ game: GameState) {
        var history = loadHistory()
        var completed = game
        completed.completedDate = Date()
        history.insert(completed, at: 0)
        if history.count > 50 { history = Array(history.prefix(50)) }
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: "gameHistory")
        }
    }
    
    func loadHistory() -> [GameState] {
        guard let data = defaults.data(forKey: "gameHistory"),
              let list = try? JSONDecoder().decode([GameState].self, from: data) else { return [] }
        return list
    }

    func removeFromHistory(gameID: String) {
        var history = loadHistory()
        history.removeAll { $0.gameID == gameID }
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: "gameHistory")
        }
    }
}
