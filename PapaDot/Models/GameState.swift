// Models/GameState.swift
import Foundation

// MARK: - Side Bet

enum SideBetStatus: String, Codable {
    case active, settled
}

struct SideBet: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var description: String
    var amount: Int
    var createdBy: String
    var participants: [String]
    var winnerId: String?
    var status: SideBetStatus = .active
    var hole: Int?
    var createdDate: Date = Date()
    var settledDate: Date?
}

// MARK: - GameState

struct GameState: Codable, Equatable {
    var recordID: String?
    var gameID: String
    var players: [Player]
    var rules: GameRules
    var currentHole: Int = 1
    var scores: [Int: [String: [String: Bool]]] = [:]
    var strokeScores: [Int: [String: Int]] = [:] // hole -> playerName -> strokes
    var isActive: Bool = false
    var completedDate: Date?
    var lastModified: Date = Date()
    var joinedPlayerIDs: Set<String> = []
    var golfCourse: GolfCourse?
    var courseData: GolfCourseData?
    var greenieValues: [Int: Int] = [:]
    var processedPar3Holes: Set<Int> = []
    var lowHoleValues: [Int: Int] = [:]
    var processedLowHoleHoles: Set<Int> = []
    var holePhotos: [HolePhoto] = []
    var payments: [PaymentSummary] = []
    var sideBets: [SideBet] = []

    // Team assignments: Player 1 & 2 = Team A, Player 3 & 4 = Team B
    var teamAssignments: [String: String] {
        guard rules.isTeamMode, players.count == 4 else { return [:] }
        return [
            players[0].id: "A",
            players[1].id: "A",
            players[2].id: "B",
            players[3].id: "B"
        ]
    }

    func teamForPlayer(_ player: Player) -> String? {
        teamAssignments[player.id]
    }

    var currentGreenieValue: Int {
        get { rules.currentGreenieValue }
        set { rules.currentGreenieValue = newValue }
    }

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
    }
}
