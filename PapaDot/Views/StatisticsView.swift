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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Task")
                        .frame(width: 100, alignment: .leading)
                        .font(.headline.bold())
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                    ForEach(g.players) { player in
                        Text(player.name)
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 14)
                .background(Color.green.opacity(0.3))
                
                ForEach(g.rules.tasks) { task in
                    HStack(spacing: 0) {
                        Text(task.name)
                            .frame(width: 100, alignment: .leading)
                            .font(.title3.bold())
                            .foregroundColor(task.isNegative ? .red : .green)
                            .padding(.leading, 16)
                        
                        ForEach(g.players) { player in
                            let count = taskCounts[player]?[task.name] ?? 0
                            Text(count > 0 ? "\(count)" : "–")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity)
                                .foregroundColor(count > 0 ? (task.isNegative ? .red : .yellow) : .white.opacity(0.3))
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
}

#Preview {
    StatisticsView()
        .environment(GameManager())
}
