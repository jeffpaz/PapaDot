//  Views/CourseSelectionView.swift
import SwiftUI
import MapKit

struct CourseSelectionView: View {
    @Environment(\.dismiss) var dismiss
    let onSelect: (GolfCourse) -> Void
    let onSelectWithData: ((GolfCourse, GolfCourseData?) -> Void)?
    
    @State private var locationManager = LocationManager()
    @State private var courses: [GolfCourse] = []
    @State private var selectedCourse: GolfCourse?
    @State private var isLoading = false
    @State private var isFetchingCourseData = false
    @State private var errorMessage: String?
    @State private var searchRadius = 25000 // meters (~15 miles)
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingManualEntry = false
    
    // NEW: For multiple courses at same location
    @State private var multipleCourses: [GolfCourseSearchResult] = []
    @State private var showingMultiCourseSheet = false
    @State private var selectedGoogleCourse: GolfCourse?
    
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
                                .background(Color.blue)
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
                                .background(Color.green)
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
                        
                        if isFetchingCourseData {
                            // Loading state
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(.white)
                                Text("Loading course details...")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.blue)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                        } else {
                            Button {
                                Task {
                                    await selectCourse(selected)
                                }
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
                    onSave: { _ in },
                    onComplete: { course, courseData in
                        if let onSelectWithData = onSelectWithData {
                            onSelectWithData(course, courseData)
                        } else {
                            onSelect(course)
                        }
                        dismiss()
                    }
                )
            }
            .sheet(isPresented: $showingMultiCourseSheet) {
                MultiCoursePickerView(
                    courses: multipleCourses,
                    googleCourse: selectedGoogleCourse
                ) { selectedApiCourse in
                    Task {
                        await fetchCourseData(
                            googleCourse: selectedGoogleCourse!,
                            apiCourse: selectedApiCourse
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Load Courses from Google Places
    private func loadCourses() async {
        guard let userLocation = locationManager.location else {
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
    
    // MARK: - Select Course and Fetch Hole Data
    private func selectCourse(_ course: GolfCourse) async {
        print("🏌️ === SELECTING COURSE ===")
        print("   Course: \(course.name)")
        print("   Address: \(course.address)")
        
        isFetchingCourseData = true
        
        do {
            // Try to fetch hole data from Golf Course API
            let golfAPIService = GolfCourseAPIService()
            
            // Generate multiple search variations to increase match probability
            let searchQueries = generateSearchQueries(from: course.name)
            
            print("   🔍 Will try \(searchQueries.count) search variations:")
            for (index, query) in searchQueries.enumerated() {
                print("      \(index + 1). \"\(query)\"")
            }
            
            var allResults: [GolfCourseSearchResult] = []
            
            // Try each search query
            for query in searchQueries {
                print("   🔎 Searching: \"\(query)\"")
                let results = try await golfAPIService.searchCoursesByName(query)
                print("      Found \(results.count) results")
                allResults.append(contentsOf: results)
                
                // Stop if we found enough results
                if allResults.count > 10 {
                    break
                }
            }
            
            // Remove duplicates by ID
            let uniqueResults = Array(Set(allResults.map { $0.id }))
                .compactMap { id in allResults.first { $0.id == id } }
            
            print("   📊 Total unique results: \(uniqueResults.count)")
            
            // Log all unique results
            for (index, result) in uniqueResults.enumerated() {
                print("   📋 Result \(index + 1): \(result.courseName) (Club: \(result.clubName))")
                if let lat = result.location.latitude, let lon = result.location.longitude {
                    print("      Location: \(lat), \(lon)")
                }
            }
            
            print("   🎯 Google Course Location: \(course.coordinate.latitude), \(course.coordinate.longitude)")
            
            // Find ALL courses at this location (within 1 mile)
            let matchedCourses = uniqueResults.filter { apiCourse in
                guard let apiLat = apiCourse.location.latitude,
                      let apiLon = apiCourse.location.longitude else {
                    print("   ⚠️  \(apiCourse.courseName) - NO COORDINATES")
                    return false
                }
                
                let apiLocation = CLLocation(latitude: apiLat, longitude: apiLon)
                let googleLocation = CLLocation(
                    latitude: course.coordinate.latitude,
                    longitude: course.coordinate.longitude
                )
                
                let distance = apiLocation.distance(from: googleLocation)
                let miles = distance / 1609.34
                print("   📍 Distance from \(apiCourse.courseName): \(Int(distance))m (\(String(format: "%.2f", miles)) miles)")
                
                let isMatch = distance < 1600 // Within 1 mile (1609 meters)
                if isMatch {
                    print("      ✅ MATCH - Within 1 mile")
                } else {
                    print("      ❌ TOO FAR")
                }
                
                return isMatch
            }
            
            print("   🎯 Found \(matchedCourses.count) course(s) at this location")
            
            // Log matched courses
            if matchedCourses.count > 0 {
                print("   📌 Matched courses:")
                for (index, match) in matchedCourses.enumerated() {
                    print("      \(index + 1). \(match.courseName) (Club: \(match.clubName))")
                }
            }
            
            // If multiple courses at same location, let user pick
            if matchedCourses.count > 1 {
                print("   🏌️ Multiple courses detected - showing picker")
                print("   📱 Setting showingMultiCourseSheet = true")
                selectedGoogleCourse = course
                multipleCourses = matchedCourses
                showingMultiCourseSheet = true
                isFetchingCourseData = false
                print("   ✅ Sheet should be visible now")
                return
            }
            
            // Single course - proceed normally
            guard let matched = matchedCourses.first else {
                print("   ❌ No courses found at this location")
                print("   Falling back to manual entry")
                
                // No match - proceed with manual entry
                if let onSelectWithData = onSelectWithData {
                    onSelectWithData(course, nil)
                } else {
                    onSelect(course)
                }
                dismiss()
                isFetchingCourseData = false
                return
            }
            
            // Fetch data for the matched course
            await fetchCourseData(googleCourse: course, apiCourse: matched)
            
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
            
            // Error - proceed without course data
            if let onSelectWithData = onSelectWithData {
                onSelectWithData(course, nil)
            } else {
                onSelect(course)
            }
            dismiss()
        }
        
        isFetchingCourseData = false
    }
    
    // MARK: - Fetch Course Data from API Result
    private func fetchCourseData(googleCourse: GolfCourse, apiCourse: GolfCourseSearchResult) async {
        print("   💾 === FETCHING COURSE DATA ===")
        print("   📍 Google Course: \(googleCourse.name)")
        print("   🎯 API Course: \(apiCourse.courseName)")
        print("   🏢 Club: \(apiCourse.clubName)")
        print("   🆔 Course ID: \(apiCourse.id)")
        
        do {
            let golfAPIService = GolfCourseAPIService()
            
            print("   ⏳ Calling getCourseDetails...")
            
            // Fetch detailed hole data
            let details = try await golfAPIService.getCourseDetails(courseId: "\(apiCourse.id)")
            
            print("   📦 Received response")
            
            if let holes = details.holes, !holes.isEmpty {
                print("   ✅ Got hole data: \(holes.count) holes")
                
                // Extract par 3 holes
                let par3Holes = holes
                    .filter { $0.par == 3 }
                    .compactMap { $0.holeNumber }
                
                let totalPar = holes.reduce(0) { $0 + $1.par }
                
                print("   ⛳ Par 3 holes: \(par3Holes)")
                print("   📊 Total par: \(totalPar)")
                
                // Show first few holes for verification
                print("   🏌️ First 3 holes:")
                for hole in holes.prefix(3) {
                    print("      Hole \(hole.holeNumber): Par \(hole.par), \(hole.yardage ?? 0) yards")
                }
                
                // Create course data
                let courseData = GolfCourseData(
                    courseName: apiCourse.courseName, // Use API course name (e.g., "Snow Mountain")
                    totalPar: totalPar,
                    par3Holes: par3Holes,
                    holes: holes.map { hole in
                        HoleInfo(
                            number: hole.holeNumber,
                            par: hole.par,
                            yardage: hole.yardage ?? 0
                        )
                    }
                )
                
                print("   📤 Calling callback with course data")
                print("   📝 Course name will be: \(apiCourse.courseName)")
                
                // Call the callback with course data
                if let onSelectWithData = onSelectWithData {
                    onSelectWithData(googleCourse, courseData)
                    print("   ✅ Callback completed (onSelectWithData)")
                } else {
                    onSelect(googleCourse)
                    print("   ✅ Callback completed (onSelect)")
                }
                
                showingMultiCourseSheet = false
                dismiss()
                print("   👋 Dismissed and returning to game setup")
            } else {
                print("   ⚠️ No hole data found")
                print("   📊 Details received: \(details)")
                
                // No hole data - return without course data
                if let onSelectWithData = onSelectWithData {
                    onSelectWithData(googleCourse, nil)
                } else {
                    onSelect(googleCourse)
                }
                
                showingMultiCourseSheet = false
                dismiss()
            }
        } catch {
            print("   ❌ Error fetching course data: \(error.localizedDescription)")
            
            // Error - return without course data
            if let onSelectWithData = onSelectWithData {
                onSelectWithData(googleCourse, nil)
            } else {
                onSelect(googleCourse)
            }
            
            showingMultiCourseSheet = false
            dismiss()
        }
    }
    
    // MARK: - Helper: Generate Search Query Variations
    
    /// Generates multiple search variations from a course name to improve matching
    /// Example: "Pebble Beach Golf Links" → ["Pebble Beach Golf Links", "Pebble Beach", "Pebble"]
    private func generateSearchQueries(from courseName: String) -> [String] {
        var queries: [String] = []
        
        // Remove common suffixes that might differ between Google and Golf Course API
        let cleanedName = courseName
            .replacingOccurrences(of: " - ", with: " ")
            .replacingOccurrences(of: "Golf Course", with: "")
            .replacingOccurrences(of: "Golf Club", with: "")
            .replacingOccurrences(of: "Country Club", with: "")
            .replacingOccurrences(of: "Golf Resort", with: "")
            .replacingOccurrences(of: "Golf Links", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        
        // 1. Full cleaned name
        if !cleanedName.isEmpty {
            queries.append(cleanedName)
        }
        
        // 2. Original name (in case cleaning made it worse)
        if courseName != cleanedName {
            queries.append(courseName)
        }
        
        // 3. First two words (e.g., "Pebble Beach")
        let words = cleanedName.split(separator: " ").map(String.init)
        if words.count >= 2 {
            let firstTwoWords = words.prefix(2).joined(separator: " ")
            if !queries.contains(firstTwoWords) {
                queries.append(firstTwoWords)
            }
        }
        
        // 4. First word only (e.g., "Pebble")
        if let firstWord = words.first, firstWord.count > 3 {
            if !queries.contains(firstWord) {
                queries.append(firstWord)
            }
        }
        
        // Remove duplicates while preserving order
        var uniqueQueries: [String] = []
        var seen = Set<String>()
        for query in queries {
            if !seen.contains(query.lowercased()) {
                seen.insert(query.lowercased())
                uniqueQueries.append(query)
            }
        }
        
        return uniqueQueries
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
    

// MARK: - Multi-Course Picker Sheet

struct MultiCoursePickerView: View {
    let courses: [GolfCourseSearchResult]
    let googleCourse: GolfCourse?
    let onSelect: (GolfCourseSearchResult) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.4, blue: 0.2),
                        Color(red: 0.05, green: 0.25, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)
                        
                        Text("Multiple Courses Found")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        
                        if let course = googleCourse {
                            Text(course.name)
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        Text("Select which course you're playing")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.top, 30)
                    
                    // Course List
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(courses) { course in
                                Button {
                                    onSelect(course)
                                    dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(course.courseName)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            
                                            if !course.clubName.isEmpty {
                                                Text(course.clubName)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.white.opacity(0.7))
                                            }
                                            
                                            // Show city/state if available
                                            if let city = course.city, let state = course.state {
                                                Text("\(city), \(state)")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.5))
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Select Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

#Preview {
    CourseSelectionView { course in
        print("Selected: \(course.name)")
    }
}
