//  Services/GolfCourseAPIService.swift
import Foundation
import CoreLocation

class GolfCourseAPIService {
    // Replace with your actual API key from golfcourseapi.com
    private let apiKey = "YOUR_GOLF_COURSE_API_KEY"
    private let baseURL = "https://api.golfcourseapi.com/v1"
    
    enum APIError: LocalizedError {
        case invalidURL
        case noData
        case decodingError(String)
        case apiError(String)
        case unauthorized
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .noData:
                return "No data received"
            case .decodingError(let msg):
                return "Failed to decode: \(msg)"
            case .apiError(let msg):
                return "API Error: \(msg)"
            case .unauthorized:
                return "API key invalid or expired"
            }
        }
    }
    
    // MARK: - Search Courses by Location
    
    func searchCourses(near location: CLLocation, radius: Int = 25) async throws -> [GolfCourseSearchResult] {
        print("🏌️ === GOLF COURSE API SEARCH ===")
        print("   Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("   Radius: \(radius) miles")
        
        // Build URL for nearby search
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlString = "\(baseURL)/courses?lat=\(lat)&lon=\(lon)&radius=\(radius)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🏌️ Making request to: \(urlString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🏌️ Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
                
                if httpResponse.statusCode != 200 {
                    throw APIError.apiError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Log response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🏌️ Response (first 500 chars):")
                print(String(jsonString.prefix(500)))
            }
            
            // Decode
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let searchResponse = try decoder.decode(CourseSearchResponse.self, from: data)
            
            print("✅ Found \(searchResponse.courses?.count ?? 0) courses")
            
            return searchResponse.courses ?? []
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Get Course Details (with hole data)
    
    func getCourseDetails(courseId: String) async throws -> GolfCourseDetails {
        print("🏌️ === FETCHING COURSE DETAILS ===")
        print("   Course ID: \(courseId)")
        
        let urlString = "\(baseURL)/courses/\(courseId)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🏌️ Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    throw APIError.apiError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Log response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🏌️ Course details (first 1000 chars):")
                print(String(jsonString.prefix(1000)))
            }
            
            // Decode
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let courseDetails = try decoder.decode(GolfCourseDetails.self, from: data)
            
            print("✅ Loaded course: \(courseDetails.name)")
            print("   Holes: \(courseDetails.holes?.count ?? 0)")
            
            return courseDetails
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Response Models

struct CourseSearchResponse: Decodable {
    let courses: [GolfCourseSearchResult]?
}

struct GolfCourseSearchResult: Decodable, Identifiable {
    let id: String
    let name: String
    let address: String?
    let city: String?
    let state: String?
    let zipCode: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
    let phoneNumber: String?
    let website: String?
    
    var fullAddress: String {
        [address, city, state, zipCode].compactMap { $0 }.joined(separator: ", ")
    }
}

struct GolfCourseDetails: Decodable {
    let id: String
    let name: String
    let address: String?
    let holes: [HoleData]?
    let totalPar: Int?
    let totalYardage: Int?
}

struct HoleData: Decodable, Identifiable {
    let id: String?
    let holeNumber: Int
    let par: Int
    let yardage: Int?
    let handicap: Int?
    
    var isPar3: Bool {
        par == 3
    }
}