//  Helpers/CalculateTotalDots.swift
import Foundation

/// Expected par for a hole: prefers loaded course data, falling back to 3 for holes
/// marked as par-3 in the game's rules and 4 otherwise. Single source of truth for
/// "what par should this hole be treated as when no course data is loaded" — reused
/// by the stroke score reconciliation in GameManager and the Scorecard's PAR row.
func holePar(game: GameState, hole: Int) -> Int {
    game.courseData?.holes?.first(where: { $0.number == hole })?.par
        ?? (game.rules.par3Holes.contains(hole) ? 3 : 4)
}

/// Net score after handicap strokes for a player on a specific hole.
/// Par 3 holes receive no handicap strokes. A player's full handicap is distributed only
/// among non-par-3 holes that carry handicap stroke-index data, re-ranked among themselves
/// by difficulty. Holes missing that data receive no strokes.
/// Single source of truth — reused by scoring (Low Hole auto-award), the stroke picker's
/// net-score tooltip, and the Scorecard's NET column so all three always agree.
func calculateNetScore(playerHandicap: Int, grossScore: Int, holeNumber: Int, holePar: Int, courseData: GolfCourseData?) -> Int {
    guard playerHandicap > 0 else { return grossScore }
    guard holePar != 3 else { return grossScore }
    guard let allHoles = courseData?.holes else { return grossScore }

    let nonPar3 = allHoles.filter { $0.par != 3 && $0.handicap != nil }
                          .sorted { ($0.handicap ?? Int.max) < ($1.handicap ?? Int.max) }
    guard !nonPar3.isEmpty, let rankIndex = nonPar3.firstIndex(where: { $0.number == holeNumber }) else {
        return grossScore
    }
    let rank = rankIndex + 1
    let strokesReceived = playerHandicap / nonPar3.count + (rank <= playerHandicap % nonPar3.count ? 1 : 0)
    return max(1, grossScore - strokesReceived)
}

/// Per-payer debts derived from total dots, with the Maximum Owed cap applied when enabled —
/// mirrors GameOverView's settlement math so History's lifetime totals always agree with what
/// was actually shown/settled at the end of each game.
/// Individual mode: each player behind another owes them the dot difference * stake.
/// Team mode (4 players, isTeamMode): each losing-team player owes each winning-team player
/// the team dot difference * stake.
func calculateCappedDebts(game: GameState) -> [(payer: Player, owes: [(to: Player, amount: Int)])] {
    let dots = calculateTotalDots(game: game)
    let stake = game.rules.stakePerPoint
    let isTeamMode = game.rules.isTeamMode && game.players.count == 4

    var raw: [(payer: Player, owes: [(to: Player, amount: Int)])] = []

    if isTeamMode {
        let teamA = [game.players[0], game.players[1]]
        let teamB = [game.players[2], game.players[3]]
        let teamADots = teamA.map { dots[$0] ?? 0 }.reduce(0, +)
        let teamBDots = teamB.map { dots[$0] ?? 0 }.reduce(0, +)
        if teamADots != teamBDots {
            let dotDiff = abs(teamADots - teamBDots)
            let amountPerPerson = dotDiff * stake
            let losingTeam  = teamADots > teamBDots ? teamB : teamA
            let winningTeam = teamADots > teamBDots ? teamA : teamB
            for loser in losingTeam {
                raw.append((payer: loser, owes: winningTeam.map { (to: $0, amount: amountPerPerson) }))
            }
        }
    } else {
        for player in game.players.sorted(by: { $0.name < $1.name }) {
            let myDots = dots[player] ?? 0
            let owes = game.players
                .filter { $0.id != player.id }
                .compactMap { other -> (to: Player, amount: Int)? in
                    let diff = (dots[other] ?? 0) - myDots
                    return diff > 0 ? (to: other, amount: diff * stake) : nil
                }
                .sorted { $0.to.name < $1.to.name }
            if !owes.isEmpty { raw.append((payer: player, owes: owes)) }
        }
    }

    guard game.rules.maxOwedEnabled else { return raw }
    let cap = game.rules.maxOwedAmount
    return raw.map { group in
        let totalDebt = group.owes.reduce(0) { $0 + $1.amount }
        guard totalDebt > cap else { return group }
        let sorted = group.owes.sorted { $0.amount > $1.amount }
        var remaining = cap
        var scaled: [(to: Player, amount: Int)] = []
        for (index, debt) in sorted.enumerated() {
            let share: Int = index == sorted.count - 1 ? remaining : {
                let s = Int(Double(debt.amount) / Double(totalDebt) * Double(cap))
                remaining -= s
                return s
            }()
            scaled.append((to: debt.to, amount: share))
        }
        return (payer: group.payer, owes: scaled)
    }
}

