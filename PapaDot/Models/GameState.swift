//  Models/GameState.swift
import Foundation

struct GameState: Equatable, Codable {
    var recordID: String?
    var gameID: String
    var players: [Player]
    var rules: GameRules
    var currentHole: Int = 1
    var scores: [Int: [String: [String: Bool]]] = [:]
    var isActive: Bool = false
    var completedDate: Date?
    var lastModified: Date = Date()
    
    // NEW: for dynamic greenie
    var currentGreenieValue: Int {
        get { rules.currentGreenieValue }
        set { rules.currentGreenieValue = newValue }
    }
}
