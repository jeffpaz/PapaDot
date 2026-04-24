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
    @State private var showingPlayerPicker = false
    @State private var showingCourseSelection = false
    @State private var showingTaskEditor = false

    @AppStorage("userName") private var userName: String = "Me"
    @AppStorage("userPhoneNumber") private var userPhoneNumber: String = ""
    @AppStorage("userContactID") private var userContactID: String = ""

    @State private var showingUserProfileSetup = false

    private var allPlayers: [Player] {
        [Player(name: userName, phoneNumber: userPhoneNumber)] + players
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
                        Button {
                            showingUserProfileSetup = true
                        } label: {
                            Text("Edit").font(.caption)
                        }
                    }

                    ForEach(players) { player in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name).font(.headline)
                                if !player.phoneNumber.isEmpty {
                                    Text(player.phoneNumber)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                players.removeAll { $0.id == player.id }
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
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
