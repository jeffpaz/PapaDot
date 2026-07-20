//  Views/GameOverView.swift
import SwiftUI
import MessageUI

struct GameOverView: View {
    let game: GameState
    let stake: Int
    var isHistoryView: Bool = false
    @Environment(GameManager.self) var manager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 1   // default Payouts — what everyone wants first
    @State private var showShareMessage = false
    @State private var showMessagingUnavailableAlert = false
    @State private var trophyScale: CGFloat = 0.3
    @State private var trophyOpacity: Double = 0

    private var totalDots: [Player: Int] { calculateTotalDots(game: game) }
    private var isTeamMode: Bool { game.rules.isTeamMode && game.players.count == 4 }

    private var teamResults: [(team: String, players: [Player], totalDots: Int)] {
        guard isTeamMode else { return [] }
        let dots = totalDots
        let teamA = [game.players[0], game.players[1]]
        let teamB = [game.players[2], game.players[3]]
        let teamADots = teamA.map { dots[$0] ?? 0 }.reduce(0, +)
        let teamBDots = teamB.map { dots[$0] ?? 0 }.reduce(0, +)
        return [
            (team: "A", players: teamA, totalDots: teamADots),
            (team: "B", players: teamB, totalDots: teamBDots)
        ].sorted { $0.totalDots > $1.totalDots }
    }

    private var winningTeam: String? {
        guard isTeamMode, teamResults.count == 2 else { return nil }
        return teamResults[0].totalDots > teamResults[1].totalDots ? teamResults[0].team : nil
    }

    private var teamDebts: [(player: Player, owes: [(to: Player, amount: Int)])] {
        guard isTeamMode, teamResults.count == 2 else { return [] }
        let teamADots = teamResults.first(where: { $0.team == "A" })?.totalDots ?? 0
        let teamBDots = teamResults.first(where: { $0.team == "B" })?.totalDots ?? 0
        let dotDiff = abs(teamADots - teamBDots)
        let amountPerPerson = dotDiff * stake
        if teamADots == teamBDots { return [] }
        let losingTeam  = teamADots > teamBDots ? teamResults.first(where: { $0.team == "B" })?.players ?? [] : teamResults.first(where: { $0.team == "A" })?.players ?? []
        let winningTeam = teamADots > teamBDots ? teamResults.first(where: { $0.team == "A" })?.players ?? [] : teamResults.first(where: { $0.team == "B" })?.players ?? []
        var result: [(player: Player, owes: [(to: Player, amount: Int)])] = []
        for loser in losingTeam {
            result.append((player: loser, owes: winningTeam.map { (to: $0, amount: amountPerPerson) }))
        }
        return result
    }

    private var debtsByPayer: [(player: Player, owes: [(to: Player, amount: Int)])] {
        if isTeamMode { return teamDebts }
        var result: [(player: Player, owes: [(to: Player, amount: Int)])] = []
        for player in game.players.sorted(by: { $0.name < $1.name }) {
            let myDots = totalDots[player] ?? 0
            let owes = game.players
                .filter { $0.id != player.id }
                .compactMap { other -> (to: Player, amount: Int)? in
                    let diff = (totalDots[other] ?? 0) - myDots
                    return diff > 0 ? (to: other, amount: diff * stake) : nil
                }
                .sorted { $0.to.name < $1.to.name }
            if !owes.isEmpty { result.append((player: player, owes: owes)) }
        }
        return result
    }

