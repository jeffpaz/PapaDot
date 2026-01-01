//
//  CustomTask.swift
//  PapaDot
//
//  Created by Jeff Pazahanick on 12/1/25.
//

import Foundation

struct CustomTask: Identifiable, Codable, Equatable, Hashable {
    var id = UUID().uuidString
    var name: String
    var points: Int
    var isExclusive = false
    var isNegative = false
    
    /// Default tasks that come with the game
    static var defaultTasks: [CustomTask] {
        [
            CustomTask(name: "Fairway", points: 1, isExclusive: false, isNegative: false),
            CustomTask(name: "Birdie", points: 3, isExclusive: false, isNegative: false),
            CustomTask(name: "Poley", points: 1, isExclusive: false, isNegative: false),
            CustomTask(name: "Greenie", points: 1, isExclusive: true, isNegative: false),
            CustomTask(name: "Low Hole", points: 1, isExclusive: true, isNegative: false),
            CustomTask(name: "Sandy", points: 1, isExclusive: false, isNegative: false),
            CustomTask(name: "Sand", points: 1, isExclusive: false, isNegative: true),
            CustomTask(name: "OB", points: 1, isExclusive: false, isNegative: true),
            CustomTask(name: "3-Putt", points: 1, isExclusive: false, isNegative: true)
        ]
    }
}
