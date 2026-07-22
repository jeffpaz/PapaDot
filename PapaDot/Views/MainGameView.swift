// Views/MainGameView.swift
import SwiftUI

struct MainGameView: View {
    @Environment(GameManager.self) var manager
    @AppStorage("colorScheme") private var colorSchemeRaw = "system"
    @State private var showEndConfirm = false
    @State private var showingSideBets = false
    @State private var selectedTab = 0

    private var game: GameState { manager.game ?? GameState(gameID: "", players: [], rules: GameRules()) }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ScoreEntryView()
                    .tabItem {
                        Label("Score", systemImage: "pencil.circle.fill")
                            .accessibilityIdentifier("tab_Score")
                    }
                    .tag(0)

                StatisticsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.pie.fill")
                            .accessibilityIdentifier("tab_Stats")
                    }
                    .tag(1)

                ScorecardView(game: game)
                    .tabItem {
                        Label("Scorecard", systemImage: "tablecells")
                            .accessibilityIdentifier("tab_Scorecard")
                    }
                    .tag(2)

                Color.clear
                    .tabItem {
                        Label("End", systemImage: "flag.checkered")
                            .accessibilityIdentifier("tab_End")
                    }
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
        }
    }

}

#Preview {
    NavigationStack {
        MainGameView()
            .environment(GameManager())
    }
}
