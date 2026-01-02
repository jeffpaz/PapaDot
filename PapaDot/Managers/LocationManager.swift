//  Managers/LocationManager.swift
import SwiftUI
import CoreLocation
import Combine

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var location: CLLocation?
    var authorizationStatus: CLAuthorizationStatus?
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
        
        print("📍 LocationManager init - Current status: \(authorizationStatus?.rawValue ?? -1)")
        
        // CRITICAL FIX: Request permission on init if not determined
        if authorizationStatus == .notDetermined {
            print("📍 Requesting location permission...")
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            print("📍 Already authorized, requesting location...")
            manager.requestLocation()
        } else {
            print("📍 Location denied or restricted")
        }
    }
    
    func requestLocation() {
        print("📍 requestLocation() called")
        print("   Current status: \(authorizationStatus?.rawValue ?? -1)")
        
        if authorizationStatus == .notDetermined {
            print("   → Requesting authorization...")
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            print("   → Requesting location update...")
            manager.requestLocation()
        } else {
            print("   → Not authorized (status: \(authorizationStatus?.rawValue ?? -1))")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
        print("📍 Location updated: \(location?.coordinate.latitude ?? 0), \(location?.coordinate.longitude ?? 0)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location error: \(error.localizedDescription)")
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                print("   → User denied location access")
                print("   → Go to Settings → PapaDot → Location → While Using the App")
            case .locationUnknown:
                print("   → Location unknown - will try again")
            default:
                print("   → Error code: \(clError.code.rawValue)")
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let oldStatus = authorizationStatus
        authorizationStatus = manager.authorizationStatus
        
        print("📍 Authorization changed: \(oldStatus?.rawValue ?? -1) → \(authorizationStatus?.rawValue ?? -1)")
        
        if isAuthorized {
            print("   → Now authorized! Requesting location...")
            manager.requestLocation()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            print("   → Access denied/restricted")
            print("   → User must enable in Settings → PapaDot → Location")
        }
    }
}
