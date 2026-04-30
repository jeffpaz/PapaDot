//  Helpers/CalculateTotalDots.swift
import Foundation

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

    // Loop through all holes
    for hole in 1...18 {
        guard let holeScores = game.scores[hole] else { continue }

        for (playerName, tasks) in holeScores {
            guard let player = game.players.first(where: { $0.name == playerName }) else { continue }

            for (taskName, scored) in tasks where scored {
                // Find the task definition
                guard let task = game.rules.tasks.first(where: { $0.name == taskName }) else { continue }

                if task.isNegative {
                    // NEGATIVE TASK: Give points to ALL OTHER players
                    let pointsPerPlayer = abs(task.points)
                    for otherPlayer in game.players where otherPlayer.id != player.id {
                        dots[otherPlayer, default: 0] += pointsPerPlayer
                    }
                } else {
                    // POSITIVE TASK: Give points to the player who scored it

                    // Special handling for carry-over tasks - use the stored value for this hole
                    if taskName == "Greenie" {
                        let greenieValue = game.greenieValues[hole] ?? task.points
                        dots[player, default: 0] += greenieValue
                    } else if taskName == "Low Hole" {
                        let lowHoleValue = game.lowHoleValues[hole] ?? task.points
                        dots[player, default: 0] += lowHoleValue
                    } else {
                        dots[player, default: 0] += task.points
                    }
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

    guard let holeScores = game.scores[hole] else { return dots }

    for (playerName, tasks) in holeScores {
        guard let player = game.players.first(where: { $0.name == playerName }) else { continue }

        for (taskName, scored) in tasks where scored {
            guard let task = game.rules.tasks.first(where: { $0.name == taskName }) else { continue }

            if task.isNegative {
                // NEGATIVE TASK: Give points to ALL OTHER players
                let pointsPerPlayer = abs(task.points)
                for otherPlayer in game.players where otherPlayer.id != player.id {
                    dots[otherPlayer]! += pointsPerPlayer
                }
            } else {
                // POSITIVE TASK: Give points to the player who scored it
                if taskName == "Greenie" {
                    let greenieValue = game.greenieValues[hole] ?? task.points
                    dots[player, default: 0] += greenieValue
                } else if taskName == "Low Hole" {
                    let lowHoleValue = game.lowHoleValues[hole] ?? task.points
                    dots[player, default: 0] += lowHoleValue
                } else {
                    dots[player, default: 0] += task.points
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
