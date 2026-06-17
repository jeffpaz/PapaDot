// Views/ScoreEntryView.swift
import SwiftUI

struct ScoreEntryView: View {
    @Environment(GameManager.self) var manager
    @AppStorage("userName") private var userName = "Me"

    private var g: GameState { manager.game ?? GameState(gameID: "", players: [], rules: GameRules()) }

    private var isHost: Bool {
        g.players.first?.name == userName
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

    private var showCarry: Bool {
        g.rules.tasks.contains { $0.name == "Low Hole" }
    }

    private var carryCount: Int {
        let basePoints = max(1, g.rules.tasks.first(where: { $0.name == "Low Hole" })?.points ?? 2)
        return max(0, g.rules.currentLowHoleValue / basePoints - 1)
    }

    private var visibleTasks: [CustomTask] {
        g.rules.tasks.filter { task in
            // Hide Low Hole - it's auto-awarded based on stroke scores
            if task.name == "Low Hole" { return false }
            if task.name == "Fairway" && isPar3 { return false }
            if task.name == "Greenie" { return isPar3 }
            return true
        }
    }

    private var groupedTasks: [(title: String?, tasks: [CustomTask])] {
        if isPar3 {
            let par3Tasks = visibleTasks.filter { $0.name == "Greenie" }
            let other = visibleTasks.filter { $0.name != "Greenie" }
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

            Text("\(g.roundPosition)/18").font(.title3).foregroundStyle(.white.opacity(0.6))
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
        let dots = calculateTotalDots(game: g)
        let holeDots = calculateHoleDots(game: g, hole: g.currentHole)
        let isTeam = g.rules.isTeamMode && g.players.count == 4
        let maxDots = isTeam ? 0 : (dots.values.max() ?? 0)
        let sorted  = isTeam ? [] as [Player] : g.players.sorted { (dots[$0] ?? 0) > (dots[$1] ?? 0) }
        let aSum    = isTeam ? (dots[g.players[0]] ?? 0) + (dots[g.players[1]] ?? 0) : 0
        let bSum    = isTeam ? (dots[g.players[2]] ?? 0) + (dots[g.players[3]] ?? 0) : 0
        let aHole   = isTeam ? (holeDots[g.players[0]] ?? 0) + (holeDots[g.players[1]] ?? 0) : 0
        let bHole   = isTeam ? (holeDots[g.players[2]] ?? 0) + (holeDots[g.players[3]] ?? 0) : 0

        return HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    if isTeam {
                        teamDotBadge(name: g.rules.teamNameA, color: .cyan,   totalDots: aSum, holeDots: aHole)
                        teamDotBadge(name: g.rules.teamNameB, color: .orange, totalDots: bSum, holeDots: bHole)
                    } else {
                        ForEach(sorted) { player in
                            playerDotBadge(
                                player: player,
                                dots: dots[player] ?? 0,
                                holeDots: holeDots[player] ?? 0,
                                isLeader: (dots[player] ?? 0) == maxDots && maxDots > 0
                            )
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            if showCarry {
                VStack(spacing: 0) {
                    Text("Carry")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.orange.opacity(0.8))
                    Text("\(carryCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
                .padding(.horizontal, 6).padding(.vertical, 4)
                .background(Capsule().fill(Color.orange.opacity(0.12)))
                .padding(.leading, 4)
            }
        }
        .id(manager.updateCounter)
    }

    private func teamDotBadge(name: String, color: Color, totalDots: Int, holeDots: Int) -> some View {
        let initials = teamInitials(for: name)
        return HStack(spacing: 3) {
            Text(initials)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
                .background(Circle().fill(color.opacity(0.2)))
            VStack(spacing: 0) {
                Text("\(totalDots)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                if holeDots > 0 {
                    Text("(+\(holeDots))")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(color.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private func teamInitials(for name: String) -> String {
        let words = name.split(separator: " ").map(String.init)
        if words.count >= 2 {
            // Use first letter from each of the first two words
            let a = words[0].first(where: \.isLetter).map(String.init) ?? ""
            let b = words[1].first(where: \.isLetter).map(String.init) ?? ""
            return (a + b).uppercased()
        }
        // Single word: skip non-letter characters (e.g. "A&M" → "AM")
        return String(name.filter(\.isLetter).prefix(2)).uppercased()
    }

    private func playerDotBadge(player: Player, dots: Int, holeDots: Int, isLeader: Bool) -> some View {
        HStack(spacing: 3) {
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
            if isLeader {
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
        let isAtStart = g.currentHole == g.rules.startingHole ||
                        (g.rules.startingHole > 1 && g.currentHole == 1)
        let isDisabled = isAtStart || !isHost

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
        let isFinish = g.isLastHole
        let buttonBackground: AnyShapeStyle = !isHost ? AnyShapeStyle(Color.white.opacity(0.1)) :
            (isFinish
            ? AnyShapeStyle(LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)))

        return Button { manager.advanceHole() } label: {
            HStack(spacing: 8) {
                Text(isFinish ? "Finish" : "Next")
                Image(systemName: isFinish ? "checkmark" : "chevron.right")
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
                .frame(width: 90, alignment: .leading).padding(.leading, 16)

                ForEach(g.players) { player in
                    StrokeScorePicker(
                        player: player,
                        hole: g.currentHole,
                        currentStrokes: g.strokeScores[g.currentHole]?[player.name] ?? defaultPar,
                        defaultPar: defaultPar,
                        isHost: isHost,
                        updateCounter: manager.updateCounter
                    ) { newStrokes in
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

    /// Calculate net score: gross score minus handicap strokes received on this hole.
    /// Par 3 holes receive no handicap strokes. Strokes are distributed
    /// only among non-par-3 holes, ranked by their hole handicap.
    private func calculateNetScore(player: Player, grossScore: Int, hole: Int) -> Int {
        guard g.rules.useHandicap, player.handicap > 0 else { return grossScore }
        guard let allHoles = g.courseData?.holes,
              let holeData = allHoles.first(where: { $0.number == hole }) else { return grossScore }
        guard holeData.par != 3 else { return grossScore }

        let nonPar3 = allHoles.filter { $0.par != 3 }.sorted { ($0.handicap ?? 99) < ($1.handicap ?? 99) }
        let nonPar3Count = nonPar3.count
        guard nonPar3Count > 0, let rankIndex = nonPar3.firstIndex(where: { $0.number == hole }) else {
            return grossScore
        }
        let rank = rankIndex + 1
        let strokesReceived = player.handicap / nonPar3Count + (rank <= player.handicap % nonPar3Count ? 1 : 0)
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
                    ScoreTaskRow(
                        task: task,
                        players: g.players,
                        hole: g.currentHole,
                        holeScores: g.scores[g.currentHole],
                        holeRepeatableCounts: g.repeatableCounts[g.currentHole],
                        isHost: isHost,
                        updateCounter: manager.updateCounter,
                        greenieValue: g.rules.currentGreenieValue
                    ) { playerName in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            manager.toggleScore(playerName: playerName, hole: g.currentHole, task: task.name)
                        }
                    } onAdjustCount: { playerName, delta in
                        manager.adjustRepeatableCount(playerName: playerName, hole: g.currentHole, task: task.name, delta: delta)
                    }
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
                    .frame(width: 90, alignment: .leading).padding(.leading, 16)

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
        let teamA = g.players.count >= 4 ? [g.players[0], g.players[1]] : Array(g.players.prefix(2))
        let teamB = g.players.count >= 4 ? [g.players[2], g.players[3]] : Array(g.players.dropFirst(2))

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Task")
                    .font(.subheadline.bold()).foregroundStyle(.white.opacity(0.7))
                    .frame(width: 90, alignment: .leading).padding(.leading, 16)

                // Team A
                VStack(spacing: 0) {
                    Text(g.rules.teamNameA).font(.caption.bold()).foregroundStyle(.cyan)
                        .padding(.vertical, 4)
                    HStack(spacing: 4) {
                        ForEach(teamA) { player in
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
                    Text(g.rules.teamNameB).font(.caption.bold()).foregroundStyle(.orange)
                        .padding(.vertical, 4)
                    HStack(spacing: 4) {
                        ForEach(teamB) { player in
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

}

// MARK: - Task Row

private struct ScoreTaskRow: View {
    let task: CustomTask
    let players: [Player]
    let hole: Int
    let holeScores: [String: [String: Bool]]?
    let holeRepeatableCounts: [String: [String: Int]]?
    let isHost: Bool
    let updateCounter: Int
    let greenieValue: Int
    let onToggle: (String) -> Void
    let onAdjustCount: (String, Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: taskIcon(for: task.name))
                        .font(.caption).foregroundStyle(task.isNegative ? .red : .green)
                    Text(task.name).font(.body.bold()).foregroundStyle(.white)
                }
                if task.name == "Greenie" {
                    Text("\(greenieValue) point\(greenieValue > 1 ? "s" : "")")
                        .font(.caption2).foregroundStyle(.yellow.opacity(0.8))
                }
            }
            .frame(width: 90, alignment: .leading).padding(.leading, 16)

            ForEach(players) { player in
                if task.isRepeatable {
                    ScoreStepperButton(
                        playerName: player.name,
                        taskName: task.name,
                        hole: hole,
                        count: holeRepeatableCounts?[player.name]?[task.name] ?? 0,
                        isHost: isHost,
                        updateCounter: updateCounter
                    ) { delta in
                        onAdjustCount(player.name, delta)
                    }
                } else {
                    ScoreToggleButton(
                        playerID: player.id,
                        playerName: player.name,
                        taskName: task.name,
                        hole: hole,
                        isOn: holeScores?[player.name]?[task.name] ?? false,
                        isHost: isHost,
                        updateCounter: updateCounter
                    ) {
                        onToggle(player.name)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.02))
    }

    private func taskIcon(for taskName: String) -> String {
        switch taskName {
        case "Fairway":  return "figure.golf"
        case "Birdie":   return "bird"
        case "Poley":    return "flag.fill"
        case "Greenie":  return "leaf.fill"
        case "Low Hole": return "trophy.fill"
        case "Sandy":    return "beach.umbrella"
        case "Sand":     return "exclamationmark.triangle.fill"
        case "OB":       return "xmark.circle.fill"
        case "3-Putt":   return "minus.circle.fill"
        default:         return "circle"
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

// MARK: - Score Stepper Button

/// Compact pill stepper that fits in narrow columns (2–4 players, down to iPhone SE width).
/// Natural content width ≈ 56pt; uses maxWidth:.infinity to center in its column.
private struct ScoreStepperButton: View {
    let playerName: String
    let taskName: String
    let hole: Int
    let count: Int
    let isHost: Bool
    let updateCounter: Int
    let onAdjust: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button { onAdjust(-1) } label: {
                Text("−")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(count > 0 && isHost ? Color.red.opacity(0.9) : Color.white.opacity(0.18))
                    .frame(width: 22, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isHost || count <= 0)

            Text("\(count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(count > 0 ? Color.red : Color.white.opacity(0.28))
                .frame(width: 16)

            Button { onAdjust(1) } label: {
                Text("+")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(count < 3 && isHost ? Color.white.opacity(0.75) : Color.white.opacity(0.18))
                    .frame(width: 22, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isHost || count >= 3)
        }
        .background(
            Capsule()
                .fill(count > 0 ? Color.red.opacity(0.14) : Color.white.opacity(0.07))
                .frame(height: 26)
        )
        .frame(maxWidth: .infinity)
        .id("\(playerName)-\(taskName)-\(hole)-\(updateCounter)")
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

    @State private var isShowingTooltip = false

    private var netScore: Int { calculateNet(currentStrokes) }

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

            if netScore != currentStrokes {
                Text("(net \(netScore))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.cyan.opacity(0.8))
                    .contentShape(Rectangle())
                    .onTapGesture { triggerTooltip() }
                    .onLongPressGesture(minimumDuration: 0.3) { triggerTooltip() }
                    .overlay(alignment: .top) {
                        if isShowingTooltip {
                            Text("Net: \(netScore)")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.05, green: 0.3, blue: 0.15))
                                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                                )
                                .fixedSize()
                                .offset(y: -36)
                                .allowsHitTesting(false)
                                .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .bottom)))
                        }
                    }
                    .zIndex(10)
            }
        }
        .frame(maxWidth: .infinity)
        .id("\(player.id)-stroke-\(hole)-\(updateCounter)")
    }

    private func triggerTooltip() {
        withAnimation(.easeOut(duration: 0.15)) { isShowingTooltip = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeIn(duration: 0.15)) { isShowingTooltip = false }
        }
    }
}

#Preview {
    ScoreEntryView().environment(GameManager())
}