/// Calculate total dots for each player, accounting for variable greenie values and negative tasks
func calculateTotalDots(game: GameState) -> [Player: Int] {
    // Use team mode calculation if enabled
    if game.rules.isTeamMode && game.players.count == 4 {
        return calculateTeamModeDots(game: game)
    }

    var dots = [Player: Int]()
    for player in game.players {
        dots[player] = 0
    }

    // Loop through all holes — Bool-scored tasks
    for hole in 1...18 {
        guard let holeScores = game.scores[hole] else { continue }

        for (playerName, tasks) in holeScores {
            guard let player = game.players.first(where: { $0.name == playerName }) else { continue }

            for (taskName, scored) in tasks where scored {
                guard let task = game.rules.tasks.first(where: { $0.name == taskName }) else { continue }

                if task.isNegative {
                    let pointsPerPlayer = abs(task.points)
                    for otherPlayer in game.players where otherPlayer.id != player.id {
                        dots[otherPlayer, default: 0] += pointsPerPlayer
                    }
                } else {
                    if taskName == "Greenie" {
                        dots[player, default: 0] += game.greenieValues[hole] ?? task.points
                    } else if taskName == "Low Hole" {
                        dots[player, default: 0] += game.lowHoleValues[hole] ?? task.points
                    } else {
                        dots[player, default: 0] += task.points
                    }
                }
            }
        }
    }

    // Repeatable-task counts (e.g. OB, Sand) stored separately from Bool scores
    for hole in 1...18 {
        guard let holeCounts = game.repeatableCounts[hole] else { continue }
        for (playerName, taskCounts) in holeCounts {
            guard let player = game.players.first(where: { $0.name == playerName }) else { continue }
            for (taskName, count) in taskCounts where count > 0 {
                guard let task = game.rules.tasks.first(where: { $0.name == taskName }) else { continue }
                let pts = abs(task.points) * count
                if task.isNegative {
                    for other in game.players where other.id != player.id {
                        dots[other, default: 0] += pts
                    }
                } else {
                    dots[player, default: 0] += pts
                }
            }
        }
    }

    return dots
}

/// Calculate dots for a single hole
func calculateHoleDots(game: GameState, hole: Int) -> [Player: Int] {
    // Use team mode calculation if enabled
    if game.rules.isTeamMode && game.players.count == 4 {
        return calculateTeamModeHoleDots(game: game, hole: hole)
    }

    var dots = [Player: Int]()
    for player in game.players {
        dots[player] = 0
    }

    if let holeScores = game.scores[hole] {
        for (playerName, tasks) in holeScores {
            guard let player = game.players.first(where: { $0.name == playerName }) else { continue }
            for (taskName, scored) in tasks where scored {
                guard let task = game.rules.tasks.first(where: { $0.name == taskName }) else { continue }
                if task.isNegative {
                    let pointsPerPlayer = abs(task.points)
                    for otherPlayer in game.players where otherPlayer.id != player.id {
                        dots[otherPlayer, default: 0] += pointsPerPlayer
                    }
                } else {
                    if taskName == "Greenie" {
                        dots[player, default: 0] += game.greenieValues[hole] ?? task.points
                    } else if taskName == "Low Hole" {
                        dots[player, default: 0] += game.lowHoleValues[hole] ?? task.points
                    } else {
                        dots[player, default: 0] += task.points
                    }
                }
            }
        }
    }

    if let holeCounts = game.repeatableCounts[hole] {
        for (playerName, taskCounts) in holeCounts {
            guard let player = game.players.first(where: { $0.name == playerName }) else { continue }
            for (taskName, count) in taskCounts where count > 0 {
                guard let task = game.rules.tasks.first(where: { $0.name == taskName }) else { continue }
                let pts = abs(task.points) * count
                if task.isNegative {
                    for other in game.players where other.id != player.id {
                        dots[other, default: 0] += pts
                    }
                } else {
                    dots[player, default: 0] += pts
                }
            }
        }
    }

    return dots
}

