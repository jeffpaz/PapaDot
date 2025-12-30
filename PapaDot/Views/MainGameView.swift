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
            
            Button("End Game") {
                showEndConfirm = true
            }
            .tabItem { Label("End", systemImage: "flag.checkered") }
            .foregroundColor(.red)
        }
        .alert("End Game Now?", isPresented: $showEndConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("End Game", role: .destructive) {
                manager.showGameOver = true
            }
        }
        .navigationTitle("Hole \(manager.game?.currentHole ?? 1)")
        .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
    }
}
