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
}
