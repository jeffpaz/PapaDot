//  Utilities/Helpers.swift
import Foundation

/// Calculate total dots for each player in the game
func calculateTotalDots(game: GameState) -> [Player: Int] {
    var totals = [Player: Int]()
    
    // Initialize all players to 0
    for player in game.players {
        totals[player] = 0
    }
    
    // Iterate through all holes
    for hole in 1...18 {
        guard let holeScores = game.scores[hole] else { continue }
        
        for (playerName, tasks) in holeScores {
            guard let player = game.players.first(where: { $0.name == playerName }) else { continue }
            
            for (taskName, scored) in tasks where scored {
                guard let task = game.rules.tasks.first(where: { $0.name == taskName }) else { continue }
                
                // Handle Greenie with dynamic value
                if taskName == "Greenie" {
                    // Use the stored greenie value for this hole, or fall back to task points
                    let greenieValue = game.greenieValues[hole] ?? task.points
                    totals[player]! += greenieValue
                } else if task.isNegative {
                    // Negative tasks: Give points to all OTHER players
                    let pointValue = abs(task.points) // Use absolute value
                    for opponent in game.players where opponent.id != player.id {
                        totals[opponent]! += pointValue
                    }
                } else {
                    // Positive tasks: Give points to the player who achieved it
                    totals[player]! += task.points
                }
            }
        }
    }
    
    return totals
}
