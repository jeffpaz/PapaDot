//  Models/GolfCourseData.swift
import Foundation
import CloudKit

struct GolfCourseData: Codable, Equatable {
    var recordID: String?
    var courseID: String           // Google Places ID
    var courseName: String
    var holePars: [Int]            // 18 values: [4,3,5,4,4,3...]
    var totalPar: Int
    var contributedBy: String?     // Optional: User's name
    var contributedDate: Date
    var verificationCount: Int     // How many users confirmed it's correct
    var lastModified: Date
    
    // Computed property: Get Par 3 hole numbers
    var par3Holes: Set<Int> {
        Set(holePars.enumerated()
            .filter { $0.element == 3 }
            .map { $0.offset + 1 })  // Convert to 1-based hole numbers
    }
    
    init(courseID: String, 
         courseName: String, 
         holePars: [Int], 
         contributedBy: String? = nil) {
        self.recordID = nil
        self.courseID = courseID
        self.courseName = courseName
        self.holePars = holePars
        self.totalPar = holePars.reduce(0, +)
        self.contributedBy = contributedBy
        self.contributedDate = Date()
        self.verificationCount = 1
        self.lastModified = Date()
    }
    
    // Convert to CloudKit record
    func toCKRecord() -> CKRecord {
        let record: CKRecord
        if let recordID = recordID {
            record = CKRecord(recordType: "GolfCourseData", recordID: CKRecord.ID(recordName: recordID))
        } else {
            record = CKRecord(recordType: "GolfCourseData")
        }
        
        record["courseID"] = courseID
        record["courseName"] = courseName
        record["holeParsJSON"] = try? JSONEncoder().encode(holePars)
        record["totalPar"] = totalPar
        record["contributedBy"] = contributedBy
        record["contributedDate"] = contributedDate
        record["verificationCount"] = verificationCount
        record["lastModified"] = lastModified
        
        return record
    }
    
    // Create from CloudKit record
    static func from(_ record: CKRecord) -> GolfCourseData? {
        guard let courseID = record["courseID"] as? String,
              let courseName = record["courseName"] as? String,
              let holeParsData = record["holeParsJSON"] as? Data,
              let holePars = try? JSONDecoder().decode([Int].self, from: holeParsData),
              holePars.count == 18 else {
            return nil
        }
        
        var data = GolfCourseData(
            courseID: courseID,
            courseName: courseName,
            holePars: holePars,
            contributedBy: record["contributedBy"] as? String
        )
        
        data.recordID = record.recordID.recordName
        data.totalPar = record["totalPar"] as? Int ?? holePars.reduce(0, +)
        data.contributedDate = record["contributedDate"] as? Date ?? Date()
        data.verificationCount = record["verificationCount"] as? Int ?? 1
        data.lastModified = record["lastModified"] as? Date ?? Date()
        
        return data
    }
}
