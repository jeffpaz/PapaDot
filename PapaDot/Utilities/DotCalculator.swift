//  Utilities/DotCalculator.swift
import Foundation

// REMOVE "public" — this fixes the error
func calculateTotalDots(game: GameState) -> [Player: Int] {
    var dots: [Player: Int] = [:]
    for player in game.players { dots[player] = 0 }
    
    for hole in 1...18 {
        var rewardTasksThisHole = 0
        
        // Count how many Sand/OB/3-Putt happened this hole
        for task in game.rules.tasks where task.isNegative {
            for player in game.players {
                if game.scores[hole]?[player.name]?[task.name] == true {
                    rewardTasksThisHole += 1
                }
            }
        }
        
        // Everyone except the guilty gets +1 per bad thing
        for player in game.players {
            var badThingsIDid = 0
            for task in game.rules.tasks where task.isNegative {
                if game.scores[hole]?[player.name]?[task.name] == true {
                    badThingsIDid += 1
                }
            }
            
            let rewardsIGet = rewardTasksThisHole - badThingsIDid
            dots[player]! += rewardsIGet
        }
        
        // Positive tasks
        for player in game.players {
            for task in game.rules.tasks where !task.isNegative {
                if game.scores[hole]?[player.name]?[task.name] == true {
                    dots[player]! += task.points
                }
            }
        }
    }
    
    return dots
}
