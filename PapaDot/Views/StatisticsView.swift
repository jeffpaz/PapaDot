//
//  StatisticsView.swift
//  PapaDot
//
//  Created by Jeff Pazahanick on 12/1/25.
//


import SwiftUI

struct StatisticsView: View {
    @Environment(GameManager.self) var manager
    private var g: GameState { manager.game ?? GameState(gameID: "", players: [], rules: GameRules()) }
    
    private var totalDots: [Player: Int] { calculateTotalDots(game: g) }

    private var teamLowByTeam: [String: Int] {
        guard g.rules.isTeamMode && g.players.count == 4 else { return [:] }
        var counts: [String: Int] = [:]
        for hole in 1...18 {
            if let winner = g.teamLowWinner[hole] {
                counts[winner, default: 0] += g.rules.teamLowPoints
            }
        }
        return counts
    }

    private var teamTotalDots: [String: Int] {
        guard g.rules.isTeamMode && g.players.count == 4 else { return [:] }
        let dots = totalDots
        return [
            "A": (dots[g.players[0]] ?? 0) + (dots[g.players[1]] ?? 0),
            "B": (dots[g.players[2]] ?? 0) + (dots[g.players[3]] ?? 0)
        ]
    }
    
    private var taskCounts: [Player: [String: Int]] {
        var counts = [Player: [String: Int]]()
        for player in g.players {
            var dict = [String: Int]()
            for task in g.rules.tasks { dict[task.name] = 0 }
            counts[player] = dict
        }
        
        for hole in 1...18 {
            guard let holeScores = g.scores[hole] else { continue }
            for (playerName, tasks) in holeScores {
                guard let player = g.players.first(where: { $0.name == playerName }) else { continue }
                for (taskName, scored) in tasks where scored {
                    counts[player, default: [:]][taskName, default: 0] += 1
                }
            }
        }

        // Repeatable tasks (e.g. Sand, OB) are stored in repeatableCounts, not scores
        for hole in 1...18 {
            guard let holeCounts = g.repeatableCounts[hole] else { continue }
            for (playerName, taskCounts) in holeCounts {
                guard let player = g.players.first(where: { $0.name == playerName }) else { continue }
                for (taskName, count) in taskCounts where count > 0 {
                    counts[player, default: [:]][taskName, default: 0] += count
                }
            }
        }

        return counts
    }
    
    // Calculate carry-over task points (Greenie, Low Hole) instead of count
    private var greeniePoints: [Player: Int] {
        var points = [Player: Int]()
        for player in g.players {
            points[player] = 0
        }

        for hole in 1...18 {
            guard let holeScores = g.scores[hole] else { continue }
            for (playerName, tasks) in holeScores {
                guard let player = g.players.first(where: { $0.name == playerName }) else { continue }
                if tasks["Greenie"] == true {
                    // Use the stored greenie value for this hole
                    let greenieValue = g.greenieValues[hole] ?? 1
                    points[player, default: 0] += greenieValue
                }
            }
        }
        return points
    }

