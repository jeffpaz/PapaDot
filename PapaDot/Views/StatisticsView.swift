//
//  StatisticsView.swift
//  PapaDot
//
//  Created by Jeff Pazahanick on 12/1/25.
//


import SwiftUI

struct StatisticsView: View {
    @Environment(GameManager.self) var manager
    private var g: GameState { manager.game! }
    
    private var totalDots: [Player: Int] { calculateTotalDots(game: g) }
    
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
                    counts[player]![taskName]! += 1
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
                    points[player]! += greenieValue
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

        // Get base Low Hole value (typically 2 dots per hole)
        let basePoints = g.rules.tasks.first(where: { $0.name == "Low Hole" })?.points ?? 2

        print("\n📊 === Low Hole Count Calculation ===")
        print("📊 Base Low Hole value: \(basePoints) dots per hole")
        for hole in 1...18 {
            guard let holeScores = g.scores[hole] else { continue }
            for (playerName, tasks) in holeScores {
                guard let player = g.players.first(where: { $0.name == playerName }) else { continue }
                if tasks["Low Hole"] == true {
                    // Calculate how many Low Holes were won based on dots awarded
                    let dotsAwarded = g.lowHoleValues[hole] ?? basePoints
                    let holesWon = dotsAwarded / basePoints
                    count[player]! += holesWon
                    print("📊 Hole \(hole): \(playerName) won Low Hole, awarded \(dotsAwarded) dots = \(holesWon) holes (count now: \(count[player]!))")
                }
            }
        }
        print("📊 === Final Low Hole Counts: ===")
        for player in g.players {
            print("📊 \(player.name): \(count[player] ?? 0) Low Holes won")
        }
        print("📊 ==============================\n")
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
                            // Use carry-over points for Greenie, count for Low Hole, regular count for others
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
            return "\(components[0].prefix(1))\(components.last!.prefix(1))".uppercased()
        }
        return String(fullName.prefix(1)).uppercased()
    }
}

#Preview {
    StatisticsView()
        .environment(GameManager())
}
