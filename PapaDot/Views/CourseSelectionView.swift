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
        return courses.sorted { course1, course2 in
            let dist1 = course1.distance(from: userLocation)
            let dist2 = course2.distance(from: userLocation)
            return dist1 < dist2
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
                    mapSection
                    mainListView
                }
                
                floatingButton
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
                        completeSelection(course: course, data: courseData)
                    }
                )
            }
            .sheet(isPresented: $showingMultiCourseSheet) {
                MultiCoursePickerView(
                    courses: multipleCourses,
                    googleCourse: selectedGoogleCourse
                ) { selectedApiCourse in
                    Task {
                        // Ensure we have a valid Google course to pair with
                        if let googleCourse = selectedGoogleCourse {
                            await fetchCourseData(
                                googleCourse: googleCourse,
                                apiCourse: selectedApiCourse
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private var mapSection: some View {
        if locationManager.isAuthorized && !courses.isEmpty {
            Map(position: $cameraPosition) {
                if let userLocation = locationManager.location {
                    Annotation("Your Location", coordinate: userLocation.coordinate) {
                        ZStack {
                            Circle().fill(Color.blue).frame(width: 20, height: 20)
                            Circle().stroke(Color.white, lineWidth: 3).frame(width: 20, height: 20)
                        }
                    }
                }
                
                ForEach(courses) { course in
                    Annotation(course.name, coordinate: course.coordinate.clLocationCoordinate) {
                        Button {
                            selectCourseOnMap(course)
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
    }
    
    @ViewBuilder
    private var mainListView: some View {
        if isLoading {
            loadingState
        } else if let error = errorMessage {
            errorState(error: error)
        } else if !locationManager.isAuthorized {
            permissionState
        } else if courses.isEmpty {
            emptyState
        } else {
            coursesList
        }
    }
    
    @ViewBuilder
    private var floatingButton: some View {
        if let selected = selectedCourse {
            VStack {
                Spacer()
                if isFetchingCourseData {
                    HStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("Loading course details...").font(.headline).foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.blue)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                } else {
                    Button {
                        Task { await selectCourse(selected) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Select \(selected.name)").lineLimit(1)
                        }
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.green)
                        .cornerRadius(16)
                        .shadow(radius: 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView().tint(.white).scaleEffect(1.5)
            Text("Finding nearby courses...").foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxHeight: .infinity)
    }
    
    private func errorState(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 50)).foregroundStyle(.yellow)
            Text(error).foregroundStyle(.white).multilineTextAlignment(.center).padding(.horizontal)
            Button("Try Again") { Task { await loadCourses() } }
                .font(.headline).foregroundStyle(.white)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Color.blue).cornerRadius(10)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var permissionState: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash.fill").font(.system(size: 50)).foregroundStyle(.white.opacity(0.5))
            Text("Location Access Needed").font(.title2.bold()).foregroundStyle(.white)
            Button { locationManager.requestLocation() } label: {
                Text("Enable Location").font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Color.blue).cornerRadius(12)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("No courses found nearby").font(.title3.bold()).foregroundStyle(.white)
            Button { showingManualEntry = true } label: {
                Text("Enter Course Manually").font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(Color.green).cornerRadius(12)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var coursesList: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("\(courses.count) Courses Found").font(.headline).foregroundStyle(.white)
                    Spacer()
                    Button("Add") { showingManualEntry = true }
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .padding(8)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20).padding(.top, 16)
                
                ForEach(sortedCourses) { course in
                    CourseCard(
                        course: course,
                        userLocation: locationManager.location,
                        isSelected: selectedCourse?.id == course.id,
                        onTap: { selectCourseOnMap(course) }
                    )
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Actions & Logic
    
    private func selectCourseOnMap(_ course: GolfCourse) {
        selectedCourse = course
        withAnimation {
            cameraPosition = .camera(MapCamera(centerCoordinate: course.coordinate.clLocationCoordinate, distance: 5000))
        }
    }
    
    private func completeSelection(course: GolfCourse, data: GolfCourseData?) {
        if let onSelectWithData = onSelectWithData {
            onSelectWithData(course, data)
        } else {
            onSelect(course)
        }
        dismiss()
    }

    private func loadCourses() async {
        isLoading = true
        errorMessage = nil
        
        // Wait for location if not available yet (up to 5 seconds)
        var attempts = 0
        while locationManager.location == nil && attempts < 10 {
            locationManager.requestLocation()
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            attempts += 1
        }
        
        guard let userLocation = locationManager.location else {
            errorMessage = "Unable to get your location. Please check location permissions."
            isLoading = false
            return
        }
        
        do {
            let service = GolfCourseAPIService()
            courses = try await service.searchNearbyGolfCourses(near: userLocation, radius: searchRadius)
            
            if courses.isEmpty {
                errorMessage = "No golf courses found within \(searchRadius / 1609) miles"
            } else if let userCoord = locationManager.location?.coordinate {
                cameraPosition = .camera(MapCamera(centerCoordinate: userCoord, distance: Double(searchRadius)))
            }
        } catch {
            errorMessage = "Error loading courses: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func selectCourse(_ course: GolfCourse) async {
        print("🏌️ === SELECTING COURSE: \(course.name) ===")
        isFetchingCourseData = true
        
        do {
            let golfAPIService = GolfCourseAPIService()
            let searchQueries = generateSearchQueries(from: course.name)
            
            print("   🔍 Generated Queries: \(searchQueries)")
            
            var allResults: [GolfCourseSearchResult] = []
            
            // Try queries until we find results
            for query in searchQueries {
                print("   🔎 Searching API for: '\(query)'")
                let results = try await golfAPIService.searchCoursesByName(query)
                print("      Found \(results.count) results")
                allResults.append(contentsOf: results)
                if !allResults.isEmpty { break } // Stop if we found something good
            }
            
            // Filter duplicates
            let uniqueResults = Array(Set(allResults.map { $0.id }))
                .compactMap { id in allResults.first { $0.id == id } }
            
            // Filter by distance (if API provides location)
            // Or if multiple results for "Paiute", show them all
            let matchedCourses = filterCoursesByLocation(googleCourse: course, apiResults: uniqueResults)
            
            if matchedCourses.count > 1 {
                print("   🏌️ Multiple courses detected (\(matchedCourses.count)) - Showing Picker")
                selectedGoogleCourse = course
                multipleCourses = matchedCourses
                showingMultiCourseSheet = true
                isFetchingCourseData = false
                return
            }
            
            if let matched = matchedCourses.first {
                print("   ✅ Single match found: \(matched.courseName)")
                await fetchCourseData(googleCourse: course, apiCourse: matched)
            } else {
                print("   ⚠️ No matching API course found. Using manual entry fallback.")
                completeSelection(course: course, data: nil)
            }
            
        } catch {
            print("   ❌ Error during selection: \(error.localizedDescription)")
            completeSelection(course: course, data: nil)
        }
        
        isFetchingCourseData = false
    }
    
    private func filterCoursesByLocation(googleCourse: GolfCourse, apiResults: [GolfCourseSearchResult]) -> [GolfCourseSearchResult] {
        guard !apiResults.isEmpty else { return [] }
        
        // If we found exact name matches (like "Snow Mountain"), just return them
        // But usually we want to check distance if coordinates exist
        let googleLoc = CLLocation(latitude: googleCourse.coordinate.latitude, longitude: googleCourse.coordinate.longitude)
        
        let validCourses = apiResults.filter { apiCourse in
            guard let lat = apiCourse.location.latitude, let lon = apiCourse.location.longitude else {
                // If API has no location, keep it if the name is similar
                return true
            }
            
            let apiLoc = CLLocation(latitude: lat, longitude: lon)
            let distance = apiLoc.distance(from: googleLoc)
            
            // Match if within 2 miles (approx 3200 meters) to account for large resorts like Paiute
            return distance < 3200
        }
        
        return validCourses.isEmpty ? apiResults : validCourses
    }
    
    private func fetchCourseData(googleCourse: GolfCourse, apiCourse: GolfCourseSearchResult) async {
        print("   💾 Fetching full details for: \(apiCourse.courseName)")
        do {
            let golfAPIService = GolfCourseAPIService()
            let details = try await golfAPIService.getCourseDetails(courseId: "\(apiCourse.id)")
            
            if let holes = details.holes, !holes.isEmpty {
                // Holes don't have explicit numbers - use array index (1-based)
                let numberedHoles = holes.enumerated().map { index, hole in
                    HoleInfo(number: index + 1, par: hole.par, yardage: hole.yardage ?? 0, handicap: hole.handicap)
                }
                
                let par3Holes = numberedHoles.filter { $0.par == 3 }.map { $0.number }
                let totalPar = numberedHoles.reduce(0) { $0 + $1.par }
                
                print("   🏌️ Found \(par3Holes.count) par 3s at holes: \(par3Holes)")
                
                let courseData = GolfCourseData(
                    courseName: apiCourse.courseName,
                    totalPar: totalPar,
                    par3Holes: par3Holes,
                    holes: numberedHoles
                )
                
                print("   ✅ Success! Course data loaded.")
                completeSelection(course: googleCourse, data: courseData)
            } else {
                print("   ⚠️ No hole data in details.")
                completeSelection(course: googleCourse, data: nil)
            }
        } catch {
            print("   ❌ Failed to fetch details: \(error)")
            completeSelection(course: googleCourse, data: nil)
        }
    }
    
    // MARK: - Improved Search Logic
    
    private func generateSearchQueries(from courseName: String) -> [String] {
        var queries: [String] = []
        
        // Clean the name
        let cleaned = courseName
            .replacingOccurrences(of: " - ", with: " ")
            .replacingOccurrences(of: "Golf Club", with: "")
            .replacingOccurrences(of: "Golf Course", with: "")
            .replacingOccurrences(of: "Golf Resort", with: "")
            .replacingOccurrences(of: "Country Club", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        // 1. High Priority: Strip known city names to find the unique identifier
        // Example: "Las Vegas Paiute" -> "Paiute"
        let cityNames = ["Las Vegas", "North Las Vegas", "Henderson", "Summerlin"]
        var nameWithoutCity = cleaned
        for city in cityNames {
            if nameWithoutCity.localizedCaseInsensitiveContains(city) {
                nameWithoutCity = nameWithoutCity.replacingOccurrences(of: city, with: "", options: .caseInsensitive)
            }
        }
        nameWithoutCity = nameWithoutCity.trimmingCharacters(in: .whitespaces)
        
        if !nameWithoutCity.isEmpty && nameWithoutCity.count > 3 {
            queries.append(nameWithoutCity) // e.g. "Paiute"
        }
        
        // 2. Original cleaned name
        if !queries.contains(cleaned) && !cleaned.isEmpty {
            queries.append(cleaned)
        }
        
        // 3. First unique large word (heuristic)
        let words = cleaned.split(separator: " ")
        if let longest = words.max(by: { $0.count < $1.count }), longest.count > 4 {
            let sLongest = String(longest)
            if !queries.contains(sLongest) {
                queries.append(sLongest)
            }
        }
        
        return queries
    }
}

// MARK: - Components

struct CourseCard: View {
    let course: GolfCourse
    let userLocation: CLLocation?
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Circle()
                    .fill(isSelected ? Color.green.opacity(0.3) : Color.white.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: isSelected ? "flag.fill" : "flag")
                            .foregroundStyle(isSelected ? .green : .white).font(.title3)
                    }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(course.name).font(.headline.bold()).foregroundStyle(.white).lineLimit(1)
                    Text(course.address).font(.caption).foregroundStyle(.white.opacity(0.6)).lineLimit(2)
                    
                    HStack(spacing: 12) {
                        if let rating = course.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill").font(.caption2)
                                Text(String(format: "%.1f", rating)).font(.caption)
                            }
                            .foregroundStyle(.yellow)
                        }
                        if let userLoc = userLocation {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill").font(.caption2)
                                Text(String(format: "%.1f mi", course.distanceInMiles(from: userLoc))).font(.caption)
                            }
                            .foregroundStyle(.blue.opacity(0.8))
                        }
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.green)
                }
            }
            .padding(16)
            .background(isSelected ? Color.green.opacity(0.2) : Color.white.opacity(0.08))
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

struct MultiCoursePickerView: View {
    let courses: [GolfCourseSearchResult]
    let googleCourse: GolfCourse?
    let onSelect: (GolfCourseSearchResult) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.4, blue: 0.2), Color(red: 0.05, green: 0.25, blue: 0.15)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        Text("Select Course at \(googleCourse?.name ?? "Location")")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.vertical)
                        
                        ForEach(courses) { course in
                            Button {
                                onSelect(course)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(course.courseName).font(.headline).foregroundStyle(.white)
                                        if !course.clubName.isEmpty {
                                            Text(course.clubName).font(.subheadline).foregroundStyle(.white.opacity(0.7))
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.5))
                                }
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Multiple Courses Found")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
    }
}
