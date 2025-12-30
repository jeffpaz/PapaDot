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
}
