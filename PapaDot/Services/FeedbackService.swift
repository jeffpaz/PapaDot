//  Services/FeedbackService.swift
import Foundation
import CloudKit
import MessageUI

@Observable
class FeedbackService {
    private let container = CKContainer.default()
    private var publicDatabase: CKDatabase { container.publicCloudDatabase }
    
    // MARK: - CloudKit Storage
    
    /// Save feedback to CloudKit Public Database
    func saveFeedback(_ feedback: Feedback) async -> Bool {
        let record = feedback.toCKRecord()
        
        do {
            _ = try await publicDatabase.save(record)
            return true
        } catch {
            return false
        }
    }
    
    /// Fetch all feedback (for admin review)
    func fetchAllFeedback() async -> [Feedback] {
        let query = CKQuery(recordType: "Feedback", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            let results = try await publicDatabase.records(matching: query)
            
            var feedbacks: [Feedback] = []
            for result in results.matchResults {
                if let record = try? result.1.get(),
                   let feedback = Feedback.from(record) {
                    feedbacks.append(feedback)
                }
            }
            
            return feedbacks
        } catch {
            return []
        }
    }
    
    // MARK: - Email Support
    
    /// Generate mailto URL for email app
    func emailURL(for feedback: Feedback, to email: String) -> URL? {
        let subject = "PapaDot Feedback: \(feedback.category.rawValue)"
        let body = feedback.toEmailBody()
        
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "mailto:\(email)?subject=\(subjectEncoded)&body=\(bodyEncoded)"
        
        return URL(string: urlString)
    }
    
    /// Check if device can send email
    static func canSendEmail() -> Bool {
        return MFMailComposeViewController.canSendMail()
    }
}
