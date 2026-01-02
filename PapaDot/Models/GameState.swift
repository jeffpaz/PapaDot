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
    var joinedPlayerIDs: Set<String> = [] // Track which players have actually connected (using String IDs)
    var golfCourse: GolfCourse? // Location
    var courseData: GolfCourseData? // Detailed course info
    var greenieValues: [Int: Int] = [:] // Track greenie value per hole
    var processedPar3Holes: Set<Int> = [] // Track which par 3s we've already processed
    var holePhotos: [HolePhoto] = [] // Photos taken during the round
    
    // NEW: for dynamic greenie
    var currentGreenieValue: Int {
        get { rules.currentGreenieValue }
        set { rules.currentGreenieValue = newValue }
    }
}
