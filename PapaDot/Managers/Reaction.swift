// Models/GameState.swift
import Foundation

// MARK: - Reaction Model

struct Reaction: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var fromPlayer: String      // player name
    var toPlayer: String        // player name being reacted to
    var emoji: String           // e.g. "🔥"
    var hole: Int
    var taskName: String        // what they're reacting to
    var timestamp: Date = Date()

    static let availableEmojis = ["🔥", "💀", "👑", "😂", "🤡", "💸", "🎯", "👏"]
}

// MARK: - Side Bet Model

enum SideBetStatus: String, Codable {
    case active, settled
}

struct SideBet: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String           // e.g. "Longest Drive Hole 7"
    var description: String     // e.g. "Closest to pin on par 3s"
    var amount: Int             // dollars
    var createdBy: String       // player name
    var participants: [String]  // player names
    var winnerId: String?       // player name of winner (nil until settled)
    var status: SideBetStatus = .active
    var hole: Int?              // optional hole number
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
    var isActive: Bool = false
    var completedDate: Date?
    var lastModified: Date = Date()
    var joinedPlayerIDs: Set<String> = []
    var golfCourse: GolfCourse?
    var courseData: GolfCourseData?
    var greenieValues: [Int: Int] = [:]
    var processedPar3Holes: Set<Int> = []
    var holePhotos: [HolePhoto] = []
    var payments: [PaymentSummary] = []
    var reactions: [Reaction] = []       // 🔥 Trash talk reactions
    var sideBets: [SideBet] = []         // 💰 Side bets

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
