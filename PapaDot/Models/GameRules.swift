//  Models/GameRules.swift
import Foundation

struct GameRules: Codable, Equatable {
    var stakePerPoint = 1
    var par3Holes: Set<Int> = []  // NEW: selected par 3 holes
    var currentGreenieValue = 1   // NEW: dynamic greenie value
    var allowGuestsToScore = true // NEW: Allow non-host players to change scores
    
    var tasks: [CustomTask] = [
        CustomTask(name: "Fairway", points: 1),
        CustomTask(name: "Birdie", points: 3),
        CustomTask(name: "Poley", points: 1),
        CustomTask(name: "Greenie", points: 1, isExclusive: true),
        CustomTask(name: "Low Hole", points: 1, isExclusive: true),
        CustomTask(name: "Sandy", points: 2),
        CustomTask(name: "Sand", points: -1, isNegative: true),
        CustomTask(name: "OB", points: -1, isNegative: true),
        CustomTask(name: "3-Putt", points: -1, isNegative: true)
    ]
    
    init(stakePerPoint: Int = 1, par3Holes: Set<Int> = []) {
        self.stakePerPoint = stakePerPoint
        self.par3Holes = par3Holes
    }
}