    private var cappedDebtsByPayer: [(player: Player, owes: [(to: Player, amount: Int, originalAmount: Int, isCapped: Bool)])] {
        let cap = game.rules.maxOwedAmount
        let capEnabled = game.rules.maxOwedEnabled
        return debtsByPayer.map { group in
            let rawOwes = group.owes
            guard capEnabled else {
                return (player: group.player, owes: rawOwes.map { (to: $0.to, amount: $0.amount, originalAmount: $0.amount, isCapped: false) })
            }
            let totalDebt = rawOwes.reduce(0) { $0 + $1.amount }
            guard totalDebt > cap else {
                return (player: group.player, owes: rawOwes.map { (to: $0.to, amount: $0.amount, originalAmount: $0.amount, isCapped: false) })
            }
            let sorted = rawOwes.sorted { $0.amount > $1.amount }
            var remaining = cap
            var cappedOwes: [(to: Player, amount: Int, originalAmount: Int, isCapped: Bool)] = []
            for (index, debt) in sorted.enumerated() {
                let share: Int = index == sorted.count - 1 ? remaining : {
                    let s = Int(Double(debt.amount) / Double(totalDebt) * Double(cap))
                    remaining -= s
                    return s
                }()
                cappedOwes.append((to: debt.to, amount: share, originalAmount: debt.amount, isCapped: true))
            }
            return (player: group.player, owes: cappedOwes)
        }
    }

    private var anyCapped: Bool {
        cappedDebtsByPayer.flatMap { $0.owes }.contains { $0.isCapped }
    }

    private var netSummary: [(player: Player, net: Int)] {
        var net = Dictionary(uniqueKeysWithValues: game.players.map { ($0, 0) })
        for group in cappedDebtsByPayer {
            for debt in group.owes {
                net[group.player, default: 0] -= debt.amount
                net[debt.to, default: 0] += debt.amount
            }
        }
        return game.players.map { ($0, net[$0] ?? 0) }.sorted { $0.1 > $1.1 }
    }

    private var champion: Player? {
        if isTeamMode { return nil }
        let max = netSummary.first?.net ?? 0
        let winners = netSummary.filter { $0.net == max }
        return winners.count == game.players.count ? nil : winners.first?.player
    }

    private var championTeam: String? {
        guard isTeamMode else { return nil }
        return winningTeam
    }

    private var myPlayer: Player? { game.players.first }

    private var myNet: Int {
        guard let me = myPlayer else { return 0 }
        return netSummary.first(where: { $0.player.id == me.id })?.net ?? 0
    }

    // MARK: - Player Task Counts

    private var playerTaskCounts: [Player: [String: Int]] {
        var counts = [Player: [String: Int]]()
        for player in game.players { counts[player] = [:] }
        for hole in 1...18 {
            if let holeScores = game.scores[hole] {
                for (playerName, tasks) in holeScores {
                    guard let player = game.players.first(where: { $0.name == playerName }) else { continue }
                    for (taskName, scored) in tasks where scored {
                        if taskName == "Greenie" {
                            counts[player, default: [:]][taskName, default: 0] += game.greenieValues[hole] ?? 1
                        } else if taskName == "Low Hole" {
                            counts[player, default: [:]][taskName, default: 0] += game.lowHoleValues[hole] ?? 1
                        } else {
                            counts[player, default: [:]][taskName, default: 0] += 1
                        }
                    }
                }
            }
            if let holeCounts = game.repeatableCounts[hole] {
                for (playerName, taskCounts) in holeCounts {
                    guard let player = game.players.first(where: { $0.name == playerName }) else { continue }
                    for (taskName, count) in taskCounts where count > 0 {
                        counts[player, default: [:]][taskName, default: 0] += count
                    }
                }
            }
        }
        return counts
    }

    // MARK: - Stats Helpers

    private var totalOwedByPlayer: [String: Int] {
        var result = [String: Int]()
        for group in cappedDebtsByPayer {
            result[group.player.id] = group.owes.reduce(0) { $0 + $1.amount }
        }
        return result
    }

    private var maxDots: Int { max(1, game.players.map { totalDots[$0] ?? 0 }.max() ?? 1) }

    private var bestHoleHighlight: (hole: Int, playerName: String, dots: Int, tasks: String)? {
        var best: (hole: Int, playerName: String, dots: Int, tasks: String)? = nil
        for hole in 1...18 {
            let holeDots = calculateHoleDots(game: game, hole: hole)
            for (player, dots) in holeDots {
                guard dots > (best?.dots ?? 0) else { continue }
                let scored = (game.scores[hole]?[player.name] ?? [:])
                    .filter { $0.value }
                    .compactMap { name, _ -> String? in
                        guard let t = game.rules.tasks.first(where: { $0.name == name }),
                              !t.isNegative else { return nil }
                        return name
                    }
                    .sorted()
                best = (hole: hole, playerName: player.name, dots: dots, tasks: scored.joined(separator: " + "))
            }
        }
        return best
    }

