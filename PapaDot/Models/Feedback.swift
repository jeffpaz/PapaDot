//  Models/Feedback.swift
import Foundation
import CloudKit
import UIKit

enum FeedbackCategory: String, Codable, CaseIterable {
    case bug = "Bug Report"
    case feature = "Feature Request"
    case general = "General Feedback"
    
    var icon: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .feature: return "lightbulb.fill"
        case .general: return "message.fill"
        }
    }
    
    var color: String {
        switch self {
        case .bug: return "red"
        case .feature: return "blue"
        case .general: return "green"
        }
    }
}

struct Feedback: Codable, Identifiable {
    var id: String = UUID().uuidString
    var category: FeedbackCategory
    var message: String
    var userName: String?
    var userEmail: String?
    var appVersion: String
    var iosVersion: String
    var deviceModel: String
    var timestamp: Date
    var recordID: String?
    
    init(category: FeedbackCategory,
         message: String,
         userName: String? = nil,
         userEmail: String? = nil) {
        self.category = category
        self.message = message
        self.userName = userName
        self.userEmail = userEmail
        self.timestamp = Date()
        
        // Capture device info
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.iosVersion = UIDevice.current.systemVersion
        self.deviceModel = UIDevice.current.model
    }
    
    // Convert to CloudKit record
    func toCKRecord() -> CKRecord {
        let record: CKRecord
        if let recordID = recordID {
            record = CKRecord(recordType: "Feedback", recordID: CKRecord.ID(recordName: recordID))
        } else {
            record = CKRecord(recordType: "Feedback")
        }
        
        record["category"] = category.rawValue
        record["message"] = message
        record["userName"] = userName
        record["userEmail"] = userEmail
        record["appVersion"] = appVersion
        record["iosVersion"] = iosVersion
        record["deviceModel"] = deviceModel
        record["timestamp"] = timestamp
        
        return record
    }
    
    // Create from CloudKit record
    static func from(_ record: CKRecord) -> Feedback? {
        guard let categoryString = record["category"] as? String,
              let category = FeedbackCategory(rawValue: categoryString),
              let message = record["message"] as? String,
              let appVersion = record["appVersion"] as? String,
              let iosVersion = record["iosVersion"] as? String,
              let deviceModel = record["deviceModel"] as? String,
              let timestamp = record["timestamp"] as? Date else {
            return nil
        }
        
        var feedback = Feedback(category: category, message: message)
        feedback.recordID = record.recordID.recordName
        feedback.userName = record["userName"] as? String
        feedback.userEmail = record["userEmail"] as? String
        feedback.appVersion = appVersion
        feedback.iosVersion = iosVersion
        feedback.deviceModel = deviceModel
        feedback.timestamp = timestamp
        
        return feedback
    }
    
    // Format for email
    func toEmailBody() -> String {
        var body = """
        Category: \(category.rawValue)
        
        Message:
        \(message)
        
        ---
        User: \(userName ?? "Anonymous")
        """
        
        if let email = userEmail {
            body += "\nEmail: \(email)"
        }
        
        body += """
        
        
        Device Info:
        App Version: \(appVersion)
        iOS Version: \(iosVersion)
        Device: \(deviceModel)
        Timestamp: \(timestamp.formatted())
        """
        
        return body
    }
}
