//  Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @Environment(GameManager.self) var manager
    @State private var showingCreateGame = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.4, blue: 0.2),
                        Color(red: 0.05, green: 0.25, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header Section
                        VStack(spacing: 12) {
                            Image(systemName: "figure.golf")
                                .font(.system(size: 60, weight: .light))
                                .foregroundStyle(.white)
                                .padding(.top, 40)
                            
                            Text("PapaDot")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("Golf Betting Made Simple")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.bottom, 40)
                        }
                        
                        // Main Content Card
                        VStack(spacing: 24) {
                            if let currentGame = manager.currentGame {
                                // Active Game Card
                                activeGameCard(game: currentGame)
                            } else {
                                // No Active Game - Start New
                                emptyStateCard()
                            }
                            
                            // Quick Stats or Recent Games
                            if !manager.recentGames.isEmpty {
                                recentGamesSection()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .sheet(isPresented: $showingCreateGame) {
                CreateGameView()
            }
        }
    }
    
    // MARK: - Active Game Card
    private func activeGameCard(game: GameState) -> some View {
        VStack(spacing: 0) {
            // Card Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Round")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("Hole \(game.currentHole)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                Circle()
                    .fill(.green.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "flag.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
            }
            .padding(24)
            
            Divider()
            
            // Players
            VStack(spacing: 12) {
                ForEach(game.players.prefix(4)) { player in
                    HStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text(String(player.name.prefix(1)))
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                        
                        Text(player.name)
                            .font(.body)
                        
                        Spacer()
                        
                        // Dots count placeholder
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.orange)
                            Text("\(Int.random(in: 0...5))")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(24)
            
            // Continue Button
            NavigationLink {
                GamePlayView()
                    .environment(manager)
            } label: {
                HStack {
                    Text("Continue Round")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.green, .green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(24)
            .padding(.top, -12)
        }
        .background(.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
    }
    
    // MARK: - Empty State Card
    private func emptyStateCard() -> some View {
        VStack(spacing: 24) {
            // Icon
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.green.opacity(0.2), .blue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                }
                .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text("Ready to Play?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("Start a new round and track your dots")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Start Game Button
            Button {
                showingCreateGame = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "flag.fill")
                    Text("Start New Round")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.green, .green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .background(.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
    }
    
    // MARK: - Recent Games Section
    private func recentGamesSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Rounds")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                ForEach(manager.recentGames.prefix(3)) { game in
                    recentGameRow(game: game)
                }
            }
        }
    }
    
    private func recentGameRow(game: GameState) -> some View {
        HStack {
            // Date
            VStack(alignment: .leading, spacing: 4) {
                Text(game.gameID)
                    .font(.headline)
                
                Text("\(game.players.count) players")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status
            HStack(spacing: 8) {
                Text("Completed")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.white)
        .cornerRadius(12)
    }
}

#Preview {
    HomeView()
        .environment(GameManager())
}