/// Calculate dots for a single hole in team mode
func calculateTeamModeHoleDots(game: GameState, hole: Int) -> [Player: Int] {
    guard game.players.count == 4 else { return [:] }

    var teamDots: [String: Double] = ["A": 0, "B": 0]

    guard let holeScores = game.scores[hole] else {
        var playerDots = [Player: Int]()
        for player in game.players {
            playerDots[player] = 0
        }
        return playerDots
    }

    for (playerName, tasks) in holeScores {
        guard let player = game.players.first(where: { $0.name == playerName }),
              let team = game.teamForPlayer(player) else { continue }

        for (taskName, scored) in tasks where scored {
            guard let task = game.rules.tasks.first(where: { $0.name == taskName }) else { continue }

            if task.isNegative {
                let opposingTeam = team == "A" ? "B" : "A"
                let pointsValue = Double(abs(task.points))
                teamDots[opposingTeam, default: 0] += pointsValue
            } else {
                if taskName == "Greenie" {
                    let greenieValue = Double(game.greenieValues[hole] ?? task.points)
                    teamDots[team, default: 0] += greenieValue
                } else if taskName == "Low Hole" {
                    let lowHoleValue = Double(game.lowHoleValues[hole] ?? task.points)
                    teamDots[team, default: 0] += lowHoleValue
                } else {
                    teamDots[team, default: 0] += Double(task.points)
                }
            }
        }
    }

    if let holeCounts = game.repeatableCounts[hole] {
        for (playerName, taskCounts) in holeCounts {
            guard let player = game.players.first(where: { $0.name == playerName }),
                  let team = game.teamForPlayer(player) else { continue }
            for (taskName, count) in taskCounts where count > 0 {
                guard let task = game.rules.tasks.first(where: { $0.name == taskName }) else { continue }
                let pts = Double(abs(task.points) * count)
                if task.isNegative {
                    let opposingTeam = team == "A" ? "B" : "A"
                    teamDots[opposingTeam, default: 0] += pts
                } else {
                    teamDots[team, default: 0] += pts
                }
            }
        }
    }

    // Team Low points for this hole
    if let winner = game.teamLowWinner[hole] {
        teamDots[winner, default: 0] += Double(game.rules.teamLowPoints)
    }

    // Split team dots between teammates, preserving total (no phantom dots from rounding)
    var playerDots = [Player: Int]()
    var teamPlayerIndex: [String: Int] = [:]
    for player in game.players {
        if let team = game.teamForPlayer(player) {
            let total = Int(teamDots[team] ?? 0)
            let idx = teamPlayerIndex[team, default: 0]
            playerDots[player] = total / 2 + (idx == 0 && total % 2 != 0 ? 1 : 0)
            teamPlayerIndex[team] = idx + 1
        } else {
            playerDots[player] = 0
        }
    }

    return playerDots
}

// MARK: - Nassau

enum NassauSegment: String, Codable {
    case front, back, overall
}

/// Result of one segment (front/back/overall) of a Nassau match.
/// `margin` is signed holes-up: positive means playerA is up, negative means playerB is up,
/// zero means all square. It's meaningful even while `isResolved` is false (for live "2up"
/// style status), but `winnerID`/`amount` only become non-nil/non-zero once the segment
/// actually settles — a leading margin mid-segment is not a settled result.
struct NassauSegmentResult {
    let segment: NassauSegment
    let isResolved: Bool
    let holesPlayed: Int
    let holesTotal: Int
    let margin: Int
    let winnerID: String?
    let amount: Int
}

struct NassauMatchResult {
    let match: NassauMatch
    let segments: [NassauSegmentResult]

