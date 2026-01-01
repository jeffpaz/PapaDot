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
    var joinedPlayerIDs: Set<String> = []
    var golfCourse: GolfCourse?
    var courseData: GolfCourseData? // NEW: Course par data
    var greenieValues: [Int: Int] = [:] // Track greenie value per hole
    var processedPar3Holes: Set<Int> = [] // Track which par 3s have been processed for increment
    
    // Dynamic greenie value (delegates to rules)
    var currentGreenieValue: Int {
        get { rules.currentGreenieValue }
        set { rules.currentGreenieValue = newValue }
    }
}
