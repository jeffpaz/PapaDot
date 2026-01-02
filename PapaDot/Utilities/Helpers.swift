//  Utilities/Helpers.swift

import Foundation

/// Calculate total dots for each player, accounting for variable greenie values
func calculateTotalDots(game: GameState) -> [Player: Int] {
    var totals = [Player: Int]()
    for player in game.players {
        totals[player] = 0
    }
    
    // Loop through all holes
    for hole in 1...18 {
        guard let holeScores = game.scores[hole] else { continue }
        
        for (playerName, tasks) in holeScores {
            guard let player = game.players.first(where: { $0.name == playerName }) else { continue }
            
            for (taskName, scored) in tasks where scored {
                // Find the task definition
                guard let task = game.rules.tasks.first(where: { $0.name == taskName }) else { continue }
                
                // Special handling for Greenie - use the stored value for this hole
                if taskName == "Greenie" {
                    let greenieValue = game.greenieValues[hole] ?? 1  // Default to 1 if not stored
                    totals[player]! += greenieValue
                    print("📊 Hole \(hole): \(playerName) got Greenie worth \(greenieValue) points")
                } else {
                    // Use the task's defined point value
                    totals[player]! += task.points
                }
            }
        }
    }
    
    return totals
}
