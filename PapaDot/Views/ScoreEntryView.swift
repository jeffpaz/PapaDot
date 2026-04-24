// Views/ScoreEntryView.swift
import SwiftUI

struct ScoreEntryView: View {
    @Environment(GameManager.self) var manager
    @AppStorage("userName") private var userName = "Me"
    @State private var reactionTarget: Player? = nil
    @State private var reactionTaskName = ""

    private var g: GameState { manager.game! }

    private var liveDots: [Player: Int] { calculateTotalDots(game: g) }

    private var sortedPlayers: [Player] {
        g.players.sorted { liveDots[$0] ?? 0 > liveDots[$1] ?? 0 }
    }

    private func getInitials(for player: Player) -> String {
        let parts = player.name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[parts.count - 1].prefix(1))"
        }
        return String(player.name.prefix(1))
    }

    private func getDisplayName(for player: Player) -> String {
        String(player.name.split(separator: " ").first ?? player.name.prefix(20))
    }

    private var isPar3: Bool { g.rules.par3Holes.contains(g.currentHole) }

    private var visibleTasks: [CustomTask] {
        g.rules.tasks.filter { task in
            if task.name == "Fairway" && isPar3 { return false }
            if task.name == "Greenie" || task.name == "Sandy" { return isPar3 }
            return true
        }
    }

    private var groupedTasks: [(title: String?, tasks: [CustomTask])] {
        if isPar3 {
            let par3Tasks = visibleTasks.filter { $0.name == "Greenie" || $0.name == "Sandy" }
            let other = visibleTasks.filter { $0.name != "Greenie" && $0.name != "Sandy" }
            var groups: [(String?, [CustomTask])] = []
            if !par3Tasks.isEmpty { groups.append(("Par 3 Bonuses", par3Tasks)) }
            if !other.isEmpty { groups.append(("Standard Tasks", other)) }
            return groups
        }
        return [(nil, visibleTasks)]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.2, blue: 0.1), Color(red: 0.02, green: 0.15, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "flag.fill").font(.title2).foregroundStyle(.green)

                        Text("Hole \(g.currentHole)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()

                        if isPar3 {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                                Text("Par 3").font(.subheadline.bold()).foregroundStyle(.yellow)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.2)).cornerRadius(8)
                        } else if let holeData = g.courseData?.holes?.first(where: { $0.number == g.currentHole }) {
                            HStack(spacing: 6) {
                                Text("Par \(holeData.par)").font(.subheadline.bold()).foregroundStyle(.white)
                                if holeData.yardage > 0 {
                                    Text("•").foregroundStyle(.white.opacity(0.5))
                                    Text("\(holeData.yardage) yds").font(.subheadline).foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.white.opacity(0.1)).cornerRadius(8)
                        } else {
                            Text("Par 4").font(.subheadline.bold()).foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.white.opacity(0.1)).cornerRadius(8)
                        }

                        Text("\(g.currentHole)/18").font(.title3).foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.white.opacity(0.1)).cornerRadius(8)
                    }

                    // Live dots strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(sortedPlayers) { player in
                                let dots = liveDots[player] ?? 0
                                let isLeader = dots == (liveDots.values.max() ?? 0) && dots > 0
                                HStack(spacing: 3) {
                                    Text(getInitials(for: player))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(isLeader ? .yellow : .white)
                                        .frame(width: 18, height: 18)
                                        .background(Circle().fill(isLeader ? Color.yellow.opacity(0.2) : Color.white.opacity(0.15)))
                                    Text("\(dots)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(isLeader ? .yellow : .white)
                                    if isLeader && dots > 0 {
                                        Image(systemName: "crown.fill").font(.system(size: 8)).foregroundStyle(.yellow)
                                    }
                                }
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .background(Capsule().fill(isLeader ? Color.yellow.opacity(0.1) : Color.white.opacity(0.05)))
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    // Hole navigation
                    HStack(spacing: 12) {
                        Button { manager.setHole(g.currentHole - 1) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                Text("Prev")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(g.currentHole == 1 ? Color.white.opacity(0.1) : Color.blue.opacity(0.3))
                            .cornerRadius(12)
                        }
                        .disabled(g.currentHole == 1)

                        Button { manager.setHole(g.currentHole + 1) } label: {
                            HStack(spacing: 8) {
                                Text(g.currentHole == 18 ? "Finish" : "Next")
                                Image(systemName: g.currentHole == 18 ? "checkmark" : "chevron.right")
                            }
                            .font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(g.currentHole == 18
                                ? LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(20)
                .background(Color.black.opacity(0.3))

                // Player Headers with 🔥 Reaction buttons
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("Task")
                            .font(.subheadline.bold()).foregroundStyle(.white.opacity(0.7))
                            .frame(width: 100, alignment: .leading).padding(.leading, 20)

                        ForEach(g.players) { player in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Text(getInitials(for: player))
                                            .font(.caption.bold()).foregroundStyle(.white)
                                    }
                                Text(getDisplayName(for: player))
                                    .font(.caption).foregroundStyle(.white.opacity(0.8)).lineLimit(1)

                                // 🔥 Reaction button — only for other players
                                if player.name != userName {
                                    Button {
                                        reactionTarget = player
                                        reactionTaskName = "their play"
                                    } label: {
                                        Text("🔥")
                                            .font(.system(size: 14))
                                            .padding(4)
                                            .background(Color.orange.opacity(0.15))
                                            .cornerRadius(8)
                                    }
                                } else {
                                    Text("(you)").font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                }

                // Score Grid
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(groupedTasks.enumerated()), id: \.offset) { index, group in
                            VStack(spacing: 8) {
                                if let title = group.title {
                                    HStack {
                                        Text(title).font(.subheadline.bold()).foregroundStyle(.yellow)
                                            .textCase(.uppercase)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, index == 0 ? 12 : 20)
                                    .padding(.bottom, 4)
                                }
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
        // Reaction picker sheet
        .sheet(item: $reactionTarget) { player in
            ReactionPickerView(
                fromPlayer: userName,
                toPlayer: player.name,
                hole: g.currentHole,
                taskName: reactionTaskName
            )
        }
    }

    // MARK: - Task Row

    private func taskRow(task: CustomTask) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: taskIcon(for: task.name))
                        .font(.caption).foregroundStyle(task.isNegative ? .red : .green)
                    Text(task.name).font(.body.bold()).foregroundStyle(.white)
                }
                if task.name == "Greenie" {
                    Text("\(g.rules.currentGreenieValue) point\(g.rules.currentGreenieValue > 1 ? "s" : "")")
                        .font(.caption2).foregroundStyle(.yellow.opacity(0.8))
                }
            }
            .frame(width: 100, alignment: .leading).padding(.leading, 20)

            ForEach(g.players) { player in
                let isOn = g.scores[g.currentHole]?[player.name]?[task.name] ?? false
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        manager.toggleScore(playerName: player.name, hole: g.currentHole, task: task.name)
                    }
                } label: {
                    ZStack {
                        Circle().fill(isOn ? Color.green.opacity(0.2) : Color.clear).frame(width: 44, height: 44)
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 32))
                            .foregroundStyle(isOn ? .green : .white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .id("\(player.id)-\(task.name)-\(g.currentHole)-\(manager.updateCounter)")
            }
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.02))
    }

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
    ScoreEntryView().environment(GameManager())
}
