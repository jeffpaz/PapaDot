//  Utilities/PersistenceManager.swift
import Foundation

@Observable
final class PersistenceManager {
    private let defaults = UserDefaults.standard
    
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
}
