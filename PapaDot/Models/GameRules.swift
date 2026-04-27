// Models/GameRules.swift
import Foundation

struct GameRules: Codable, Equatable {
    var stakePerPoint = 1
    var par3Holes: Set<Int> = []
    var currentGreenieValue = 1
    var currentLowHoleValue = 1
    var allowGuestsToScore = true
    var isTeamMode = false

    // Uses CustomTask.defaultTasks as the single source of truth.
    // Previously tasks were duplicated here with inconsistent point values.
    var tasks: [CustomTask] = CustomTask.defaultTasks

    init(stakePerPoint: Int = 1, par3Holes: Set<Int> = []) {
        self.stakePerPoint = stakePerPoint
        self.par3Holes = par3Holes

        // Initialize carry-over values to base points from tasks
        self.currentGreenieValue = tasks.first(where: { $0.name == "Greenie" })?.points ?? 1
        self.currentLowHoleValue = tasks.first(where: { $0.name == "Low Hole" })?.points ?? 1
    }
}
