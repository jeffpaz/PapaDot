//  Models/GolfCourseData.swift
import Foundation

/// Represents detailed hole-by-hole data for a golf course
struct GolfCourseData: Codable, Equatable {
    let courseName: String
    let totalPar: Int
    let par3Holes: [Int] // Hole numbers that are par 3s
    let holes: [HoleInfo]? // Optional detailed hole information
    
    init(courseName: String, totalPar: Int, par3Holes: [Int], holes: [HoleInfo]? = nil) {
        self.courseName = courseName
        self.totalPar = totalPar
        self.par3Holes = par3Holes
        self.holes = holes
    }
}

/// Detailed information for a single hole
struct HoleInfo: Codable, Equatable, Identifiable {
    var id: Int { number }
    let number: Int // 1-18
    let par: Int // 3, 4, or 5
    let yardage: Int // Distance in yards
    let handicap: Int? // Handicap rating (optional)
    
    init(number: Int, par: Int, yardage: Int, handicap: Int? = nil) {
        self.number = number
        self.par = par
        self.yardage = yardage
        self.handicap = handicap
    }
}