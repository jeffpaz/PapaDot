// Models/GameRules.swift
import Foundation

struct GameRules: Codable, Equatable {
    var stakePerPoint = 1
    var par3Holes: Set<Int> = []
    var currentGreenieValue = 1
    var currentLowHoleValue = 1
    var isTeamMode = false
    var startingHole: Int = 1
    var maxOwedEnabled: Bool = false
    var maxOwedAmount: Int = 20
    var useHandicap: Bool = true

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

    // Custom decoder so missing keys in older saved records fall back to defaults
    // rather than throwing, which would wipe out the entire history on schema evolution.
    private enum CodingKeys: String, CodingKey {
        case stakePerPoint, par3Holes, currentGreenieValue, currentLowHoleValue
        case isTeamMode, startingHole, tasks
        case maxOwedEnabled, maxOwedAmount, useHandicap
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stakePerPoint        = try c.decodeIfPresent(Int.self,          forKey: .stakePerPoint)        ?? 1
        par3Holes            = try c.decodeIfPresent(Set<Int>.self,      forKey: .par3Holes)            ?? []
        currentGreenieValue  = try c.decodeIfPresent(Int.self,          forKey: .currentGreenieValue)  ?? 1
        currentLowHoleValue  = try c.decodeIfPresent(Int.self,          forKey: .currentLowHoleValue)  ?? 1
        isTeamMode           = try c.decodeIfPresent(Bool.self,         forKey: .isTeamMode)           ?? false
        startingHole         = try c.decodeIfPresent(Int.self,          forKey: .startingHole)         ?? 1
        tasks                = try c.decodeIfPresent([CustomTask].self, forKey: .tasks)                ?? CustomTask.defaultTasks
        maxOwedEnabled       = try c.decodeIfPresent(Bool.self,         forKey: .maxOwedEnabled)       ?? false
        maxOwedAmount        = try c.decodeIfPresent(Int.self,          forKey: .maxOwedAmount)        ?? 20
        useHandicap          = try c.decodeIfPresent(Bool.self,         forKey: .useHandicap)          ?? true
    }
}
