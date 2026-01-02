//  Models/HolePhoto.swift
import Foundation
import UIKit

struct HolePhoto: Codable, Identifiable, Equatable {
    let id: String
    let holeNumber: Int
    let imageData: Data
    let timestamp: Date
    let caption: String?
    
    init(id: String = UUID().uuidString, holeNumber: Int, image: UIImage, caption: String? = nil) {
        self.id = id
        self.holeNumber = holeNumber
        // Compress to JPEG at 70% quality to save space
        self.imageData = image.jpegData(compressionQuality: 0.7) ?? Data()
        self.timestamp = Date()
        self.caption = caption
    }
    
    // Reconstruct UIImage from data
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    // Formatted timestamp
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    // For CloudKit encoding
    var dictionaryRepresentation: [String: Any] {
        [
            "id": id,
            "holeNumber": holeNumber,
            "imageData": imageData,
            "timestamp": timestamp,
            "caption": caption as Any
        ]
    }
    
    static func == (lhs: HolePhoto, rhs: HolePhoto) -> Bool {
        lhs.id == rhs.id
    }
}
