// Views/MainGameView.swift
import SwiftUI

struct MainGameView: View {
    @Environment(GameManager.self) var manager
    @AppStorage("colorScheme") private var colorSchemeRaw = "system"
    @State private var showEndConfirm = false
    @State private var showingSideBets = false
    @State private var selectedTab = 0

    private var game: GameState { manager.game! }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Score Entry
                ScoreEntryView()
                    .tabItem { Label("Score", systemImage: "pencil.circle.fill") }
                    .tag(0)

                // Live Leaderboard
                leaderboardTab
                    .tabItem { Label("Board", systemImage: "chart.bar.fill") }
                    .tag(1)

                // Stats
                StatisticsView()
                    .tabItem { Label("Stats", systemImage: "chart.pie.fill") }
                    .tag(2)

                // End game
                Color.clear
                    .tabItem { Label("End", systemImage: "flag.checkered") }
                    .tag(3)
            }
            .alert("End Game?", isPresented: $showEndConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("End Game", role: .destructive) { manager.showGameOver = true }
            } message: {
                Text("Are you sure you want to end the game and view results?")
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 3 { showEndConfirm = true; selectedTab = oldValue }
            }
            .navigationTitle("Hole \(game.currentHole)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSideBets = true
                    } label: {
                        Label("Side Bets", systemImage: "dollarsign.circle.fill")
                            .foregroundStyle(.yellow)
                    }
                }
            }
            .sheet(isPresented: $showingSideBets) {
                SideBetsView()
            }

            // Reaction overlay — appears when a reaction comes in
            if let reaction = manager.incomingReaction {
                ReactionOverlayView(reaction: reaction)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(99)
            }
        }
        .animation(.spring(response: 0.4), value: manager.incomingReaction?.id)
    }

    // MARK: - Leaderboard Tab

    private var leaderboardTab: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.35, blue: 0.2), Color(red: 0.05, green: 0.2, blue: 0.1)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Live leaderboard
                    LiveLeaderboardView(game: game)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Active side bets summary
                    if !game.sideBets.filter({ $0.status == .active }).isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "dollarsign.circle.fill").foregroundStyle(.yellow)
                                Text("Side Bets").font(.headline.bold()).foregroundStyle(.white)
                                Spacer()
                                Button("View All") { showingSideBets = true }
                                    .font(.caption.bold()).foregroundStyle(.yellow)
                            }
                            ForEach(game.sideBets.filter { $0.status == .active }.prefix(3)) { bet in
                                HStack {
                                    Text(bet.title).font(.subheadline).foregroundStyle(.white)
                                    Spacer()
                                    Text("$\(bet.amount)").font(.subheadline.bold()).foregroundStyle(.yellow)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                    }

                    // Reaction feed
                    ReactionFeedView(reactions: game.reactions)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MainGameView()
            .environment(GameManager())
    }
}
