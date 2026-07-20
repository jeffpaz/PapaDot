//
//  Player.swift
//  PapaDot
//
//  Created by Jeff Pazahanick on 12/1/25.
//

import Foundation

struct Player: Identifiable, Codable, Equatable, Hashable {
    var id = UUID().uuidString
    var name: String
    let phoneNumber: String
    var handicap: Int = 0 // 0-36, default 0 (scratch golfer)
    var lastUsedHandicap: Int = 0
}

// Custom decoder so records saved before lastUsedHandicap was added still decode correctly.
extension Player {
    private enum CodingKeys: String, CodingKey {
        case id, name, phoneNumber, handicap, lastUsedHandicap
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decodeIfPresent(String.self, forKey: .id)              ?? UUID().uuidString
        name             = try c.decode(String.self,          forKey: .name)
        phoneNumber      = try c.decode(String.self,          forKey: .phoneNumber)
        handicap         = try c.decodeIfPresent(Int.self,    forKey: .handicap)         ?? 0
        // -1 sentinel: field absent in records predating this feature.
        // Distinguished from 0 (genuine scratch golfer) in lookupLastHandicap.
        lastUsedHandicap = try c.decodeIfPresent(Int.self,    forKey: .lastUsedHandicap) ?? -1
    }
}
