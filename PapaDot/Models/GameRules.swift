// Models/GameRules.swift
import Foundation

struct GameRules: Codable, Equatable {
    var stakePerPoint = 1
    var par3Holes: Set<Int> = []
    var currentGreenieValue = 1
    var allowGuestsToScore = true

    // Uses CustomTask.defaultTasks as the single source of truth.
    // Previously tasks were duplicated here with inconsistent point values.
    var tasks: [CustomTask] = CustomTask.defaultTasks

    init(stakePerPoint: Int = 1, par3Holes: Set<Int> = []) {
        self.stakePerPoint = stakePerPoint
        self.par3Holes = par3Holes
    }
}
