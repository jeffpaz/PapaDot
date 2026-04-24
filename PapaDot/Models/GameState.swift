//  Models/GameState.swift
import Foundation

struct GameState: Codable, Equatable {
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
    var courseData: GolfCourseData?
    var greenieValues: [Int: Int] = [:]
    var processedPar3Holes: Set<Int> = []
    var holePhotos: [HolePhoto] = []
    var payments: [PaymentSummary] = [] // Track payment status
    
    var currentGreenieValue: Int {
        get { rules.currentGreenieValue }
        set { rules.currentGreenieValue = newValue }
    }

    // Explicit Equatable implementation to resolve compiler confusion
    static func == (lhs: GameState, rhs: GameState) -> Bool {
        return lhs.gameID == rhs.gameID &&
               lhs.recordID == rhs.recordID &&
               lhs.players == rhs.players &&
               lhs.rules == rhs.rules &&
               lhs.currentHole == rhs.currentHole &&
               lhs.isActive == rhs.isActive &&
               lhs.joinedPlayerIDs == rhs.joinedPlayerIDs &&
               lhs.golfCourse == rhs.golfCourse &&
               lhs.courseData == rhs.courseData &&
               lhs.completedDate == rhs.completedDate
               // payments comparison omitted (not critical for game equality)
    }
}
