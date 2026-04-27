// Models/CustomTask.swift
import Foundation

struct CustomTask: Identifiable, Codable, Equatable, Hashable {
    var id = UUID().uuidString
    var name: String
    var points: Int
    var isExclusive = false
    var isNegative = false
    var hasCarryOver = false  // If true, value increments when no one scores it

    // MARK: - Default Tasks
    // Single source of truth — GameRules.tasks references this directly.
    static var defaultTasks: [CustomTask] {
        [
            CustomTask(name: "Fairway",   points: 1, isExclusive: false, isNegative: false, hasCarryOver: false),
            CustomTask(name: "Birdie",    points: 3, isExclusive: false, isNegative: false, hasCarryOver: false),
            CustomTask(name: "Poley",     points: 1, isExclusive: false, isNegative: false, hasCarryOver: false),
            CustomTask(name: "Greenie",   points: 2, isExclusive: true,  isNegative: false, hasCarryOver: true),
            CustomTask(name: "Low Hole",  points: 2, isExclusive: true,  isNegative: false, hasCarryOver: true),
            CustomTask(name: "Sandy",     points: 1, isExclusive: false, isNegative: false, hasCarryOver: false),
            CustomTask(name: "Sand",      points: 1, isExclusive: false, isNegative: true,  hasCarryOver: false),
            CustomTask(name: "OB",        points: 1, isExclusive: false, isNegative: true,  hasCarryOver: false),
            CustomTask(name: "3-Putt",    points: 1, isExclusive: false, isNegative: true,  hasCarryOver: false)
        ]
    }
}
