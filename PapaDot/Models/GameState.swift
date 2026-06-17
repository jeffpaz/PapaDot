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
    var sideBets: [SideBet] = []
    // Count-based scores for repeatable tasks (e.g. OB, Sand). Stored separately from
    // the Bool scores dict so existing saved games decode without any migration.
    // Structure: hole → playerName → taskName → count (0–3)
    var repeatableCounts: [Int: [String: [String: Int]]] = [:]
    // Team Low winner per hole: hole → "A" or "B". Nil means tied or not yet played.
    var teamLowWinner: [Int: String] = [:]

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

    /// The last hole to play given the starting hole (18 for start=1, startingHole-1 otherwise).
    var finishHole: Int {
        rules.startingHole == 1 ? 18 : rules.startingHole - 1
    }

    /// True when the player is on the last hole of the round.
    var isLastHole: Bool { currentHole == finishHole }

    /// 1-based position in the round (e.g. hole 12 in a back-9 start = position 3).
    var roundPosition: Int {
        let s = rules.startingHole
        return currentHole >= s ? currentHole - s + 1 : currentHole + 19 - s
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

// MARK: - Resilient Decoding
// Placed in an extension so Swift still synthesizes the memberwise init in the primary
// struct declaration. Without this, adding init(from:) to the struct body would kill the
// synthesized init and break every GameState(...) call site.
// Using decodeIfPresent throughout means any key added in a future schema version won't
// crash when decoding records that predate that addition.

extension GameState {
    private enum CodingKeys: String, CodingKey {
        case recordID, gameID, players, rules, currentHole, scores, strokeScores
        case isActive, completedDate, lastModified, joinedPlayerIDs
        case golfCourse, courseData
        case greenieValues, processedPar3Holes, lowHoleValues, processedLowHoleHoles
        case holePhotos, sideBets, repeatableCounts, teamLowWinner
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recordID              = try c.decodeIfPresent(String.self,                          forKey: .recordID)
        gameID                = try c.decode(String.self,                                   forKey: .gameID)
        players               = try c.decode([Player].self,                                 forKey: .players)
        rules                 = try c.decode(GameRules.self,                                forKey: .rules)
        currentHole           = try c.decodeIfPresent(Int.self,                             forKey: .currentHole)           ?? 1
        scores                = try c.decodeIfPresent([Int: [String: [String: Bool]]].self, forKey: .scores)                ?? [:]
        strokeScores          = try c.decodeIfPresent([Int: [String: Int]].self,            forKey: .strokeScores)          ?? [:]
        isActive              = try c.decodeIfPresent(Bool.self,                            forKey: .isActive)              ?? false
        completedDate         = try c.decodeIfPresent(Date.self,                            forKey: .completedDate)
        lastModified          = try c.decodeIfPresent(Date.self,                            forKey: .lastModified)          ?? .distantPast
        joinedPlayerIDs       = try c.decodeIfPresent(Set<String>.self,                     forKey: .joinedPlayerIDs)       ?? []
        golfCourse            = try c.decodeIfPresent(GolfCourse.self,                      forKey: .golfCourse)
        courseData            = try c.decodeIfPresent(GolfCourseData.self,                  forKey: .courseData)
        greenieValues         = try c.decodeIfPresent([Int: Int].self,                      forKey: .greenieValues)         ?? [:]
        processedPar3Holes    = try c.decodeIfPresent(Set<Int>.self,                        forKey: .processedPar3Holes)    ?? []
        lowHoleValues         = try c.decodeIfPresent([Int: Int].self,                      forKey: .lowHoleValues)         ?? [:]
        processedLowHoleHoles = try c.decodeIfPresent(Set<Int>.self,                        forKey: .processedLowHoleHoles) ?? []
        holePhotos            = try c.decodeIfPresent([HolePhoto].self,                     forKey: .holePhotos)            ?? []
        sideBets              = try c.decodeIfPresent([SideBet].self,                       forKey: .sideBets)              ?? []
        repeatableCounts      = try c.decodeIfPresent([Int: [String: [String: Int]]].self,  forKey: .repeatableCounts)      ?? [:]
        teamLowWinner         = try c.decodeIfPresent([Int: String].self,                   forKey: .teamLowWinner)         ?? [:]
    }
}
