// Services/GolfCourseAPIService.swift
import Foundation
import CoreLocation

// MARK: - Combined Golf API Service
// Handles both Golf Course API (for course details) and Google Places API (for course search)

class GolfCourseAPIService {
    // Golf Course API Key
    private let golfApiKey = "FJ5ICSRCEOTCPDV6DQCJKMA5SM"
    
    // Google Places API Key
    private let googleApiKey = "AIzaSyB8KMvHSd-tN9N7sRRSn2bmvwakkJ9Q3wE"
    
    enum APIError: LocalizedError {
        case invalidURL
        case noData
        case decodingError(String)
        case apiError(String)
        case noResults
        case noAPIKey
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL for API request"
            case .noData: return "No data received from server"
            case .decodingError(let details): return "Failed to decode response: \(details)"
            case .apiError(let message): return "API Error: \(message)"
            case .noResults: return "No results found"
            case .noAPIKey: return "API key not configured"
            }
        }
    }
    
    // MARK: - Google Places API (Course Search)
    
    func searchNearbyGolfCourses(near location: CLLocation, radius: Int) async throws -> [GolfCourse] {
        print("🌐 === GOOGLE PLACES API SEARCH ===")
        print("   Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("   Radius: \(radius)m (~\(radius / 1609) miles)")
        print("   API Key: \(googleApiKey.prefix(10))...***")
        
        let baseURL = "https://places.googleapis.com/v1/places:searchNearby"
        
        guard let url = URL(string: baseURL) else {
            print("❌ Failed to create URL")
            throw APIError.invalidURL
        }
        
        let requestBody: [String: Any] = [
            "includedTypes": ["golf_course"],
            "maxResultCount": 20,
            "locationRestriction": [
                "circle": [
                    "center": [
                        "latitude": location.coordinate.latitude,
                        "longitude": location.coordinate.longitude
                    ],
                    "radius": Double(radius)
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(googleApiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount", forHTTPHeaderField: "X-Goog-FieldMask")
        
        // Try ALL possible bundle ID header formats
        let bundleID = Bundle.main.bundleIdentifier ?? "com.jeffpaz.PapaDot"
        print("📱 Attempting to send Bundle ID: \(bundleID)")
        print("   Bundle.main.bundleIdentifier = \(String(describing: Bundle.main.bundleIdentifier))")
        
        // Try multiple header formats (Google APIs use different ones)
        request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.setValue(bundleID, forHTTPHeaderField: "X-iOS-Bundle-Identifier")  // Capital iOS
        request.setValue(bundleID, forHTTPHeaderField: "X-Goog-Api-Key-Ios-Bundle-Id")
        request.setValue(bundleID, forHTTPHeaderField: "X-Apple-App-Id")
        
        // Also try Referer format
        request.setValue("bundle://\(bundleID)", forHTTPHeaderField: "Referer")
        
        print("   Headers being sent:")
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            print("      \(key): \(value)")
        }
        
        request.httpBody = jsonData
        
        print("🌐 Request URL: \(baseURL)")
       
        request.httpBody = jsonData

        print("🌐 Request URL: \(baseURL)")
        
        
        print("🌐 Request body: \(String(data: jsonData, encoding: .utf8) ?? "nil")")
        print("🌐 Making request...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🌐 HTTP Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Error response: \(errorString)")
                }
                throw APIError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🌐 Response (first 1000 chars):")
            print(String(jsonString.prefix(1000)))
        }
        
        let placesResponse = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
        
        guard let places = placesResponse.places, !places.isEmpty else {
            print("⚠️ No results found")
            throw APIError.noResults
        }
        
        print("✅ Found \(places.count) places")
        
        let courses = places.compactMap { place -> GolfCourse? in
            guard let lat = place.location?.latitude,
                  let lng = place.location?.longitude,
                  let name = place.displayName?.text else {
                return nil
            }
            
            let address = place.formattedAddress ?? ""
            print("   ✓ \(name) - \(address)")
            
            return GolfCourse(
                id: place.id ?? UUID().uuidString,
                name: name,
                address: address,
                coordinate: GolfCourse.Coordinate(latitude: lat, longitude: lng),
                phoneNumber: nil,
                rating: place.rating,
                userRatingsTotal: place.userRatingCount
            )
        }
        
        print("✅ Successfully converted \(courses.count) valid courses")
        print("🌐 === END GOOGLE PLACES API SEARCH ===")
        return courses
    }
    
    // MARK: - Golf Course API (Course Details)
    
    func searchCoursesByName(_ query: String) async throws -> [GolfCourseSearchResult] {
        print("🌐 Golf Course API Request:")
        print("   URL: https://api.golfcourseapi.com/v1/search?search_query=\(query)")
        print("   Query: \(query)")
        
        let baseURL = "https://api.golfcourseapi.com/v1/search"
        let queryParam = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)?search_query=\(queryParam)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        // Golf Course API uses Authorization header with "Key " prefix
        request.setValue("Key \(golfApiKey)", forHTTPHeaderField: "Authorization")
        
        print("   Golf API Key being sent: Key \(golfApiKey.prefix(10))...***")
        print("   Request headers:")
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            if key.lowercased().contains("auth") {
                print("      \(key): Key \(String(value.dropFirst(4).prefix(10)))...***")
            } else {
                print("      \(key): \(value)")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   HTTP Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Response (first 500 chars): \(String(responseString.prefix(500)))")
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        do {
            let searchResponse = try JSONDecoder().decode(GolfCourseSearchResponse.self, from: data)
            print("   ✅ Successfully decoded \(searchResponse.courses.count) courses")
            print("   Found \(searchResponse.courses.count) results")
            return searchResponse.courses
        } catch {
            print("   ❌ Decoding error: \(error)")
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    func getCourseDetails(courseId: String) async throws -> GolfCourseDetailsResponse {
        print("🔍 Fetching details for course ID: \(courseId)")
        
        let baseURL = "https://api.golfcourseapi.com/v1/courses/\(courseId)"
        print("   URL: \(baseURL)")
        
        guard let url = URL(string: baseURL) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        // Golf Course API uses Authorization header with "Key " prefix
        request.setValue("Key \(golfApiKey)", forHTTPHeaderField: "Authorization")
        
        print("   Golf API Key being sent: Key \(golfApiKey.prefix(10))...***")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("   HTTP Status: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Raw response (first 1000 chars):")
                print(String(responseString.prefix(1000)))
            }
            
            guard httpResponse.statusCode == 200 else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   Error response: \(responseString)")
                }
                throw APIError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        do {
            let details = try JSONDecoder().decode(GolfCourseDetailsResponse.self, from: data)
            print("   Decoded course ID: \(details.course.id)")
            print("   Has male tees: \(details.course.tees?.male != nil)")
            print("   Has female tees: \(details.course.tees?.female != nil)")
            
            if let maleTees = details.course.tees?.male {
                print("   Male tees count: \(maleTees.count)")
                for (idx, tee) in maleTees.enumerated() {
                    let holeCount = tee.holes?.count ?? 0
                    print("      Tee \(idx): \(tee.teeName), holes: \(holeCount)")
                }
            }
            
            if let femaleTees = details.course.tees?.female {
                print("   Female tees count: \(femaleTees.count)")
            }
            
            let holeCount = details.holes?.count ?? 0
            print("   Final holes count: \(holeCount)")
            
            return details
        } catch {
            print("   ❌ Decoding error: \(error)")
            throw APIError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Google Places Response Models

private struct GooglePlacesResponse: Decodable {
    let places: [GooglePlace]?
}

private struct GooglePlace: Decodable {
    let id: String?
    let displayName: GoogleDisplayName?
    let formattedAddress: String?
    let location: GoogleLatLng?
    let rating: Double?
    let userRatingCount: Int?
}

private struct GoogleDisplayName: Decodable {
    let text: String?
}

private struct GoogleLatLng: Decodable {
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Golf Course API Response Models

struct GolfCourseSearchResponse: Codable {
    let courses: [GolfCourseSearchResult]
}

struct GolfCourseSearchResult: Codable, Identifiable {
    let id: Int
    let clubName: String
    let courseName: String
    let location: CourseLocation
    let tees: TeesCollection?
    
    enum CodingKeys: String, CodingKey {
        case id
        case clubName = "club_name"
        case courseName = "course_name"
        case location
        case tees
    }
}

struct CourseLocation: Codable {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
}

struct TeesCollection: Codable {
    let male: [TeeSearchResult]?
    let female: [TeeSearchResult]?
}

struct TeeSearchResult: Codable {
    let teeName: String
    let courseRating: Double?
    let slopeRating: Double?
    let totalYards: Int?
    let parTotal: Int?
    let holes: [APIHole]?
    
    enum CodingKeys: String, CodingKey {
        case teeName = "tee_name"
        case courseRating = "course_rating"
        case slopeRating = "slope_rating"
        case totalYards = "total_yards"
        case parTotal = "par_total"
        case holes
    }
}

struct APIHole: Codable {
    let holeNumber: Int?
    let par: Int
    let yardage: Int?
    let handicap: Int?
    
    enum CodingKeys: String, CodingKey {
        case holeNumber = "hole_number"
        case par
        case yardage
        case handicap
    }
}

struct GolfCourseDetailsResponse: Codable {
    let course: CourseDetail
}

struct CourseDetail: Codable {
    let id: Int
    let clubName: String
    let courseName: String
    let location: CourseLocation
    let tees: TeesCollection?
    
    enum CodingKeys: String, CodingKey {
        case id
        case clubName = "club_name"
        case courseName = "course_name"
        case location
        case tees
    }
}

extension GolfCourseDetailsResponse {
    var holes: [APIHole]? {
        // Prefer male tees, fall back to female
        if let maleTees = course.tees?.male?.first(where: { ($0.holes?.count ?? 0) == 18 }) {
            return maleTees.holes
        }
        if let femaleTees = course.tees?.female?.first(where: { ($0.holes?.count ?? 0) == 18 }) {
            return femaleTees.holes
        }
        return nil
    }
}
