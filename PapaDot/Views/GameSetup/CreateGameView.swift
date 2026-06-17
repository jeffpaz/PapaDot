// Views/GameSetup/CreateGameView.swift
import SwiftUI

struct CreateGameView: View {
    @Environment(GameManager.self) var manager
    @Environment(SavedTasksManager.self) var savedTasks
    @Environment(FavoritesManager.self) var favorites
    @Environment(\.dismiss) var dismiss

    @State private var wagerText = "1"
    @State private var useHandicap = true
    @State private var maxOwedEnabled = false
    @State private var maxOwedAmountText = "20"
    @State private var players: [Player] = []
    @State private var selectedCourse: GolfCourse?
    @State private var courseData: GolfCourseData?
    @State private var customTasks: [CustomTask] = CustomTask.defaultTasks
    @State private var startingHole = 1
    @State private var isTeamMode = false
    @State private var teamNameA = "Team A"
    @State private var teamNameB = "Team B"
    @State private var teamLowPoints = 2
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
        selectedCourse != nil
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
                            } else {
                                Divider()
                                Label("No scorecard data found — Par 3s and handicap won't be tracked", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
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

                // Starting Hole
                Section {
                    Picker("Starting Hole", selection: $startingHole) {
                        ForEach(1...18, id: \.self) { Text("Hole \($0)").tag($0) }
                    }
                } header: {
                    Text("Starting Hole")
                } footer: {
                    if startingHole != 1 {
                        Text("Play order: \(startingHole)–18, then 1–\(startingHole - 1)")
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

                // Game Options (wager modifiers + handicap)
                Section {
                    Toggle("Use Handicap", isOn: $useHandicap)
                    Toggle("Maximum Owed", isOn: $maxOwedEnabled)
                    if maxOwedEnabled {
                        HStack {
                            Text("Cap amount").foregroundStyle(.secondary)
                            Spacer()
                            Text("$").foregroundStyle(.secondary)
                            TextField("20", text: $maxOwedAmountText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }
                    }
                } header: {
                    Text("Game Options")
                } footer: {
                    if !useHandicap {
                        Text("Handicap is off — Low Hole uses gross scores. Handicap fields are hidden in player setup.")
                    } else if maxOwedEnabled {
                        let cap = Int(maxOwedAmountText) ?? 20
                        Text("No player can owe more than $\(cap) regardless of dots lost. Debts are scaled proportionally when the cap applies.")
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
                        if useHandicap {
                            Picker("HCP", selection: $userHandicap) {
                                ForEach(0...36, id: \.self) { hcp in
                                    Text("\(hcp)").tag(hcp)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.caption)
                        }
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
                            if useHandicap {
                                Picker("HCP", selection: $players[index].handicap) {
                                    ForEach(0...36, id: \.self) { hcp in
                                        Text("\(hcp)").tag(hcp)
                                    }
                                }
                                .pickerStyle(.menu)
                                .font(.caption)
                            }
                            Button(role: .destructive) {
                                players.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }
                        }
                        .onAppear {
                            if players[index].handicap == 0 {
                                let p = players[index]
                                players[index].handicap = manager.lookupLastHandicap(name: p.name, phone: p.phoneNumber) ?? 10
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
                            Text("\(teamNameA): \(allPlayers[0].name) & \(allPlayers[1].name)\n\(teamNameB): \(allPlayers[2].name) & \(allPlayers[3].name)\n\nScoring: Individual tasks award dots to teams.")
                        } else {
                            Text("Enable Team Mode for 2v2 gameplay with combined scoring.")
                        }
                    }

                    if isTeamMode {
                        Section("Team Names") {
                            HStack {
                                Text("Team 1 & 2").foregroundStyle(.cyan)
                                Spacer()
                                TextField("Team A", text: $teamNameA)
                                    .multilineTextAlignment(.trailing)
                            }
                            HStack {
                                Text("Team 3 & 4").foregroundStyle(.orange)
                                Spacer()
                                TextField("Team B", text: $teamNameB)
                                    .multilineTextAlignment(.trailing)
                            }
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
                PlayerPickerView(showHandicap: useHandicap) { player in
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
                CustomTaskEditorView(tasks: $customTasks,
                                     isTeamMode: isTeamMode && allPlayers.count == 4,
                                     teamLowPoints: $teamLowPoints)
            }
        }
    }

    @MainActor
    private func createGame() async {
        guard let course = selectedCourse else { return }

        let wager = Int(wagerText) ?? 1
        var rules = GameRules()
        rules.tasks = customTasks
        rules.stakePerPoint = wager
        rules.par3Holes = Set(courseData?.par3Holes ?? [])
        rules.isTeamMode = isTeamMode && allPlayers.count == 4
        if rules.isTeamMode {
            rules.teamNameA = teamNameA.isEmpty ? "Team A" : teamNameA
            rules.teamNameB = teamNameB.isEmpty ? "Team B" : teamNameB
            rules.teamLowPoints = teamLowPoints
        }
        rules.startingHole = startingHole
        rules.maxOwedEnabled = maxOwedEnabled
        rules.maxOwedAmount = Int(maxOwedAmountText) ?? 20
        rules.useHandicap = useHandicap

        // Initialize carry-over values to base points from tasks
        rules.currentGreenieValue = customTasks.first(where: { $0.name == "Greenie" })?.points ?? 1
        rules.currentLowHoleValue = customTasks.first(where: { $0.name == "Low Hole" })?.points ?? 1

        // Keep favorites records current so next-game pre-population is accurate
        for player in allPlayers where favorites.isFavorite(player) {
            favorites.updateHandicap(for: player, handicap: player.handicap)
        }

        await manager.createGame(
            players: allPlayers,
            rules: rules,
            golfCourse: course,
            courseData: courseData
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
