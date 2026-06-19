//  Views/GameHistoryView.swift
import SwiftUI

struct GameHistoryView: View {
    @Environment(GameManager.self) private var manager
    @State private var history: [GameState] = []
    
    // Calculate lifetime winnings for all players
    private var lifetimeWinnings: [(player: String, amount: Int)] {
        var totals: [String: Int] = [:]

        for game in history {
            let dots = calculateTotalDots(game: game)
            let stake = game.rules.stakePerPoint
            let isTeamMode = game.rules.isTeamMode && game.players.count == 4

            var gameNet: [String: Int] = [:]
            for player in game.players {
                gameNet[player.name] = 0
            }

            if isTeamMode {
                // Mirror GameOverView.teamDebts: each loser pays each winner dotDiff * stake.
                // calculateTotalDots returns split per-player dots; summing them restores the team total.
                let teamA = [game.players[0], game.players[1]]
                let teamB = [game.players[2], game.players[3]]
                let teamADots = teamA.map { dots[$0] ?? 0 }.reduce(0, +)
                let teamBDots = teamB.map { dots[$0] ?? 0 }.reduce(0, +)
                let dotDiff = abs(teamADots - teamBDots)
                if dotDiff > 0 {
                    let amountPerPerson = dotDiff * stake
                    let losingTeam  = teamADots < teamBDots ? teamA : teamB
                    let winningTeam = teamADots < teamBDots ? teamB : teamA
                    for loser in losingTeam {
                        for winner in winningTeam {
                            gameNet[loser.name, default: 0]  -= amountPerPerson
                            gameNet[winner.name, default: 0] += amountPerPerson
                        }
                    }
                }
            } else {
                for player in game.players {
                    let myDots = dots[player]!
                    for other in game.players where other.id != player.id {
                        let diff = dots[other]! - myDots
                        if diff > 0 {
                            let amount = diff * stake
                            gameNet[player.name]! -= amount
                            gameNet[other.name]! += amount
                        }
                    }
                }
            }

            for (playerName, net) in gameNet {
                totals[playerName, default: 0] += net
            }
        }

        return totals.map { (player: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
    
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
                
                if history.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No games played yet")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Your game history will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Lifetime Leaderboard
                            lifetimeLeaderboardSection()
                            
                            // Game History
                            gameHistorySection()
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        manager.showHistory = false
                    }
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                history = PersistenceManager().loadHistory()
            }
        }
    }
    
    // MARK: - Lifetime Leaderboard Section
    private func lifetimeLeaderboardSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.yellow)
                Text("Lifetime Winnings")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            VStack(spacing: 12) {
                ForEach(Array(lifetimeWinnings.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 16) {
                        // Rank Badge
                        ZStack {
                            Circle()
                                .fill(rankColor(for: index))
                                .frame(width: 44, height: 44)
                            
                            if index < 3 {
                                Image(systemName: rankIcon(for: index))
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(index + 1)")
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        // Player Name
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.player)
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text("\(history.filter { game in game.players.contains(where: { $0.name == item.player }) }.count) games")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        // Winnings
                        Text(item.amount >= 0 ? "+$\(item.amount)" : "-$\(abs(item.amount))")
                            .font(.title3.bold())
                            .foregroundStyle(item.amount >= 0 ? .green : .red)
                            .monospacedDigit()
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Game History Section
    private func gameHistorySection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.white.opacity(0.7))
                Text("Past Rounds")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                ForEach(history, id: \.gameID) { game in
                    NavigationLink {
                        GameOverView(game: game, stake: game.rules.stakePerPoint, isHistoryView: true)
                            .navigationBarBackButtonHidden(false)
                    } label: {
                        gameHistoryCard(game: game)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteGame(game)
                        } label: {
                            Label("Delete Round", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Game History Card
    private func gameHistoryCard(game: GameState) -> some View {
        HStack(spacing: 16) {
            // Trophy Icon
            Circle()
                .fill(Color.yellow.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                        .font(.title3)
                }
            
            VStack(alignment: .leading, spacing: 6) {
                // Winner
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(championName(for: game))
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
                
                // Golf Course (NEW)
                if let course = game.golfCourse {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(course.name)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
                // Players
                Text(game.players.map { $0.name }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                
                // Date
                if let date = game.completedDate {
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Arrow
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.3))
                .font(.caption)
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
    
    // MARK: - Helper Functions
    private func championName(for game: GameState) -> String {
        let dots = calculateTotalDots(game: game)
        return game.players.max(by: { dots[$0]! < dots[$1]! })?.name ?? "Unknown"
    }
    
    private func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return Color.yellow.opacity(0.8)
        case 1: return Color.gray.opacity(0.6)
        case 2: return Color.orange.opacity(0.6)
        default: return Color.white.opacity(0.2)
        }
    }
    
    private func rankIcon(for index: Int) -> String {
        switch index {
        case 0: return "crown.fill"
        case 1: return "medal.fill"
        case 2: return "medal.fill"
        default: return ""
        }
    }
    
    private func deleteGame(_ game: GameState) {
        PersistenceManager().removeFromHistory(gameID: game.gameID)
        history.removeAll { $0.gameID == game.gameID }
    }
}

#Preview {
    GameHistoryView()
        .environment(GameManager())
}

