// Views/ScoreEntryView.swift
import SwiftUI

struct ScoreEntryView: View {
    @Environment(GameManager.self) var manager
    @AppStorage("userName") private var userName = "Me"

    private var g: GameState { manager.game! }

    private var isHost: Bool {
        g.players.first?.name == userName
    }

    private var liveDots: [Player: Int] { calculateTotalDots(game: g) }

    private var currentHoleDots: [Player: Int] { calculateHoleDots(game: g, hole: g.currentHole) }

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
            // Hide Low Hole - it's auto-awarded based on stroke scores
            if task.name == "Low Hole" { return false }
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
            backgroundGradient

            VStack(spacing: 0) {
                headerSection

                playerHeadersSection

                strokeInputSection

                scoreGridSection
            }
        }
    }

    // MARK: - View Components

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.2, blue: 0.1), Color(red: 0.02, green: 0.15, blue: 0.08)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            holeInfoRow
            liveDotsStrip
            holeNavigationButtons
        }
        .padding(20)
        .background(Color.black.opacity(0.3))
    }

    private var holeInfoRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.fill").font(.title2).foregroundStyle(.green)

            Text("Hole \(g.currentHole)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            holeParBadge

            Text("\(g.currentHole)/18").font(.title3).foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.white.opacity(0.1)).cornerRadius(8)
        }
    }

    @ViewBuilder
    private var holeParBadge: some View {
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
    }

    private var liveDotsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(sortedPlayers) { player in
                    playerDotBadge(player: player)
                }
            }
            .padding(.horizontal, 2)
        }
        .id(manager.updateCounter)
    }

    private func playerDotBadge(player: Player) -> some View {
        let dots = liveDots[player] ?? 0
        let holeDots = currentHoleDots[player] ?? 0
        let isLeader = dots == (liveDots.values.max() ?? 0) && dots > 0

        return HStack(spacing: 3) {
            Text(getInitials(for: player))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isLeader ? .yellow : .white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(isLeader ? Color.yellow.opacity(0.2) : Color.white.opacity(0.15)))

            VStack(spacing: 0) {
                Text("\(dots)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isLeader ? .yellow : .white)
                if holeDots > 0 {
                    Text("(+\(holeDots))")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle((isLeader ? Color.yellow : Color.white).opacity(0.7))
                }
            }

            if isLeader && dots > 0 {
                Image(systemName: "crown.fill").font(.system(size: 8)).foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(Capsule().fill(isLeader ? Color.yellow.opacity(0.1) : Color.white.opacity(0.05)))
    }

    private var holeNavigationButtons: some View {
        HStack(spacing: 12) {
            prevHoleButton
            nextHoleButton
        }
    }

    private var prevHoleButton: some View {
        let isDisabled = g.currentHole == 1 || !isHost

        return Button { manager.setHole(g.currentHole - 1) } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                Text("Prev")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(isDisabled ? Color.white.opacity(0.1) : Color.blue.opacity(0.3))
            .cornerRadius(12)
        }
        .disabled(isDisabled)
    }

    private var nextHoleButton: some View {
        let buttonBackground: AnyShapeStyle = !isHost ? AnyShapeStyle(Color.white.opacity(0.1)) :
            (g.currentHole == 18
            ? AnyShapeStyle(LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)))

        return Button { manager.setHole(g.currentHole + 1) } label: {
            HStack(spacing: 8) {
                Text(g.currentHole == 18 ? "Finish" : "Next")
                Image(systemName: g.currentHole == 18 ? "checkmark" : "chevron.right")
            }
            .font(.headline).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(buttonBackground)
            .cornerRadius(12)
        }
        .disabled(!isHost)
    }

    @ViewBuilder
    private var playerHeadersSection: some View {
        if g.rules.isTeamMode {
            teamModeHeaders()
        } else {
            regularModeHeaders()
        }
    }

    private var strokeInputSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                            .font(.caption).foregroundStyle(.blue)
                        Text("Score").font(.body.bold()).foregroundStyle(.white)
                    }
                    if let holeData = g.courseData?.holes?.first(where: { $0.number == g.currentHole }) {
                        Text("Par \(holeData.par)")
                            .font(.caption2).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(width: 100, alignment: .leading).padding(.leading, 20)

                ForEach(g.players) { player in
                    StrokeScorePicker(
                        player: player,
                        hole: g.currentHole,
                        currentStrokes: g.strokeScores[g.currentHole]?[player.name] ?? defaultPar,
                        defaultPar: defaultPar,
                        isHost: isHost,
                        updateCounter: manager.updateCounter
                    ) { newStrokes in
                        print("🎯 Stroke score changed for \(player.name): \(newStrokes)")
                        manager.setStrokeScore(playerName: player.name, hole: g.currentHole, strokes: newStrokes)
                    } calculateNet: { grossScore in
                        calculateNetScore(player: player, grossScore: grossScore, hole: g.currentHole)
                    }
                }
            }
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.1))
        }
    }

    private var defaultPar: Int {
        g.courseData?.holes?.first(where: { $0.number == g.currentHole })?.par ?? 4
    }

    /// Calculate net score: gross score minus handicap strokes received on this hole
    private func calculateNetScore(player: Player, grossScore: Int, hole: Int) -> Int {
        guard player.handicap > 0 else { return grossScore }
        guard let holeData = g.courseData?.holes?.first(where: { $0.number == hole }),
              let holeHandicap = holeData.handicap else {
            return grossScore // No handicap data, use gross score
        }

        // Calculate strokes received on this hole
        let strokesPerHole = player.handicap / 18
        let extraStrokeHoles = player.handicap % 18
        let strokesReceived = strokesPerHole + (holeHandicap <= extraStrokeHoles ? 1 : 0)

        return max(1, grossScore - strokesReceived)
    }

    private var scoreGridSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(groupedTasks.enumerated()), id: \.offset) { index, group in
                    taskGroupView(group: group, index: index)
                }
            }
            .padding(.bottom, 90)
        }
    }

    private func taskGroupView(group: (title: String?, tasks: [CustomTask]), index: Int) -> some View {
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

    // MARK: - Headers

    private func regularModeHeaders() -> some View {
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

                        if player.name == userName {
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
    }

    private func teamModeHeaders() -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Task")
                    .font(.subheadline.bold()).foregroundStyle(.white.opacity(0.7))
                    .frame(width: 100, alignment: .leading).padding(.leading, 20)

                // Team A
                VStack(spacing: 0) {
                    Text("Team A").font(.caption.bold()).foregroundStyle(.cyan)
                        .padding(.vertical, 4)
                    HStack(spacing: 4) {
                        ForEach([g.players[0], g.players[1]]) { player in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color.cyan.opacity(0.3))
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Text(getInitials(for: player))
                                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                    }
                                Text(getDisplayName(for: player))
                                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Team B
                VStack(spacing: 0) {
                    Text("Team B").font(.caption.bold()).foregroundStyle(.orange)
                        .padding(.vertical, 4)
                    HStack(spacing: 4) {
                        ForEach([g.players[2], g.players[3]]) { player in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color.orange.opacity(0.3))
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Text(getInitials(for: player))
                                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                    }
                                Text(getDisplayName(for: player))
                                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
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

            ForEach(Array(g.players.enumerated()), id: \.element.id) { index, player in
                ScoreToggleButton(
                    playerID: player.id,
                    playerName: player.name,
                    taskName: task.name,
                    hole: g.currentHole,
                    isOn: g.scores[g.currentHole]?[player.name]?[task.name] ?? false,
                    isHost: isHost,
                    updateCounter: manager.updateCounter
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        manager.toggleScore(playerName: player.name, hole: g.currentHole, task: task.name)
                    }
                }
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

// MARK: - Score Toggle Button

/// Isolated button component to prevent view identity confusion
private struct ScoreToggleButton: View {
    let playerID: String
    let playerName: String
    let taskName: String
    let hole: Int
    let isOn: Bool
    let isHost: Bool
    let updateCounter: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(isOn ? Color.green.opacity(0.2) : Color.clear).frame(width: 44, height: 44)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 32))
                    .foregroundStyle(isOn ? .green : .white.opacity(isHost ? 0.3 : 0.15))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!isHost)
        .id("\(playerID)-\(taskName)-\(hole)-\(updateCounter)")
    }
}

// MARK: - Stroke Score Picker

/// Dropdown picker for stroke scores
private struct StrokeScorePicker: View {
    let player: Player
    let hole: Int
    let currentStrokes: Int
    let defaultPar: Int
    let isHost: Bool
    let updateCounter: Int
    let onStrokeChange: (Int) -> Void
    let calculateNet: (Int) -> Int

    var body: some View {
        VStack(spacing: 2) {
            Picker("Score", selection: Binding(
                get: { currentStrokes },
                set: { onStrokeChange($0) }
            )) {
                ForEach(1...12, id: \.self) { strokes in
                    Text("\(strokes)").tag(strokes)
                }
            }
            .pickerStyle(.menu)
            .disabled(!isHost)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            let netScore = calculateNet(currentStrokes)
            if netScore != currentStrokes {
                Text("(net \(netScore))")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.cyan.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .id("\(player.id)-stroke-\(hole)-\(updateCounter)")
    }
}

#Preview {
    ScoreEntryView().environment(GameManager())
}