    private var lowHoleCount: [Player: Int] {
        var count = [Player: Int]()
        for player in g.players {
            count[player] = 0
        }

        let basePoints = g.rules.tasks.first(where: { $0.name == "Low Hole" })?.points ?? 2

        for hole in 1...18 {
            guard let holeScores = g.scores[hole] else { continue }
            for (playerName, tasks) in holeScores {
                guard let player = g.players.first(where: { $0.name == playerName }) else { continue }
                if tasks["Low Hole"] == true {
                    let dotsAwarded = g.lowHoleValues[hole] ?? basePoints
                    let holesWon = dotsAwarded / basePoints
                    count[player, default: 0] += holesWon
                }
            }
        }
        return count
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with better contrast
                HStack(spacing: 0) {
                    Text("Task")
                        .frame(width: 100, alignment: .leading)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.leading, 16)
                    
                    ForEach(g.players) { player in
                        VStack(spacing: 4) {
                            // Player name (first name only for space)
                            Text(getFirstName(player.name))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            // Initials badge
                            Text(getInitials(player.name))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.5, blue: 0.25),
                            Color(red: 0.1, green: 0.4, blue: 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1),
                    alignment: .bottom
                )
                
                ForEach(g.rules.tasks) { task in
                    HStack(spacing: 0) {
                        Text(task.name)
                            .frame(width: 100, alignment: .leading)
                            .font(.title3.bold())
                            .foregroundColor(task.isNegative ? .red : .green)
                            .padding(.leading, 16)

                        ForEach(g.players) { player in
                            let displayValue: Int = {
                                if task.name == "Greenie" {
                                    return greeniePoints[player] ?? 0
                                } else if task.name == "Low Hole" {
                                    return lowHoleCount[player] ?? 0
                                } else {
                                    return taskCounts[player]?[task.name] ?? 0
                                }
                            }()

                            Text(displayValue > 0 ? "\(displayValue)" : "–")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity)
                                .foregroundColor(displayValue > 0 ? (task.isNegative ? .red : .yellow) : .white.opacity(0.3))
                        }
                    }
                    .padding(.vertical, 11)
                }

                // Team Low row — only shown in team mode when Low Hole task is active
                if g.rules.isTeamMode && g.players.count == 4 && g.rules.tasks.contains(where: { $0.name == "Low Hole" }) {
                    let aVal = teamLowByTeam["A"] ?? 0
                    let bVal = teamLowByTeam["B"] ?? 0
                    HStack(spacing: 0) {
                        Text("Team\nLow")
                            .frame(width: 100, alignment: .leading)
                            .font(.title3.bold())
                            .foregroundColor(.cyan)
                            .padding(.leading, 16)
                        Text(aVal > 0 ? "\(aVal)" : "–")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .foregroundColor(aVal > 0 ? .cyan : .white.opacity(0.3))
                        Text(bVal > 0 ? "\(bVal)" : "–")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .foregroundColor(bVal > 0 ? .orange : .white.opacity(0.3))
                    }
                    .padding(.vertical, 11)
                    .background(Color.cyan.opacity(0.06))
                }

                if g.rules.isTeamMode && g.players.count == 4 {
                    let aTotal = teamTotalDots["A"] ?? 0
                    let bTotal = teamTotalDots["B"] ?? 0
                    HStack(spacing: 0) {
                        Text("TEAM\nTOTAL")
                            .frame(width: 100, alignment: .leading)
                            .font(.title2.bold())
                            .foregroundColor(.green)
                            .padding(.leading, 16)
                        Text("\(aTotal)")
                            .font(.system(size: 36, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.cyan)
                        Text("\(bTotal)")
                            .font(.system(size: 36, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 18)
                    .background(Color.yellow.opacity(0.2))
                } else {
                    HStack(spacing: 0) {
                        Text("TOTAL")
                            .frame(width: 100, alignment: .leading)
                            .font(.title2.bold())
                            .foregroundColor(.green)
                            .padding(.leading, 16)

                        ForEach(g.players) { player in
                            let dots = totalDots[player] ?? 0
                            Text("\(dots)")
                                .font(.system(size: 36, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .foregroundColor(dots >= 0 ? .green : .red)
                        }
                    }
                    .padding(.vertical, 18)
                    .background(Color.yellow.opacity(0.2))
                }
            }
            .cornerRadius(20)
            .padding(16)
        }
        .navigationTitle("Stats")
        .background(Color.black.ignoresSafeArea())
    }
    
    // MARK: - Helper Functions
    
    private func getFirstName(_ fullName: String) -> String {
        fullName.split(separator: " ").first.map(String.init) ?? fullName
    }
    
    private func getInitials(_ fullName: String) -> String {
        let components = fullName.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components.last?.prefix(1) ?? "")".uppercased()
        }
        return String(fullName.prefix(1)).uppercased()
    }
}

#Preview {
    StatisticsView()
        .environment(GameManager())
}
