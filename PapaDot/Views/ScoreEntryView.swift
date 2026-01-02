//  Views/ScoreEntryView.swift
import SwiftUI

struct ScoreEntryView: View {
    @Environment(GameManager.self) var manager
    private var g: GameState { manager.game! }
    
    // Calculate live dots for each player
    private var liveDots: [Player: Int] {
        calculateTotalDots(game: g)
    }
    
    // Sorted players by dots (highest first)
    private var sortedPlayers: [Player] {
        g.players.sorted { liveDots[$0] ?? 0 > liveDots[$1] ?? 0 }
    }
    
    // Get initials for player (first + last)
    private func getInitials(for player: Player) -> String {
        let components = player.name.split(separator: " ")
        if components.count >= 2 {
            // First initial + Last initial
            let first = String(components[0].prefix(1))
            let last = String(components[components.count - 1].prefix(1))
            return "\(first)\(last)"
        } else {
            // Just first letter if no space
            return String(player.name.prefix(1))
        }
    }
    
    // Get display name (first name only)
    private func getDisplayName(for player: Player) -> String {
        let components = player.name.split(separator: " ")
        return String(components.first ?? player.name.prefix(20))
    }
    
    private var isPar3: Bool {
        g.rules.par3Holes.contains(g.currentHole)
    }
    
    private var visibleTasks: [CustomTask] {
        g.rules.tasks.filter { task in
            // Only remove Fairway on par 3 holes
            if task.name == "Fairway" && isPar3 {
                return false
            }
            // Only show Greenie and Sandy on par 3 holes
            if task.name == "Greenie" || task.name == "Sandy" {
                return isPar3
            }
            // Show all other tasks
            return true
        }
    }
    
    private var groupedTasks: [(title: String?, tasks: [CustomTask])] {
        var groups: [(title: String?, tasks: [CustomTask])] = []
        
        if isPar3 {
            // Par 3 specific tasks grouped together
            let par3Tasks = visibleTasks.filter { $0.name == "Greenie" || $0.name == "Sandy" }
            if !par3Tasks.isEmpty {
                groups.append((title: "Par 3 Bonuses", tasks: par3Tasks))
            }
            
            // All other tasks (excluding Fairway which shouldn't be here on par 3s)
            let otherTasks = visibleTasks.filter { $0.name != "Greenie" && $0.name != "Sandy" }
            if !otherTasks.isEmpty {
                groups.append((title: "Standard Tasks", tasks: otherTasks))
            }
        } else {
            // Regular holes - no grouping, show all tasks including Fairway
            groups.append((title: nil, tasks: visibleTasks))
        }
        
        return groups
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.2, blue: 0.1),
                    Color(red: 0.02, green: 0.15, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Modern Header
                VStack(spacing: 16) {
                    // Hole Number & Progress
                    HStack(spacing: 12) {
                        Image(systemName: "flag.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        
                        Text("Hole \(g.currentHole)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        // Hole counter
                        Text("\(g.currentHole)/18")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Live Dots Counter
                    HStack(spacing: 8) {
                        ForEach(sortedPlayers) { player in
                            let dots = liveDots[player] ?? 0
                            let isLeader = dots == (liveDots.values.max() ?? 0) && dots > 0
                            
                            HStack(spacing: 6) {
                                // Player initials (first + last)
                                Text(getInitials(for: player))
                                    .font(.caption.bold())
                                    .foregroundStyle(isLeader ? .yellow : .white)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Circle()
                                            .fill(isLeader ? Color.yellow.opacity(0.2) : Color.white.opacity(0.15))
                                    )
                                
                                // Dots count
                                Text(dots >= 0 ? "+\(dots)" : "\(dots)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(isLeader ? .yellow : .white)
                                    .monospacedDigit()
                                
                                // Leader crown
                                if isLeader {
                                    Image(systemName: "crown.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                isLeader ?
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(isLeader ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                    
                    // Par 3 Badge
                    if isPar3 {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("Par 3 – Greenie Worth \(g.rules.currentGreenieValue) Point\(g.rules.currentGreenieValue > 1 ? "s" : "")")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    
                    // Navigation Buttons
                    HStack(spacing: 12) {
                        Button {
                            manager.setHole(g.currentHole - 1)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .font(.headline)
                            .foregroundStyle(g.currentHole == 1 ? .white.opacity(0.3) : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(g.currentHole == 1 ? Color.white.opacity(0.1) : Color.blue.opacity(0.3))
                            .cornerRadius(12)
                        }
                        .disabled(g.currentHole == 1)
                        
                        Button {
                            manager.setHole(g.currentHole + 1)
                        } label: {
                            HStack(spacing: 8) {
                                Text(g.currentHole == 18 ? "Finish" : "Next")
                                Image(systemName: g.currentHole == 18 ? "checkmark" : "chevron.right")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                g.currentHole == 18 ?
                                LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
                .background(Color.black.opacity(0.3))
                
                // Player Headers
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("Task")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 100, alignment: .leading)
                            .padding(.leading, 20)
                        
                        ForEach(g.players) { player in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Text(getInitials(for: player))
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                
                                Text(getDisplayName(for: player))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.05))
                }
                
                // Score Grid
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(groupedTasks.enumerated()), id: \.offset) { index, group in
                            VStack(spacing: 8) {
                                // Group Header
                                if let title = group.title {
                                    HStack {
                                        Text(title)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.yellow)
                                            .textCase(.uppercase)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, index == 0 ? 12 : 20)
                                    .padding(.bottom, 4)
                                }
                                
                                // Tasks Card
                                VStack(spacing: 1) {
                                    ForEach(group.tasks) { task in
                                        taskRow(task: task)
                                    }
                                }
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(16)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 90)
                }
            }
        }
    }
    
    // MARK: - Task Row Component
    private func taskRow(task: CustomTask) -> some View {
        HStack(spacing: 0) {
            // Task Name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    // Task icon
                    Image(systemName: taskIcon(for: task.name))
                        .font(.caption)
                        .foregroundStyle(task.isNegative ? .red : .green)
                    
                    Text(task.name)
                        .font(.body.bold())
                        .foregroundStyle(.white)
                }
                
                // Greenie point value
                if task.name == "Greenie" {
                    Text("\(g.rules.currentGreenieValue) point\(g.rules.currentGreenieValue > 1 ? "s" : "")")
                        .font(.caption2)
                        .foregroundStyle(.yellow.opacity(0.8))
                }
            }
            .frame(width: 100, alignment: .leading)
            .padding(.leading, 20)
            
            // Player Score Buttons
            ForEach(g.players) { player in
                let isOn = g.scores[g.currentHole]?[player.name]?[task.name] ?? false
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        manager.toggleScore(playerName: player.name, hole: g.currentHole, task: task.name)
                    }
                } label: {
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(isOn ? Color.green.opacity(0.2) : Color.clear)
                            .frame(width: 44, height: 44)
                        
                        // Checkmark or empty circle
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 32))
                            .foregroundStyle(isOn ? .green : .white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.02))
    }
    
    // MARK: - Task Icons
    private func taskIcon(for taskName: String) -> String {
        switch taskName {
        case "Fairway": return "figure.golf"
        case "Birdie": return "bird"
        case "Poley": return "flag.fill"
        case "Greenie": return "leaf.fill"
        case "Low Hole": return "trophy.fill"
        case "Sandy": return "beach.umbrella"
        case "Sand": return "exclamationmark.triangle.fill"
        case "OB": return "xmark.circle.fill"
        case "3-Putt": return "minus.circle.fill"
        default: return "circle"
        }
    }
}

#Preview {
    ScoreEntryView()
        .environment(GameManager())
}
