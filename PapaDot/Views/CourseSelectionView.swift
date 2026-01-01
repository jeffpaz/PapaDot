//  Views/CourseSelectionView.swift
import SwiftUI
import MapKit

struct CourseSelectionView: View {
    @Environment(\.dismiss) var dismiss
    let onSelect: (GolfCourse) -> Void
    let onSelectWithData: ((GolfCourse, GolfCourseData?) -> Void)? // NEW: Optional callback with data
    
    @State private var locationManager = LocationManager()
    @State private var courses: [GolfCourse] = []
    @State private var selectedCourse: GolfCourse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchRadius = 25000 // meters (~15 miles)
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingManualEntry = false
    
    init(onSelect: @escaping (GolfCourse) -> Void, onSelectWithData: ((GolfCourse, GolfCourseData?) -> Void)? = nil) {
        self.onSelect = onSelect
        self.onSelectWithData = onSelectWithData
    }
    
    private var sortedCourses: [GolfCourse] {
        guard let userLocation = locationManager.location else {
            return courses
        }
        return courses.sorted {
            $0.distance(from: userLocation) < $1.distance(from: userLocation)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.4, blue: 0.2),
                        Color(red: 0.05, green: 0.25, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Map View
                    if locationManager.isAuthorized && !courses.isEmpty {
                        Map(position: $cameraPosition) {
                            // User location
                            if let userLocation = locationManager.location {
                                Annotation("Your Location", coordinate: userLocation.coordinate) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 20, height: 20)
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }
                            
                            // Golf courses
                            ForEach(courses) { course in
                                Annotation(course.name, coordinate: course.coordinate.clLocationCoordinate) {
                                    Button {
                                        selectedCourse = course
                                        withAnimation {
                                            cameraPosition = .camera(
                                                MapCamera(
                                                    centerCoordinate: course.coordinate.clLocationCoordinate,
                                                    distance: 5000
                                                )
                                            )
                                        }
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(selectedCourse?.id == course.id ? Color.green : Color.white)
                                                .frame(width: 32, height: 32)
                                            
                                            Image(systemName: "flag.fill")
                                                .foregroundStyle(selectedCourse?.id == course.id ? .white : .green)
                                                .font(.caption)
                                        }
                                        .shadow(radius: 3)
                                    }
                                }
                            }
                        }
                        .frame(height: 250)
                        .cornerRadius(0)
                    }
                    
                    // Course List
                    if isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                            Text("Finding nearby courses...")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxHeight: .infinity)
                    } else if let error = errorMessage {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.yellow)
                            Text(error)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Try Again") {
                                Task { await loadCourses() }
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .frame(maxHeight: .infinity)
                    } else if !locationManager.isAuthorized {
                        VStack(spacing: 20) {
                            Image(systemName: "location.slash.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text("Location Access Needed")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            
                            Text("We need your location to find nearby golf courses")
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button {
                                locationManager.requestLocation()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "location.fill")
                                    Text("Enable Location")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    } else if courses.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "map")
                                .font(.system(size: 50))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("No courses found nearby")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("Try increasing the search radius or enter manually")
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button {
                                showingManualEntry = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Enter Course Manually")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                // Header
                                HStack {
                                    Image(systemName: "map.fill")
                                        .foregroundStyle(.white.opacity(0.7))
                                    Text("\(courses.count) Courses Found")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    
                                    Button {
                                        showingManualEntry = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.caption)
                                            Text("Add")
                                                .font(.caption.bold())
                                        }
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                
                                // Course Cards
                                ForEach(sortedCourses) { course in
                                    CourseCard(
                                        course: course,
                                        userLocation: locationManager.location,
                                        isSelected: selectedCourse?.id == course.id,
                                        onTap: {
                                            selectedCourse = course
                                            withAnimation {
                                                cameraPosition = .camera(
                                                    MapCamera(
                                                        centerCoordinate: course.coordinate.clLocationCoordinate,
                                                        distance: 5000
                                                    )
                                                )
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.bottom, 100)
                        }
                    }
                }
                
                // Select Button (floating)
                if let selected = selectedCourse {
                    VStack {
                        Spacer()
                        Button {
                            onSelect(selected)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Select \(selected.name)")
                                    .lineLimit(1)
                            }
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(radius: 10)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Select Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
            .task {
                if locationManager.isAuthorized {
                    await loadCourses()
                }
            }
            .onChange(of: locationManager.isAuthorized) { _, isAuthorized in
                if isAuthorized {
                    Task { await loadCourses() }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualCourseEntryView(
                    onSave: { _ in },  // Dummy callback for backward compatibility
                    onComplete: { course, courseData in
                        // Use the new callback if available, passing both course and data
                        if let onSelectWithData = onSelectWithData {
                            onSelectWithData(course, courseData)
                        } else {
                            onSelect(course)
                        }
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - Load Courses
    private func loadCourses() async {
        guard let userLocation = locationManager.location else {
            // Request location first
            locationManager.requestLocation()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let service = GooglePlacesService()
            courses = try await service.searchNearbyGolfCourses(near: userLocation, radius: searchRadius)
            
            if courses.isEmpty {
                errorMessage = "No golf courses found within \(searchRadius / 1609) miles"
            } else {
                // Set initial camera position to show all courses
                if let userCoord = locationManager.location?.coordinate {
                    cameraPosition = .camera(
                        MapCamera(
                            centerCoordinate: userCoord,
                            distance: Double(searchRadius)
                        )
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading courses: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Course Card Component
struct CourseCard: View {
    let course: GolfCourse
    let userLocation: CLLocation?
    let isSelected: Bool
    let onTap: () -> Void
    
    private var distanceText: String {
        guard let userLocation = userLocation else {
            return ""
        }
        let miles = course.distanceInMiles(from: userLocation)
        return String(format: "%.1f mi", miles)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Circle()
                    .fill(isSelected ? Color.green.opacity(0.3) : Color.white.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: isSelected ? "flag.fill" : "flag")
                            .foregroundStyle(isSelected ? .green : .white)
                            .font(.title3)
                    }
                
                // Course Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(course.name)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(course.address)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        if let rating = course.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption)
                                if let count = course.userRatingsTotal {
                                    Text("(\(count))")
                                        .font(.caption2)
                                }
                            }
                            .foregroundStyle(.yellow)
                        }
                        
                        if !distanceText.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                                Text(distanceText)
                                    .font(.caption)
                            }
                            .foregroundStyle(.blue.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
            .padding(16)
            .background(
                isSelected ?
                Color.green.opacity(0.2) :
                Color.white.opacity(0.08)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

#Preview {
    CourseSelectionView { course in
        print("Selected: \(course.name)")
    }
}
