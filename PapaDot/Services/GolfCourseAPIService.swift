// Services/GolfCourseAPIService.swift
import Foundation
import CoreLocation

// MARK: - Combined Golf API Service
// Handles both Golf Course API (for course details) and Google Places API (for course search)
//
// ⚠️ API KEYS: Store keys in Config.xcconfig (not committed to git), referenced via Info.plist:
//   GOLF_API_KEY = YOUR_KEY_HERE
//   GOOGLE_API_KEY = YOUR_KEY_HERE
// Then in Info.plist add:
//   GolfAPIKey  → $(GOLF_API_KEY)
//   GoogleAPIKey → $(GOOGLE_API_KEY)

class GolfCourseAPIService {

    // MARK: - API Keys (loaded from Info.plist, never hardcoded)
    private var golfApiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GolfAPIKey") as? String ?? ""
    }

    private var googleApiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GoogleAPIKey") as? String ?? ""
    }

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
        guard !googleApiKey.isEmpty else {
            throw APIError.noAPIKey
        }

        let baseURL = "https://places.googleapis.com/v1/places:searchNearby"

        guard let url = URL(string: baseURL) else {
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
        request.setValue(
            "places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )

        let bundleID = Bundle.main.bundleIdentifier ?? "com.jeffpaz.PapaDot"
        request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.setValue("bundle://\(bundleID)", forHTTPHeaderField: "Referer")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let placesResponse = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)

        guard let places = placesResponse.places, !places.isEmpty else {
            throw APIError.noResults
        }

        let courses = places.compactMap { place -> GolfCourse? in
            guard let lat = place.location?.latitude,
                  let lng = place.location?.longitude,
                  let name = place.displayName?.text else {
                return nil
            }
            let address = place.formattedAddress ?? ""
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

        return courses
    }

    // MARK: - Golf Course API (Course Details)

    func searchCoursesByName(_ query: String) async throws -> [GolfCourseSearchResult] {
        guard !golfApiKey.isEmpty else { throw APIError.noAPIKey }

        let baseURL = "https://api.golfcourseapi.com/v1/search"
        let queryParam = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)?search_query=\(queryParam)"

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Key \(golfApiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw APIError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }

        do {
            let searchResponse = try JSONDecoder().decode(GolfCourseSearchResponse.self, from: data)
            return searchResponse.courses
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    func getCourseDetails(courseId: String) async throws -> GolfCourseDetailsResponse {
        guard !golfApiKey.isEmpty else { throw APIError.noAPIKey }

        let baseURL = "https://api.golfcourseapi.com/v1/courses/\(courseId)"

        guard let url = URL(string: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Key \(golfApiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw APIError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }

        do {
            return try JSONDecoder().decode(GolfCourseDetailsResponse.self, from: data)
        } catch {
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
        if let maleTees = course.tees?.male?.first(where: { ($0.holes?.count ?? 0) == 18 }) {
            return maleTees.holes
        }
        if let femaleTees = course.tees?.female?.first(where: { ($0.holes?.count ?? 0) == 18 }) {
            return femaleTees.holes
        }
        return nil
    }
}
