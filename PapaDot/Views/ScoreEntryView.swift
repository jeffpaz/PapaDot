//  Views/ScoreEntryView.swift
import SwiftUI

struct ScoreEntryView: View {
    @Environment(GameManager.self) var manager
    private var g: GameState { manager.game! }
    
    private var isPar3: Bool {
        g.rules.par3Holes.contains(g.currentHole)
    }
    
    private var visibleTasks: [CustomTask] {
        g.rules.tasks.filter { task in
            if task.name == "Greenie" || task.name == "Sandy" {
                return isPar3
            }
            return true
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Hole \(g.currentHole)")
                    .font(.system(size: 48, weight: .black))
                    .foregroundColor(.green)
                if isPar3 {
                    Text("Par 3 – Greenie: $\(g.currentGreenieValue)")
                        .font(.title3.bold())
                        .foregroundStyle(.yellow)
                }
                HStack {
                    Button("Prev") { manager.setHole(g.currentHole - 1) }
                        .font(.title2.bold()).foregroundColor(.blue)
                    Spacer()
                    Button("Next") { manager.setHole(g.currentHole + 1) }
                        .font(.title2.bold()).foregroundColor(g.currentHole == 18 ? .red : .blue)
                }.padding(.horizontal, 32)
            }
            .padding(.vertical, 16)
            .background(Color.black)
            
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
            .padding(.vertical, 12)
            .background(Color.green.opacity(0.3))
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visibleTasks) { task in
                        HStack(spacing: 0) {
                            Text(task.name)
                                .font(.title3.bold())
                                .frame(width: 100, alignment: .leading)
                                .foregroundColor(task.isNegative ? .red : .green)
                                .padding(.leading, 16)
                            
                            ForEach(g.players) { player in
                                let isOn = g.scores[g.currentHole]?[player.name]?[task.name] ?? false
                                Button {
                                    manager.toggleScore(playerName: player.name, hole: g.currentHole, task: task.name)
                                } label: {
                                    Image(systemName: isOn ? "circle.fill" : "circle")
                                        .font(.system(size: 28))
                                        .foregroundColor(isOn ? .yellow : .white.opacity(0.5))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .background(Color.black.opacity(task.name == "3-Putt" ? 0.3 : 0.15))
                    }
                }
                .padding(.bottom, 90)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    ScoreEntryView()
        .environment(GameManager())
}
