//  Models/GolfCourse.swift
import Foundation
import CoreLocation

struct GolfCourse: Codable, Identifiable, Equatable {
    let id: String // Google Place ID
    let name: String
    let address: String
    let coordinate: Coordinate
    let phoneNumber: String?
    let rating: Double?
    let userRatingsTotal: Int?
    
    struct Coordinate: Codable, Equatable {
        let latitude: Double
        let longitude: Double
        
        var clLocationCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
        
        init(from clCoordinate: CLLocationCoordinate2D) {
            self.latitude = clCoordinate.latitude
            self.longitude = clCoordinate.longitude
        }
    }
    
    func distance(from location: CLLocation) -> CLLocationDistance {
        let courseLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        return location.distance(from: courseLocation)
    }
    
    func distanceInMiles(from location: CLLocation) -> Double {
        distance(from: location) / 1609.34
    }
}
