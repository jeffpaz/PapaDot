// Models/CustomTask.swift
import Foundation

struct CustomTask: Identifiable, Codable, Equatable, Hashable {
    var id = UUID().uuidString
    var name: String
    var points: Int
    var isExclusive = false
    var isNegative = false

    // MARK: - Default Tasks
    // Single source of truth — GameRules.tasks references this directly.
    // Sandy is worth 2 points (par-3 bonus), consistent across the app.
    static var defaultTasks: [CustomTask] {
        [
            CustomTask(name: "Fairway",   points: 1, isExclusive: false, isNegative: false),
            CustomTask(name: "Birdie",    points: 3, isExclusive: false, isNegative: false),
            CustomTask(name: "Poley",     points: 1, isExclusive: false, isNegative: false),
            CustomTask(name: "Greenie",   points: 1, isExclusive: true,  isNegative: false),
            CustomTask(name: "Low Hole",  points: 1, isExclusive: true,  isNegative: false),
            CustomTask(name: "Sandy",     points: 2, isExclusive: false, isNegative: false), // Par-3 bonus = 2pts
            CustomTask(name: "Sand",      points: 1, isExclusive: false, isNegative: true),
            CustomTask(name: "OB",        points: 1, isExclusive: false, isNegative: true),
            CustomTask(name: "3-Putt",    points: 1, isExclusive: false, isNegative: true)
        ]
    }
}
