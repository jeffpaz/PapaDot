// Models/CustomTask.swift
import Foundation

struct CustomTask: Identifiable, Codable, Equatable, Hashable {
    var id = UUID().uuidString
    var name: String
    var points: Int
    var isExclusive = false
    var isNegative = false
    var hasCarryOver = false
    var isRepeatable = false  // If true, scored as a count 0–3 rather than a Bool toggle
    var carryOverLimitEnabled = false
    var carryOverLimit: Int = 3
    var carryOverResetToZero = false

    // MARK: - Default Tasks
    static var defaultTasks: [CustomTask] {
        [
            CustomTask(name: "Fairway",    points: 1, isExclusive: false, isNegative: false, hasCarryOver: false, isRepeatable: false),
            CustomTask(name: "Birdie",     points: 3, isExclusive: false, isNegative: false, hasCarryOver: false, isRepeatable: false),
            CustomTask(name: "Poley",      points: 1, isExclusive: false, isNegative: false, hasCarryOver: false, isRepeatable: false),
            CustomTask(name: "Greenie",    points: 2, isExclusive: true,  isNegative: false, hasCarryOver: true,  isRepeatable: false),
            CustomTask(name: "Low Hole",   points: 2, isExclusive: true,  isNegative: false, hasCarryOver: true,  isRepeatable: false),
            CustomTask(name: "Sandy",      points: 1, isExclusive: false, isNegative: false, hasCarryOver: false, isRepeatable: false),
            CustomTask(name: "Sand",       points: 1, isExclusive: false, isNegative: true,  hasCarryOver: false, isRepeatable: true),
            CustomTask(name: "OB",         points: 1, isExclusive: false, isNegative: true,  hasCarryOver: false, isRepeatable: true),
            CustomTask(name: "3-Putt",     points: 1, isExclusive: false, isNegative: true,  hasCarryOver: false, isRepeatable: false),
            CustomTask(name: "4-Putt",     points: 3, isExclusive: false, isNegative: true,  hasCarryOver: false, isRepeatable: false),
            CustomTask(name: "Lady's Tee", points: 3, isExclusive: false, isNegative: true,  hasCarryOver: false, isRepeatable: false)
        ]
    }
}

// Custom decoder so records saved before isRepeatable was added still decode correctly.
extension CustomTask {
    private enum CodingKeys: String, CodingKey {
        case id, name, points, isExclusive, isNegative, hasCarryOver, isRepeatable
        case carryOverLimitEnabled, carryOverLimit, carryOverResetToZero
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                    = try c.decodeIfPresent(String.self, forKey: .id)                    ?? UUID().uuidString
        name                  = try c.decode(String.self,           forKey: .name)
        points                = try c.decode(Int.self,               forKey: .points)
        isExclusive           = try c.decodeIfPresent(Bool.self,    forKey: .isExclusive)           ?? false
        isNegative            = try c.decodeIfPresent(Bool.self,    forKey: .isNegative)            ?? false
        hasCarryOver          = try c.decodeIfPresent(Bool.self,    forKey: .hasCarryOver)          ?? false
        isRepeatable          = try c.decodeIfPresent(Bool.self,    forKey: .isRepeatable)          ?? false
        carryOverLimitEnabled = try c.decodeIfPresent(Bool.self,    forKey: .carryOverLimitEnabled) ?? false
        carryOverLimit        = try c.decodeIfPresent(Int.self,     forKey: .carryOverLimit)        ?? 3
        carryOverResetToZero  = try c.decodeIfPresent(Bool.self,    forKey: .carryOverResetToZero)  ?? false
    }
}