    /// Net payout across all resolved, non-push segments in this match — mirrors how
    /// GameOverView's netSummary nets Dots debts down to a single signed amount per player.
    /// Nil when there's nothing owed (all segments still in progress, or every settled
    /// segment was a push).
    var netSettlement: (payerID: String, payeeID: String, amount: Int)? {
        var netForA = 0
        for seg in segments where seg.isResolved {
            guard let winner = seg.winnerID else { continue }
            if winner == match.playerAID { netForA += seg.amount }
            else if winner == match.playerBID { netForA -= seg.amount }
        }
        guard netForA != 0 else { return nil }
        return netForA > 0
            ? (payerID: match.playerBID, payeeID: match.playerAID, amount: netForA)
            : (payerID: match.playerAID, payeeID: match.playerBID, amount: -netForA)
    }
}

/// Nassau (5-5-5) side match: front 9 / back 9 / overall 18, each settled independently as
/// a simple win-or-push — no presses, no carries. A hole is won by whichever player has the
/// lower score that hole; a tied hole doesn't move the margin. Front is fixed to holes 1–9
/// and back to holes 10–18 (matching ScorecardView's OUT/IN convention) regardless of
/// game.rules.startingHole — a hole counts as "played" using the same simplified check
/// ScorecardView already uses elsewhere (hole < game.currentHole, or the round is complete),
/// which — like the rest of the app — doesn't special-case a wrapped play order from a
/// non-default starting hole.
///
/// Per-hole score is each player's own net-vs-par (via the existing calculateNetScore,
/// exactly as used everywhere else in the app) when game.rules.useHandicap is on, gross
/// otherwise. This is a deliberate simplification: real match-play Nassau allocates strokes
/// head-to-head off the handicap *differential* between the two players (only the higher-
/// handicap player gets a stroke, only on their hardest holes relative to the opponent).
/// This instead just compares each player's already-existing, independently-computed net
/// score — simpler, consistent with how every other net score in this app is computed, but
/// not textbook match-play stroke allocation.
func calculateNassauResult(game: GameState, match: NassauMatch) -> NassauMatchResult {
    let segmentDefs: [(NassauSegment, ClosedRange<Int>, Int)] = [
        (.front, 1...9, match.frontBet),
        (.back, 10...18, match.backBet),
        (.overall, 1...18, match.overallBet)
    ]

    guard let playerA = game.players.first(where: { $0.id == match.playerAID }),
          let playerB = game.players.first(where: { $0.id == match.playerBID }) else {
        // A referenced player is no longer in the roster — nothing to compute.
        let segments = segmentDefs.map {
            NassauSegmentResult(segment: $0.0, isResolved: false, holesPlayed: 0,
                                 holesTotal: $0.1.count, margin: 0, winnerID: nil, amount: 0)
        }
        return NassauMatchResult(match: match, segments: segments)
    }

    let isRoundOver = game.completedDate != nil

    let segments: [NassauSegmentResult] = segmentDefs.map { segment, range, bet in
        var margin = 0
        var holesPlayed = 0
        for hole in range {
            guard hole < game.currentHole || isRoundOver else { continue }
            holesPlayed += 1
            let par = holePar(game: game, hole: hole)
            let grossA = game.strokeScores[hole]?[playerA.name] ?? par
            let grossB = game.strokeScores[hole]?[playerB.name] ?? par
            let netA = game.rules.useHandicap
                ? calculateNetScore(playerHandicap: playerA.handicap, grossScore: grossA,
                                     holeNumber: hole, holePar: par, courseData: game.courseData)
                : grossA
            let netB = game.rules.useHandicap
                ? calculateNetScore(playerHandicap: playerB.handicap, grossScore: grossB,
                                     holeNumber: hole, holePar: par, courseData: game.courseData)
                : grossB
            if netA < netB { margin += 1 } else if netB < netA { margin -= 1 }
        }
        let isResolved = holesPlayed == range.count
        let winnerID: String? = (isResolved && margin != 0) ? (margin > 0 ? playerA.id : playerB.id) : nil
        let amount = winnerID != nil ? bet : 0
        return NassauSegmentResult(segment: segment, isResolved: isResolved, holesPlayed: holesPlayed,
                                    holesTotal: range.count, margin: margin, winnerID: winnerID, amount: amount)
    }

    return NassauMatchResult(match: match, segments: segments)
}

func calculateAllNassauResults(game: GameState) -> [NassauMatchResult] {
    game.nassauMatches.map { calculateNassauResult(game: game, match: $0) }
}

// MARK: - Side Bet Payouts

