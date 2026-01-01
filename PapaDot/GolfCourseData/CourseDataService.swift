//  Services/CourseDataService.swift
import Foundation
import CloudKit

@Observable
class CourseDataService {
    private let container = CKContainer.default()
    private var publicDatabase: CKDatabase { container.publicCloudDatabase }
    
    // Fetch course data by Google Places ID
    func fetchCourseData(for courseID: String) async -> GolfCourseData? {
        let predicate = NSPredicate(format: "courseID == %@", courseID)
        let query = CKQuery(recordType: "GolfCourseData", predicate: predicate)
        
        do {
            let results = try await publicDatabase.records(matching: query)
            
            // Get the first record (should only be one per courseID)
            if let record = results.matchResults.first?.1 {
                let ckRecord = try record.get()
                return GolfCourseData.from(ckRecord)
            }
            
            return nil
        } catch {
            print("❌ Failed to fetch course data: \(error)")
            return nil
        }
    }
    
    // Save new course data
    func saveCourseData(_ courseData: GolfCourseData) async -> Bool {
        let record = courseData.toCKRecord()
        
        do {
            _ = try await publicDatabase.save(record)
            print("✅ Course data saved successfully")
            return true
        } catch {
            print("❌ Failed to save course data: \(error)")
            return false
        }
    }
    
    // Verify/upvote existing course data
    func verifyCourseData(recordID: String) async -> Bool {
        do {
            let ckRecordID = CKRecord.ID(recordName: recordID)
            let record = try await publicDatabase.record(for: ckRecordID)
            
            // Increment verification count
            let currentCount = record["verificationCount"] as? Int ?? 1
            record["verificationCount"] = currentCount + 1
            record["lastModified"] = Date()
            
            _ = try await publicDatabase.save(record)
            print("✅ Course data verified")
            return true
        } catch {
            print("❌ Failed to verify course data: \(error)")
            return false
        }
    }
    
    // Report incorrect data (for future moderation features)
    func reportIncorrectData(recordID: String) async {
        // For now, just log it
        // In the future, you could create a "Reports" record type
        print("⚠️ Course data reported as incorrect: \(recordID)")
    }
}
