//  Views/GameSetup/CreateGameView.swift
import SwiftUI
import ContactsUI

struct CreateGameView: View {
    @Environment(GameManager.self) var manager
    @Environment(\.dismiss) var dismiss
    
    @State private var wagerText = "1"
    @State private var players: [Player] = []
    @State private var selectedCourse: GolfCourse?
    @State private var courseData: GolfCourseData?
    @State private var customTasks: [CustomTask] = CustomTask.defaultTasks
    @State private var allowGuestsToScore = true  // NEW: Toggle for guest scoring
    @State private var showingContactPicker = false
    @State private var showingCourseSelection = false
    @State private var showingCourseDataEntry = false
    @State private var showingTaskEditor = false
    @State private var isLoadingCourseData = false
    
    @AppStorage("userName") private var userName: String = "Me"
    @AppStorage("userPhoneNumber") private var userPhoneNumber: String = ""
    @AppStorage("userContactID") private var userContactID: String = ""
    
    @State private var showingUserProfileSetup = false
    
    private let courseDataService = CourseDataService()
    
    private var allPlayers: [Player] {
        [Player(name: userName, phoneNumber: userPhoneNumber)] + players
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Golf Course Selection
                Section("Golf Course") {
                    if let course = selectedCourse {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "flag.fill")
                                    .foregroundStyle(.green)
                                Text(course.name)
                                    .font(.headline)
                                Spacer()
                                Button("Change") {
                                    selectedCourse = nil
                                    courseData = nil
                                }
                                .font(.caption)
                                .foregroundStyle(.blue)
                            }
                            
                            Text(course.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if let rating = course.rating {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                    Text(String(format: "%.1f", rating))
                                        .font(.caption)
                                    if let count = course.userRatingsTotal {
                                        Text("(\(count) reviews)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            // Course Data Status
                            if isLoadingCourseData {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading course data...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let data = courseData {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("Course Data Available")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.green)
                                    }
                                    
                                    HStack(spacing: 12) {
                                        Label("Par \(data.totalPar)", systemImage: "flag.fill")
                                            .font(.caption)
                                        Label("\(data.par3Holes.count) Par 3s", systemImage: "leaf.fill")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.white.opacity(0.8))
                                    
                                    if let contributor = data.contributedBy {
                                        Text("Contributed by \(contributor)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                        Text("No Course Data")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.orange)
                                    }
                                    
                                    Button {
                                        showingCourseDataEntry = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Help build our database →")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            showingCourseSelection = true
                        } label: {
                            Label("Select Golf Course", systemImage: "map")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(.blue)
                    }
                }
                
                Section("Wager per Dot") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("1", text: $wagerText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Custom Tasks Section
                Section {
                    Button {
                        showingTaskEditor = true
                    } label: {
                        HStack {
                            Label("Customize Tasks", systemImage: "slider.horizontal.3")
                            Spacer()
                            Text("\(customTasks.count)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Scoring")
                } footer: {
                    Text("Edit which tasks award points during the round")
                }
                
                // Guest Scoring Permission
                Section {
                    Toggle(isOn: $allowGuestsToScore) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Allow Guests to Score")
                                .font(.body)
                            Text("Let other players mark their own dots")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(allowGuestsToScore ?
                         "All players can mark dots. Great for casual rounds." :
                         "Only you can mark dots. Other players can view scores only.")
                }
                
                Section("Players (\(allPlayers.count)/4)") {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(userName)
                                .font(.headline.bold())
                            if !userPhoneNumber.isEmpty {
                                Text(userPhoneNumber)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Change") {
                            showingUserProfileSetup = true
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 8)
                    
                    ForEach(players) { player in
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name)
                                    .font(.subheadline)
                                if !player.phoneNumber.isEmpty {
                                    Text(player.phoneNumber)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Remove") {
                                players.removeAll { $0.id == player.id }
                            }
                            .foregroundStyle(.red)
                        }
                    }
                    
                    Button {
                        showingContactPicker = true
                    } label: {
                        Label("Add Player", systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(.blue)
                }
                
                Section {
                    Button("Create Game") {
                        createGame()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .disabled(userName == "Me" || userContactID.isEmpty || selectedCourse == nil)
                }
            }
            .navigationTitle("New Game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCourseSelection) {
                CourseSelectionView(
                    onSelect: { course in
                        print("📍 onSelect called: \(course.name)")
                        selectedCourse = course
                        loadCourseData(for: course)
                    },
                    onSelectWithData: { course, data in
                        print("📍 onSelectWithData called: \(course.name), has data: \(data != nil)")
                        selectedCourse = course
                        // If test course data was provided, use it directly
                        if let data = data {
                            print("📊 Received courseData with \(data.holePars.count) holes, par 3s: \(data.par3Holes)")
                            courseData = data
                            isLoadingCourseData = false
                            // Don't auto-show entry form since we have data
                        } else {
                            print("⚠️ No courseData received, loading from CloudKit")
                            loadCourseData(for: course)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactPicker { contact in
                    addPlayerFromContact(contact)
                }
            }
            .sheet(isPresented: $showingUserProfileSetup) {
                UserProfileSetupView(
                    userName: $userName,
                    userPhoneNumber: $userPhoneNumber,
                    userContactID: $userContactID
                )
            }
            .sheet(isPresented: $showingTaskEditor) {
                CustomTaskEditorView(tasks: $customTasks)
            }
            .sheet(isPresented: $showingCourseDataEntry) {
                if let course = selectedCourse {
                    CourseDataEntryView(course: course) { data in
                        courseData = data
                        // Save to CloudKit
                        Task {
                            await courseDataService.saveCourseData(data)
                        }
                    }
                }
            }
            .onAppear {
                // Show profile setup if user hasn't set it up yet
                if userName == "Me" || userContactID.isEmpty {
                    showingUserProfileSetup = true
                }
            }
        }
    }
    
    private func loadCourseData(for course: GolfCourse) {
        isLoadingCourseData = true
        Task {
            courseData = await courseDataService.fetchCourseData(for: course.id)
            isLoadingCourseData = false
            
            // If no data found, prompt user to add it
            if courseData == nil {
                // Auto-show entry form after a brief delay
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if selectedCourse?.id == course.id {
                    showingCourseDataEntry = true
                }
            }
        }
    }
    
    private func createGame() {
        var rules = GameRules(stakePerPoint: Int(wagerText) ?? 1)
        
        // Apply course data if available
        if let data = courseData {
            rules.par3Holes = data.par3Holes
        }
        
        // Use custom tasks if provided
        rules.tasks = customTasks
        
        // Set guest scoring permission
        rules.allowGuestsToScore = allowGuestsToScore
        
        Task { @MainActor in
            await manager.createGame(players: allPlayers, rules: rules, golfCourse: selectedCourse, courseData: courseData)
            // Small delay to let state propagate
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            dismiss()
        }
    }
    
    private func addPlayerFromContact(_ contact: CNContact) {
        let firstName = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !firstName.isEmpty,
              !allPlayers.contains(where: { $0.name.lowercased() == firstName.lowercased() }) else { return }
        
        // Get phone number if available
        let phoneNumber = contact.phoneNumbers.first?.value.stringValue ?? ""
        
        players.append(Player(name: firstName.capitalized, phoneNumber: phoneNumber))
    }
}

#Preview {
    CreateGameView()
        .environment(GameManager())
}