/// Payout lines for every *settled* side bet: the bet's `amount` is a fixed total pot,
/// split evenly across the losing participants (everyone in `participants` except the
/// winner). Splits an uneven pot the same way calculateTeamModeDots splits an odd total
/// between teammates — the remainder goes to the first loser(s) rather than being lost to
/// integer division, so the payout lines always sum back to exactly `amount`.
/// Active (unsettled) bets produce no line — there's nothing to show yet.
func calculateSideBetPayouts(game: GameState) -> [(bet: SideBet, winnerPays: [(loser: String, amount: Int)])] {
    game.sideBets.compactMap { bet -> (bet: SideBet, winnerPays: [(loser: String, amount: Int)])? in
        guard bet.status == .settled, let winner = bet.winnerId else { return nil }
        let losers = bet.participants.filter { $0 != winner }
        guard !losers.isEmpty else { return nil }

        let base = bet.amount / losers.count
        let remainder = bet.amount % losers.count
        let winnerPays = losers.enumerated().map { index, loser in
            (loser: loser, amount: base + (index < remainder ? 1 : 0))
        }
        return (bet: bet, winnerPays: winnerPays)
    }
}

/// Calculate dots for team mode: dots awarded to teams, split evenly between teammates
/// Low Hole is team-exclusive via isExclusive flag handling
func calculateTeamModeDots(game: GameState) -> [Player: Int] {
    guard game.players.count == 4 else { return [:] }

    var teamDots: [String: Double] = ["A": 0, "B": 0]

    // Loop through all holes
    for hole in 1...18 {
        guard let holeScores = game.scores[hole] else { continue }

        for (playerName, tasks) in holeScores {
            guard let player = game.players.first(where: { $0.name == playerName }),
                  let team = game.teamForPlayer(player) else { continue }

            for (taskName, scored) in tasks where scored {
                guard let task = game.rules.tasks.first(where: { $0.name == taskName }) else { continue }

                if task.isNegative {
                    // NEGATIVE TASK: Give points to OPPOSING TEAM
                    let opposingTeam = team == "A" ? "B" : "A"
                    let pointsValue = Double(abs(task.points))
                    teamDots[opposingTeam, default: 0] += pointsValue
                } else {
                    // POSITIVE TASK: Give points to player's team
                    // Special handling for carry-over tasks
                    if taskName == "Greenie" {
                        let greenieValue = Double(game.greenieValues[hole] ?? task.points)
                        teamDots[team, default: 0] += greenieValue
                    } else if taskName == "Low Hole" {
                        let lowHoleValue = Double(game.lowHoleValues[hole] ?? task.points)
                        teamDots[team, default: 0] += lowHoleValue
                    } else {
                        teamDots[team, default: 0] += Double(task.points)
                    }
                }
            }
        }
    }

    // Repeatable-task counts
    for hole in 1...18 {
        guard let holeCounts = game.repeatableCounts[hole] else { continue }
        for (playerName, taskCounts) in holeCounts {
            guard let player = game.players.first(where: { $0.name == playerName }),
                  let team = game.teamForPlayer(player) else { continue }
            for (taskName, count) in taskCounts where count > 0 {
                guard let task = game.rules.tasks.first(where: { $0.name == taskName }) else { continue }
                let pts = Double(abs(task.points) * count)
                if task.isNegative {
                    let opposingTeam = team == "A" ? "B" : "A"
                    teamDots[opposingTeam, default: 0] += pts
                } else {
                    teamDots[team, default: 0] += pts
                }
            }
        }
    }

    // Team Low points per hole
    for hole in 1...18 {
        if let winner = game.teamLowWinner[hole] {
            teamDots[winner, default: 0] += Double(game.rules.teamLowPoints)
        }
    }

    // Split team dots between teammates, preserving total (no phantom dots from rounding)
    var playerDots = [Player: Int]()
    var teamPlayerIndex: [String: Int] = [:]
    for player in game.players {
        if let team = game.teamForPlayer(player) {
            let total = Int(teamDots[team] ?? 0)
            let idx = teamPlayerIndex[team, default: 0]
            playerDots[player] = total / 2 + (idx == 0 && total % 2 != 0 ? 1 : 0)
            teamPlayerIndex[team] = idx + 1
        } else {
            playerDots[player] = 0
        }
    }

    return playerDots
}
