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

                // Stats
                StatisticsView()
                    .tabItem { Label("Stats", systemImage: "chart.pie.fill") }
                    .tag(1)

                // End game
                Color.clear
                    .tabItem { Label("End", systemImage: "flag.checkered") }
                    .tag(2)
            }
            .alert("End Game?", isPresented: $showEndConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("End Game", role: .destructive) { manager.showGameOver = true }
            } message: {
                Text("Are you sure you want to end the game and view results?")
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 2 { showEndConfirm = true; selectedTab = oldValue }
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
