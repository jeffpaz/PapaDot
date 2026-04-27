// Views/GameSetup/CreateGameView.swift
import SwiftUI

struct CreateGameView: View {
    @Environment(GameManager.self) var manager
    @Environment(SavedTasksManager.self) var savedTasks
    @Environment(\.dismiss) var dismiss

    @State private var wagerText = "1"
    @State private var players: [Player] = []
    @State private var selectedCourse: GolfCourse?
    @State private var courseData: GolfCourseData?
    @State private var customTasks: [CustomTask] = CustomTask.defaultTasks
    @State private var allowGuestsToScore = true
    @State private var isTeamMode = false
    @State private var showingPlayerPicker = false
    @State private var showingCourseSelection = false
    @State private var showingTaskEditor = false

    @AppStorage("userName") private var userName: String = "Me"
    @AppStorage("userPhoneNumber") private var userPhoneNumber: String = ""
    @AppStorage("userContactID") private var userContactID: String = ""
    @AppStorage("userHandicap") private var userHandicap: Int = 0

    @State private var showingUserProfileSetup = false

    private var allPlayers: [Player] {
        var hostPlayer = Player(name: userName, phoneNumber: userPhoneNumber)
        hostPlayer.handicap = userHandicap
        return [hostPlayer] + players
    }

    private var canCreateGame: Bool {
        allPlayers.count >= 1 && allPlayers.count <= 4 &&
        selectedCourse != nil &&
        courseData != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Golf Course
                Section("Golf Course") {
                    if let course = selectedCourse {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "flag.fill").foregroundStyle(.green)
                                Text(course.name).font(.headline)
                                Spacer()
                                Button("Change") {
                                    selectedCourse = nil
                                    courseData = nil
                                }
                                .font(.caption)
                            }
                            Text(course.address).font(.caption).foregroundStyle(.secondary)
                            if let data = courseData {
                                Divider()
                                HStack {
                                    Label("\(data.totalPar) Par", systemImage: "flag.circle.fill")
                                    Spacer()
                                    Label("\(data.par3Holes.count) Par 3s", systemImage: "star.fill")
                                        .foregroundStyle(.yellow)
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button {
                            showingCourseSelection = true
                        } label: {
                            Label("Select Course", systemImage: "plus.circle.fill")
                        }
                    }
                }

                // Wager
                Section("Wager per Dot") {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("1", text: $wagerText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Players
                Section("Players (\(allPlayers.count)/4)") {
                    HStack {
                        Image(systemName: "crown.fill").foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(userName).font(.headline.bold())
                            if !userPhoneNumber.isEmpty {
                                Text(userPhoneNumber).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Picker("HCP", selection: $userHandicap) {
                            ForEach(0...36, id: \.self) { hcp in
                                Text("\(hcp)").tag(hcp)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.caption)
                        Button {
                            showingUserProfileSetup = true
                        } label: {
                            Text("Edit").font(.caption)
                        }
                    }
                    .onAppear {
                        if userHandicap == 0 {
                            userHandicap = 10
                        }
                    }

                    ForEach(players.indices, id: \.self) { index in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(players[index].name).font(.headline)
                                if !players[index].phoneNumber.isEmpty {
                                    Text(players[index].phoneNumber)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Picker("HCP", selection: $players[index].handicap) {
                                ForEach(0...36, id: \.self) { hcp in
                                    Text("\(hcp)").tag(hcp)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.caption)
                            Button(role: .destructive) {
                                players.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }
                        }
                        .onAppear {
                            if players[index].handicap == 0 {
                                players[index].handicap = 10
                            }
                        }
                    }
                    .onDelete { players.remove(atOffsets: $0) }

                    if allPlayers.count < 4 {
                        Button {
                            showingPlayerPicker = true
                        } label: {
                            Label("Add Player", systemImage: "person.badge.plus")
                        }
                    }
                }

                // Permissions
                Section {
                    Toggle(isOn: $allowGuestsToScore) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Allow guests to score")
                            Text("Other players can mark scores before you")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("When enabled, any player can mark scores. When disabled, only the host can.")
                }

                // Team Mode
                if allPlayers.count == 4 {
                    Section {
                        Toggle(isOn: $isTeamMode) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Team Mode")
                                Text("Players 1 & 2 vs Players 3 & 4")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Game Mode")
                    } footer: {
                        if isTeamMode {
                            Text("Team A: \(allPlayers[0].name) & \(allPlayers[1].name)\nTeam B: \(allPlayers[2].name) & \(allPlayers[3].name)\n\nScoring: Individual tasks award dots to teams. Low Hole is team-exclusive.")
                        } else {
                            Text("Enable Team Mode for 2v2 gameplay with combined scoring.")
                        }
                    }
                }

                // Scoring Tasks
                Section {
                    Button {
                        showingTaskEditor = true
                    } label: {
                        Label("Edit Scoring Tasks", systemImage: "checklist")
                    }
                } header: {
                    Text("Scoring")
                } footer: {
                    Text("\(customTasks.count) tasks configured" +
                         (savedTasks.presets.isEmpty ? "" : " • \(savedTasks.presets.count) presets saved"))
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createGame() }
                    }
                    .disabled(!canCreateGame)
                    .fontWeight(.semibold)
                }
            }
            // Player picker (replaces old ContactPickerView)
            .sheet(isPresented: $showingPlayerPicker) {
                PlayerPickerView { player in
                    if allPlayers.count < 4 {
                        players.append(player)
                    }
                }
            }
            .sheet(isPresented: $showingUserProfileSetup) {
                UserProfileSetupView(
                    userName: $userName,
                    userPhoneNumber: $userPhoneNumber,
                    userContactID: $userContactID
                )
            }
            .sheet(isPresented: $showingCourseSelection) {
                CourseSelectionView(
                    onSelect: { selectedCourse = $0 },
                    onSelectWithData: { course, data in
                        selectedCourse = course
                        courseData = data
                    }
                )
            }
            .sheet(isPresented: $showingTaskEditor) {
                CustomTaskEditorView(tasks: $customTasks)
            }
        }
    }

    @MainActor
    private func createGame() async {
        guard let course = selectedCourse, let data = courseData else { return }

        let wager = Int(wagerText) ?? 1
        var rules = GameRules()
        rules.tasks = customTasks
        rules.stakePerPoint = wager
        rules.par3Holes = Set(data.par3Holes)
        rules.allowGuestsToScore = allowGuestsToScore
        rules.isTeamMode = isTeamMode && allPlayers.count == 4

        // Initialize carry-over values to base points from tasks
        rules.currentGreenieValue = customTasks.first(where: { $0.name == "Greenie" })?.points ?? 1
        rules.currentLowHoleValue = customTasks.first(where: { $0.name == "Low Hole" })?.points ?? 1

        await manager.createGame(
            players: allPlayers,
            rules: rules,
            golfCourse: course,
            courseData: data
        )
        dismiss()
    }
}

#Preview {
    CreateGameView()
        .environment(GameManager())
        .environment(SavedTasksManager())
        .environment(FavoritesManager())
}
