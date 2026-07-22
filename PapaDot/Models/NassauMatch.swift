// Models/NassauMatch.swift
import Foundation

/// A 5-5-5 Nassau side match between two players: three independent bets (front 9,
/// back 9, overall 18) settled separately. See calculateNassauResult in Helpers.swift
/// for the scoring rules.
struct NassauMatch: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var playerAID: String
    var playerBID: String
    var frontBet: Int = 5
    var backBet: Int = 5
    var overallBet: Int = 5
}
