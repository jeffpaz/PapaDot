//  Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @Environment(GameManager.self) var manager
    @State private var showingCreateGame = false
    @State private var showingJoinGame = false
    
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
                        
                        // Main Content Cards
                        VStack(spacing: 16) {
                            // Start New Game Card (Large)
                            startGameCard()
                            
                            // Join Game & History Cards (Side by Side)
                            HStack(spacing: 16) {
                                joinGameCard()
                                viewHistoryCard()
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
            .sheet(isPresented: $showingJoinGame) {
                JoinGameView()
            }
        }
    }
    
    // MARK: - Start Game Card
    private func startGameCard() -> some View {
        Button {
            showingCreateGame = true
        } label: {
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
                        Image(systemName: "flag.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 20)
                
                VStack(spacing: 8) {
                    Text("Start New Round")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Set up players and begin tracking dots")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Arrow indicator
                HStack {
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .background(.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Join Game Card
    private func joinGameCard() -> some View {
        Button {
            showingJoinGame = true
        } label: {
            VStack(spacing: 16) {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "person.2.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                
                VStack(spacing: 4) {
                    Text("Join Game")
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                    
                    Text("Enter code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - View History Card
    private func viewHistoryCard() -> some View {
        Button {
            manager.showHistory = true
        } label: {
            VStack(spacing: 16) {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                
                VStack(spacing: 4) {
                    Text("History")
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                    
                    Text("Past rounds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 15, y: 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environment(GameManager())
}
