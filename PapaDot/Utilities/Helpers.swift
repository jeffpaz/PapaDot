//  Helpers/CalculateTotalDots.swift
import Foundation

/// Calculate total dots for each player, accounting for variable greenie values and negative tasks
func calculateTotalDots(game: GameState) -> [Player: Int] {
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
                        dots[otherPlayer]! += pointsPerPlayer
                    }
                } else {
                    // POSITIVE TASK: Give points to the player who scored it
                    
                    // Special handling for Greenie - use the stored value for this hole
                    if taskName == "Greenie" {
                        let greenieValue = game.greenieValues[hole] ?? 1  // Default to 1 if not stored
                        dots[player]! += greenieValue
                    } else {
                        // Use the task's defined point value
                        dots[player]! += task.points
                    }
                }
            }
        }
    }
    
    return dots
}