    private var funLoserLabels: [(playerName: String, label: String)] {
        let checks: [(String, String)] = [
            ("Sand",   "Sand Trap King 🏖️"),
            ("OB",     "OB Leader 🚫"),
            ("3-Putt", "3-Putt Club 🙈"),
        ]
        var result: [(String, String)] = []
        for (taskName, label) in checks {
            guard game.rules.tasks.contains(where: { $0.name == taskName }) else { continue }
            let counts = game.players.map { p in (p.name, playerTaskCounts[p]?[taskName] ?? 0) }
            let maxCount = counts.map(\.1).max() ?? 0
            guard maxCount > 0 else { continue }
            let leaders = counts.filter { $0.1 == maxCount }
            guard leaders.count < game.players.count else { continue }
            result.append((leaders[0].0, "\(leaders[0].0): \(label)"))
        }
        return result
    }

    // MARK: - Share Text

    private var shareText: String {
        let courseName = game.golfCourse?.name ?? "Course"
        let dateStr: String = {
            guard let d = game.completedDate else { return "" }
            let f = DateFormatter()
            f.dateStyle = .medium; f.timeStyle = .none
            return f.string(from: d)
        }()

        var t = "🏌️ PapaDot Results\n"
        if isTeamMode {
            if let wt = championTeam {
                let td = teamResults.first(where: { $0.team == wt })?.totalDots ?? 0
                t += "🏆 Team \(wt) wins! (+\(td) dots)\n"
            } else {
                t += "🤝 Teams Tied!\n"
            }
        } else {
            if let champ = champion {
                t += "🏆 \(champ.name) wins! (+\(totalDots[champ] ?? 0) dots)\n"
            } else {
                t += "🤝 Everyone Tied!\n"
            }
        }
        t += "📍 \(courseName)"
        if !dateStr.isEmpty { t += " · \(dateStr)" }
        t += "\n──────────────\n"

        let sorted = game.players.sorted { (totalDots[$0] ?? 0) > (totalDots[$1] ?? 0) }
        for player in sorted {
            let dots = totalDots[player] ?? 0
            let net  = netSummary.first(where: { $0.player.id == player.id })?.net ?? 0
            let netStr = net >= 0 ? "+$\(net)" : "-$\(abs(net))"
            t += "\(player.name) · \(dots) dots · \(netStr)\n"
        }
        t += "──────────────\n"

        let emojiMap: [String: String] = [
            "Fairway": "✅", "Birdie": "🐦", "Eagle": "🦅", "Greenie": "🌿",
            "Poley": "🚩", "Sandy": "⛱️", "Sand": "🏖️", "OB": "🚫",
            "3-Putt": "😬", "4-Putt": "😱", "Low Hole": "🏆",
        ]
        let topTasks = game.rules.tasks.compactMap { task -> (String, Int)? in
            let total = game.players.reduce(0) { $0 + (playerTaskCounts[$1]?[task.name] ?? 0) }
            return total > 0 ? (task.name, total) : nil
        }.sorted { $0.1 > $1.1 }.prefix(3)
        if !topTasks.isEmpty {
            let parts = topTasks.map { name, _ in "\(name) \(emojiMap[name] ?? "•")" }
            t += "Top Tasks: \(parts.joined(separator: " · "))\n"
        }

        t += "\nPayouts:\n"
        if anyCapped { t += "(Cap of $\(game.rules.maxOwedAmount) applied)\n" }
        for group in cappedDebtsByPayer {
            for debt in group.owes {
                t += "\(group.player.name) → \(debt.to.name): $\(debt.amount)"
                if debt.isCapped { t += " (was $\(debt.originalAmount))" }
                t += "\n"
            }
        }
        return t
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.4, blue: 0.2), Color(red: 0.05, green: 0.25, blue: 0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.8), radius: 20, x: 0, y: 0)
                        .scaleEffect(trophyScale)
                        .opacity(trophyOpacity)
                        .padding(.top, 20)
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.45).delay(0.15)) {
                                trophyScale = 1.0
                                trophyOpacity = 1.0
                            }
                        }

                    Text("Round Complete!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if isTeamMode {
                        if let wt = championTeam {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill").foregroundStyle(.yellow)
                                Text("Team \(wt) Wins!")
                                    .font(.title2.bold())
                                    .foregroundStyle(wt == "A" ? .cyan : .orange)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background((wt == "A" ? Color.cyan : Color.orange).opacity(0.2))
                            .cornerRadius(12)
                        } else {
                            Text("Teams Tied!")
                                .font(.title3).foregroundStyle(.white.opacity(0.8))
                        }
                    } else {
                        if let champ = champion {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill").foregroundStyle(.yellow)
                                Text("\(champ.name) Wins!")
                                    .font(.title2.bold()).foregroundStyle(.white)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Color.green.opacity(0.3))
                            .cornerRadius(12)
                        } else {
                            Text("Everyone Tied!")
                                .font(.title3).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.bottom, 24)

                // Tab Selector
                HStack(spacing: 12) {
                    tabButton(title: "Stats",   icon: "chart.bar.fill",        index: 0)
                    tabButton(title: "Payouts", icon: "dollarsign.circle.fill", index: 1)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        if selectedTab == 0 {
                            if isTeamMode { teamStatsView() } else { statsView() }
                        } else {
                            payoutsView()
                        }

                        // Action Buttons
                        VStack(spacing: 12) {
                            if isHistoryView {
                                Button { manager.startNewGame() } label: {
                                    Label("Return to Home", systemImage: "house.fill")
                                        .font(.headline.bold()).foregroundStyle(.black)
                                        .frame(maxWidth: .infinity).padding()
                                        .background(Color.green).cornerRadius(14)
                                }
                            } else {
                                Button {
                                    if MFMessageComposeViewController.canSendText() {
                                        showShareMessage = true
                                    } else {
                                        showMessagingUnavailableAlert = true
                                    }
                                } label: {
                                    Label("Share Results", systemImage: "message.fill")
                                        .font(.headline).foregroundStyle(.white)
                                        .frame(maxWidth: .infinity).padding()
                                        .background(LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .leading, endPoint: .trailing))
                                        .cornerRadius(14)
                                }

                                HStack(spacing: 12) {
                                    // setHole is host-only in GameManager — hide this for guests
                                    // rather than show a button that silently does nothing.
                                    if manager.isHost {
                                        Button("Back to Hole 18") {
                                            manager.showGameOver = false
                                            manager.setHole(18)
                                        }
                                        .font(.subheadline.bold()).foregroundStyle(.white)
                                        .frame(maxWidth: .infinity).padding()
                                        .background(Color.white.opacity(0.2)).cornerRadius(12)
                                    }

                                    Button("New Round") { manager.startNewGame() }
                                        .font(.headline.bold()).foregroundStyle(.black)
                                        .frame(maxWidth: .infinity).padding()
                                        .background(Color.green).cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }

            // Confetti rains over everything, fades after 3 s
            ConfettiView()
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareMessage) {
            GameResultsMessageComposer(
                recipients: game.players
                    .filter { $0.id != currentUser.id }
                    .map { $0.phoneNumber }
                    .filter { !$0.isEmpty },
                messageBody: shareText
            )
        }
        .alert("Messaging Unavailable", isPresented: $showMessagingUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("iMessage is not available on this device. Please test on a physical device with Messages configured.")
        }
    }

    // MARK: - Tab Button

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button { withAnimation(.spring(response: 0.3)) { selectedTab = index } } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption.bold())
            }
            .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.6))
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(selectedTab == index ? Color.white.opacity(0.2) : Color.clear)
            .cornerRadius(12)
        }
    }

    // MARK: - Team Stats View (unchanged)

    private func teamStatsView() -> some View {
        VStack(spacing: 12) {
            ForEach(teamResults, id: \.team) { teamData in teamStatsCard(teamData: teamData) }
        }
        .padding(.horizontal, 16)
    }

    private func teamStatsCard(teamData: (team: String, players: [Player], totalDots: Int)) -> some View {
        let teamColor = teamData.team == "A" ? Color.cyan : Color.orange
        let isWinning = teamData.team == winningTeam
        let teamName = teamData.team == "A" ? game.rules.teamNameA : game.rules.teamNameB
        let teamLowWins = game.teamLowWinner.values.filter { $0 == teamData.team }.count
        let teamLowPts = teamLowWins * game.rules.teamLowPoints
        return VStack(spacing: 0) {
            HStack {
                Circle().fill(teamColor.opacity(0.3)).frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: isWinning ? "crown.fill" : "flag.fill")
                            .font(.title3.bold()).foregroundStyle(teamColor)
                    }
                Text(teamName).font(.title2.bold()).foregroundStyle(teamColor)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(teamData.totalDots)")
                        .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.green)
                    Text("dots").font(.caption).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(16).background(teamColor.opacity(0.1))
            if teamLowWins > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "medal.fill").font(.caption).foregroundStyle(teamColor)
                    Text("Team Low: \(teamLowWins) hole\(teamLowWins == 1 ? "" : "s") · \(teamLowPts) dot\(teamLowPts == 1 ? "" : "s")")
                        .font(.caption.bold()).foregroundStyle(teamColor)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(teamColor.opacity(0.08))
            }
            Divider().background(Color.white.opacity(0.2))
            ForEach(teamData.players) { player in
                teamPlayerRow(player: player, isLast: player.id == teamData.players.last?.id)
            }
        }
        .background(Color.white.opacity(0.08)).cornerRadius(16)
    }

    private func teamPlayerRow(player: Player, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle().fill(Color.white.opacity(0.1)).frame(width: 32, height: 32)
                    .overlay { Text(String(player.name.prefix(1))).font(.caption.bold()).foregroundStyle(.white) }
                Text(player.name).font(.body).foregroundStyle(.white)
                Spacer()
                Text("\(totalDots[player] ?? 0)").font(.headline.bold()).foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            if !isLast { Divider().background(Color.white.opacity(0.1)) }
        }
    }

    // MARK: - Stats View

    private func statsView() -> some View {
        VStack(spacing: 12) {
            let sorted = game.players.sorted { (totalDots[$0] ?? 0) > (totalDots[$1] ?? 0) }

            ForEach(sorted) { player in
                let isChamp   = champion?.id == player.id
                let dots      = totalDots[player] ?? 0
                let owesTotal = totalOwedByPlayer[player.id] ?? 0
                let pct       = CGFloat(dots) / CGFloat(maxDots)

                VStack(spacing: 0) {
                    // Player Header
                    HStack(spacing: 14) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(isChamp
                                    ? LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: isChamp ? 56 : 40, height: isChamp ? 56 : 40)
                            Text(String(player.name.prefix(1)))
                                .font(isChamp ? .title.bold() : .headline.bold())
                                .foregroundStyle(.white)
                            if isChamp {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.yellow)
                                    .offset(x: 18, y: -18)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.name)
                                .font(isChamp ? .title2.bold() : .title3.bold())
                                .foregroundStyle(.white)
                            if !isChamp && owesTotal > 0 {
                                Text("Owes $\(owesTotal)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.red.opacity(0.85))
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(dots)")
                                .font(.system(size: isChamp ? 32 : 26, weight: .bold, design: .rounded))
                                .foregroundStyle(isChamp ? .yellow : .green)
                            Text("dots").font(.caption).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(isChamp ? 18 : 14)
                    .background(isChamp
                        ? Color(red: 0.35, green: 0.28, blue: 0.0).opacity(0.35)
                        : Color.white.opacity(0.1))

                    // Dot bar
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isChamp
                                    ? LinearGradient(colors: [.yellow, .green], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.green, .green.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: proxy.size.width * max(0, pct))
                        }
                    }
                    .frame(height: 6)

                    Divider().background(Color.white.opacity(0.2))

                    // Task Breakdown
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(game.rules.tasks.filter { (playerTaskCounts[player]?[$0.name] ?? 0) > 0 }) { task in
                            HStack(spacing: 8) {
                                Image(systemName: taskIcon(for: task.name))
                                    .font(.caption)
                                    .foregroundStyle(task.isNegative ? .red : .green)
                                Text(task.name)
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                                Spacer()
                                if task.name == "Greenie" || task.name == "Low Hole" {
                                    Text("\(playerTaskCounts[player]?[task.name] ?? 0) pts")
                                        .font(.subheadline.bold()).foregroundStyle(.green)
                                } else {
                                    Text("\(playerTaskCounts[player]?[task.name] ?? 0)")
                                        .font(.subheadline.bold()).foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)
                .overlay(
                    isChamp
                    ? RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient(colors: [.yellow, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    : nil
                )
            }

            // Highlights
            highlightsSection()
        }
        .padding(.horizontal, 16)
    }

    private func highlightsSection() -> some View {
        let best  = bestHoleHighlight
        let funs  = funLoserLabels
        guard best != nil || !funs.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text("HIGHLIGHTS")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.5)

                if let b = best, !b.tasks.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Best Hole").font(.caption.bold()).foregroundStyle(.yellow)
                            Text("Hole \(b.hole) · \(b.playerName) · \(b.tasks)")
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(10)
                }

                ForEach(funs, id: \.playerName) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "flame.fill").foregroundStyle(.orange).font(.caption)
                        Text(item.label).font(.caption).foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(10)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
        )
    }

    // MARK: - Payouts View

    private var currentUser: Player {
        game.players.first ?? Player(name: "Unknown", phoneNumber: "")
    }

    private func payoutsView() -> some View {
        VStack(spacing: 16) {
            if anyCapped {
                HStack(spacing: 8) {
                    Image(systemName: "shield.fill").foregroundStyle(.yellow)
                    Text("Maximum owed cap of $\(game.rules.maxOwedAmount) applied")
                        .font(.subheadline.bold()).foregroundStyle(.yellow)
                    Spacer()
                }
                .padding(12)
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }

            if cappedDebtsByPayer.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "equal.circle.fill").font(.system(size: 60)).foregroundStyle(.green)
                    Text("Everyone Even!").font(.title2.bold()).foregroundStyle(.white)
                    Text("No money changes hands").font(.subheadline).foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity).padding(40)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20).padding(.horizontal, 16)
            } else {
                ForEach(cappedDebtsByPayer, id: \.player.id) { group in
                    ForEach(group.owes, id: \.to.id) { debt in
                        VStack(spacing: 16) {
                            // Payer avatar
                            ZStack {
                                Circle().fill(Color.red.opacity(0.25)).frame(width: 64, height: 64)
                                Text(String(group.player.name.prefix(1)))
                                    .font(.title.bold()).foregroundStyle(.white)
                            }

                            // Large dollar amount
                            VStack(spacing: 4) {
                                if debt.isCapped {
                                    HStack(spacing: 8) {
                                        Text("$\(debt.originalAmount)")
                                            .font(.title3).foregroundStyle(.red)
                                            .strikethrough(true, color: .red)
                                        Text("$\(debt.amount)")
                                            .font(.system(size: 52, weight: .black, design: .rounded))
                                            .foregroundStyle(.green).monospacedDigit()
                                    }
                                    Text("Cap applied").font(.caption2).foregroundStyle(.gray)
                                } else {
                                    Text("$\(debt.amount)")
                                        .font(.system(size: 60, weight: .black, design: .rounded))
                                        .foregroundStyle(.green).monospacedDigit()
                                }
                            }

                            // "Name owes Winner"
                            VStack(spacing: 4) {
                                Text("\(group.player.name)  →  \(debt.to.name)")
                                    .font(.headline.bold()).foregroundStyle(.white)
                                Text("owes")
                                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                                    .offset(y: -20)  // visually tuck under the arrow line
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28).padding(.horizontal, 20)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green.opacity(0.25), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Task Icons

    private func taskIcon(for taskName: String) -> String {
        switch taskName {
        case "Fairway":   return "figure.golf"
        case "Birdie":    return "bird"
        case "Poley":     return "flag.fill"
        case "Greenie":   return "leaf.fill"
        case "Low Hole":  return "trophy.fill"
        case "Sandy":     return "beach.umbrella"
        case "Sand":      return "exclamationmark.triangle.fill"
        case "OB":        return "xmark.circle.fill"
        case "3-Putt":    return "minus.circle.fill"
        case "4-Putt":    return "minus.circle.fill"
        case "Lady's Tee": return "figure.dress.line.vertical.figure"
        default:          return "circle"
        }
    }
}

// MARK: - Confetti

private struct ConfettiView: View {
    private struct Piece {
        let x: CGFloat        // 0..1 normalized screen width
        let speed: CGFloat    // screen heights traveled over 3 s
        let size: CGFloat
        let rotation: CGFloat // initial angle (radians)
        let spin: CGFloat     // radians per second
        let color: Color
        let isRect: Bool      // false = circle/ellipse
    }

    private let pieces: [Piece]
    private let duration: Double = 3.0
    @State private var startDate: Date = .now
    @State private var visible = true

    init() {
        var rng = SystemRandomNumberGenerator()
        let palette: [Color] = [
            Color(red: 0.2, green: 0.85, blue: 0.3),
            .yellow,
            Color(red: 1.0, green: 0.82, blue: 0.0),
            .white,
            Color(red: 0.5, green: 0.95, blue: 0.5),
        ]
        pieces = (0..<80).map { _ in
            Piece(
                x:        CGFloat.random(in: 0.04...0.96, using: &rng),
                speed:    CGFloat.random(in: 0.9...1.8,   using: &rng),
                size:     CGFloat.random(in: 6...14,      using: &rng),
                rotation: CGFloat.random(in: 0...(2 * .pi), using: &rng),
                spin:     CGFloat.random(in: 2...8,       using: &rng),
                color:    palette[Int.random(in: 0..<palette.count, using: &rng)],
                isRect:   Bool.random(using: &rng)
            )
        }
    }

    var body: some View {
        if visible {
            TimelineView(.animation) { ctx in
                Canvas { gc, size in
                    let elapsed = ctx.date.timeIntervalSince(startDate)
                    let t = CGFloat(min(elapsed / duration, 1.0))
                    let fadeStart = duration * 0.65
                    let alpha = elapsed > fadeStart ? max(0, 1.0 - (elapsed - fadeStart) / (duration - fadeStart)) : 1.0

                    for p in pieces {
                        let x = p.x * size.width
                        let y = -p.size * 2 + t * p.speed * size.height
                        guard y < size.height + p.size else { continue }

                        let angle = p.rotation + CGFloat(elapsed) * p.spin
                        let tf = CGAffineTransform(translationX: x, y: y).rotated(by: angle)

                        let w = p.size
                        let h = p.isRect ? p.size * 0.45 : p.size
                        let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
                        let path = (p.isRect ? Path(rect) : Path(ellipseIn: rect)).applying(tf)
                        gc.fill(path, with: .color(p.color.opacity(alpha)))
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                startDate = .now
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.2) {
                    visible = false
                }
            }
        }
    }
}

// MARK: - Game Results Message Composer

struct GameResultsMessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let messageBody: String
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = messageBody
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            dismiss()
        }
    }
}

#Preview {
    GameOverView(game: GameState(gameID: "TEST", players: [], rules: GameRules()), stake: 1)
        .environment(GameManager())
}
