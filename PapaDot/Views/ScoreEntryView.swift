//  Views/ScoreEntryView.swift
import SwiftUI

struct ScoreEntryView: View {
    @Environment(GameManager.self) var manager
    private var g: GameState { manager.game! }
    
    private var isPar3: Bool {
        g.rules.par3Holes.contains(g.currentHole)
    }
    
    private var currentHolePar: Int? {
        guard let courseData = g.courseData,
              g.currentHole > 0,
              g.currentHole <= courseData.holePars.count else {
            print("⚠️ No par data: courseData=\(g.courseData != nil), hole=\(g.currentHole), holePars count=\(g.courseData?.holePars.count ?? 0)")
            return nil
        }
        let par = courseData.holePars[g.currentHole - 1]
        print("✅ Hole \(g.currentHole) Par: \(par)")
        return par
    }
    
    private var canScore: Bool {
        // If guests are allowed to score, everyone can
        if g.rules.allowGuestsToScore {
            return true
        }
        // Otherwise, only the host can score
        return manager.isHost
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
                    // Hole Number
                    HStack(spacing: 12) {
                        Image(systemName: "flag.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hole \(g.currentHole)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            // Par display if course data available
                            if let par = currentHolePar {
                                Text("Par \(par)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green.opacity(0.8))
                            }
                        }
                        
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
                    
                    // View-Only Mode Banner
                    if !canScore {
                        HStack(spacing: 8) {
                            Image(systemName: "eye.fill")
                                .foregroundStyle(.blue)
                            Text("View Only - Only the host can mark dots")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
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
                                        Text(String(player.name.prefix(1)))
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                
                                Text(player.name)
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
                    guard canScore else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        manager.toggleScore(player: player, task: task, hole: g.currentHole)
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
                            .foregroundStyle(isOn ? .green : .white.opacity(canScore ? 0.3 : 0.15))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(!canScore)
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
