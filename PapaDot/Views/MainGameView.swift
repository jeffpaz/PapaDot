//  Views/MainGameView.swift
import SwiftUI

struct MainGameView: View {
    @Environment(GameManager.self) var manager
    @State private var showEndConfirm = false
    
    var body: some View {
        TabView {
            ScoreEntryView()
                .tabItem { Label("Score", systemImage: "pencil") }
            
            StatisticsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            
            // Empty view that triggers alert
            Color.clear
                .tabItem {
                    Label("End", systemImage: "flag.checkered")
                }
                .onAppear {
                    showEndConfirm = true
                }
        }
        .alert("End Game?", isPresented: $showEndConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("End Game", role: .destructive) {
                manager.showGameOver = true
            }
        } message: {
            Text("Are you sure you want to end the game and view results?")
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
