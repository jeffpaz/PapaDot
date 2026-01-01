//  Views/MainGameView.swift
import SwiftUI

struct MainGameView: View {
    @Environment(GameManager.self) var manager
    @State private var showEndConfirm = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ScoreEntryView()
                .tabItem { Label("Score", systemImage: "pencil") }
                .tag(0)
            
            StatisticsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(1)
            
            // Empty view that immediately shows alert and returns to previous tab
            Color.clear
                .tabItem {
                    Label("End", systemImage: "flag.checkered")
                }
                .tag(2)
        }
        .alert("End Game?", isPresented: $showEndConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("End Game", role: .destructive) {
                manager.showGameOver = true
            }
        } message: {
            Text("Are you sure you want to end the game and view results?")
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                // User tapped End tab - show alert and go back to previous tab
                showEndConfirm = true
                selectedTab = oldValue
            }
        }
        .navigationTitle("Hole \(manager.game?.currentHole ?? 1)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MainGameView()
            .environment(GameManager())
    }
}
