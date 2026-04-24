//  Views/ManualCourseEntryView.swift
import SwiftUI
import CoreLocation

struct ManualCourseEntryView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (GolfCourse) -> Void
    let onComplete: ((GolfCourse, GolfCourseData?) -> Void)? // NEW: Optional callback with course data
    
    @State private var courseName = ""
    @State private var isTestCourse = false // NEW: Test course checkbox
    @State private var locationManager = LocationManager()
    
    init(onSave: @escaping (GolfCourse) -> Void, onComplete: ((GolfCourse, GolfCourseData?) -> Void)? = nil) {
        self.onSave = onSave
        self.onComplete = onComplete
    }
    
    private var isValid: Bool {
        !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTestCourse
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)
                                .padding(.top, 20)
                            
                            Text("Add Course Manually")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("Enter the golf course name")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        // Input Fields
                        VStack(spacing: 16) {
                            // Test Course Toggle
                            Toggle(isOn: $isTestCourse) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "testtube.2")
                                            .foregroundStyle(.orange)
                                        Text("Test Course")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                    Text("Auto-generate test course (Par 72: 2 Par 3s, 2 Par 5s, 5 Par 4s per nine)")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .tint(.orange)
                            .padding()
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(12)
                            
                            // Course Name (disabled if test course)
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Course Name", systemImage: "flag.fill")
                                    .font(.headline)
                                    .foregroundStyle(isTestCourse ? .white.opacity(0.4) : .white)
                                
                                TextField("e.g., Pebble Beach Golf Links", text: $courseName)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color.white.opacity(isTestCourse ? 0.05 : 0.15))
                                    .foregroundStyle(isTestCourse ? .white.opacity(0.4) : .white)
                                    .cornerRadius(12)
                                    .autocorrectionDisabled()
                                    .disabled(isTestCourse)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Info Box
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("We'll use your current location as the course location for distance calculations.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        
                        // Save Button
                        Button {
                            saveCourse()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Course")
                                    .font(.headline.bold())
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                isValid ?
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .disabled(!isValid)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if !locationManager.isAuthorized {
                    locationManager.requestLocation()
                }
            }
        }
    }
    
    private func saveCourse() {
        let finalName: String
        if isTestCourse {
            finalName = "Test Course - \(Date().formatted(date: .numeric, time: .omitted))"
        } else {
            finalName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Use current location or default to a generic coordinate
        let coordinate: GolfCourse.Coordinate
        if let userLocation = locationManager.location {
            coordinate = GolfCourse.Coordinate(from: userLocation.coordinate)
        } else {
            // Default to a generic coordinate (center of US) if no location available
            coordinate = GolfCourse.Coordinate(latitude: 39.8283, longitude: -98.5795)
        }
        
        let manualCourse = GolfCourse(
            id: "manual-\(UUID().uuidString)",
            name: finalName,
            address: "Location not specified",
            coordinate: coordinate,
            phoneNumber: nil,
            rating: nil,
            userRatingsTotal: nil
        )
        
        // Generate test course data if test course is enabled
        let courseData: GolfCourseData?
        if isTestCourse {
            courseData = generateTestCourseData(for: manualCourse)
        } else {
            courseData = nil
        }
        
        // Call the appropriate callback
        if let onComplete = onComplete {
            print("✅ Calling onComplete with courseData: \(courseData != nil)")
            onComplete(manualCourse, courseData)
        } else {
            print("⚠️ Calling onSave (no courseData)")
            onSave(manualCourse)
        }
    }
    
    /// Generate randomized test course data
    /// Front 9: 2 Par 3s, 5 Par 4s, 2 Par 5s
    /// Back 9: 2 Par 3s, 5 Par 4s, 2 Par 5s
    private func generateTestCourseData(for course: GolfCourse) -> GolfCourseData {
        var holePars: [Int] = []
        
        // Front 9 (holes 1-9)
        var front9: [Int] = []
        front9.append(contentsOf: Array(repeating: 3, count: 2)) // 2 par 3s
        front9.append(contentsOf: Array(repeating: 4, count: 5)) // 5 par 4s
        front9.append(contentsOf: Array(repeating: 5, count: 2)) // 2 par 5s
        front9.shuffle()
        
        // Back 9 (holes 10-18)
        var back9: [Int] = []
        back9.append(contentsOf: Array(repeating: 3, count: 2)) // 2 par 3s
        back9.append(contentsOf: Array(repeating: 4, count: 5)) // 5 par 4s
        back9.append(contentsOf: Array(repeating: 5, count: 2)) // 2 par 5s
        back9.shuffle()
        
        // Combine front and back
        holePars = front9 + back9
        
        // Calculate total par and find par 3 holes
        let totalPar = holePars.reduce(0, +)
        let par3Holes = holePars.enumerated()
            .filter { $0.element == 3 }
            .map { $0.offset + 1 } // Convert to 1-based hole numbers
        
        // Generate hole info with random yardages
        let holes = holePars.enumerated().map { index, par in
            let yardage: Int
            switch par {
            case 3: yardage = Int.random(in: 120...200)
            case 4: yardage = Int.random(in: 300...450)
            case 5: yardage = Int.random(in: 480...580)
            default: yardage = 350
            }
            
            return HoleInfo(
                number: index + 1,
                par: par,
                yardage: yardage,
                handicap: nil
            )
        }
        
        print("🧪 Generated test course data: \(totalPar) total par, \(par3Holes.count) par 3s")
        print("🧪 Par 3 holes: \(par3Holes)")
        
        return GolfCourseData(
            courseName: course.name,
            totalPar: totalPar,
            par3Holes: par3Holes,
            holes: holes
        )
    }
}

#Preview {
    ManualCourseEntryView { course in
        print("Saved: \(course.name)")
    }
}
