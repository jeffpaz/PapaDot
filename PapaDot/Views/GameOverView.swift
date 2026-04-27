//  Views/GameOverView.swift
import SwiftUI
import MessageUI

struct GameOverView: View {
    let game: GameState
    let stake: Int
    @Environment(GameManager.self) var manager
    @State private var selectedTab = 0
    @State private var showShareMessage = false
    @State private var showMessagingUnavailableAlert = false

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

        if teamADots == teamBDots {
            return [] // Tie, no payments
        }

        let losingTeam = teamADots > teamBDots ? teamResults.first(where: { $0.team == "B" })?.players ?? [] : teamResults.first(where: { $0.team == "A" })?.players ?? []
        let winningTeam = teamADots > teamBDots ? teamResults.first(where: { $0.team == "A" })?.players ?? [] : teamResults.first(where: { $0.team == "B" })?.players ?? []

        var result: [(player: Player, owes: [(to: Player, amount: Int)])] = []
        for loser in losingTeam {
            var owes: [(to: Player, amount: Int)] = []
            for winner in winningTeam {
                owes.append((to: winner, amount: amountPerPerson))
            }
            result.append((player: loser, owes: owes))
        }

        return result
    }

    private var debtsByPayer: [(player: Player, owes: [(to: Player, amount: Int)])] {
        if isTeamMode {
            return teamDebts
        }

        var result: [(player: Player, owes: [(to: Player, amount: Int)])] = []
        for player in game.players.sorted(by: { $0.name < $1.name }) {
            var owes: [(to: Player, amount: Int)] = []
            let myDots = totalDots[player]!
            for other in game.players where other.id != player.id {
                let diff = totalDots[other]! - myDots
                if diff > 0 {
                    owes.append((to: other, amount: diff * stake))
                }
            }
            if !owes.isEmpty {
                result.append((player: player, owes: owes.sorted { $0.to.name < $1.to.name }))
            }
        }
        return result
    }

    private var netSummary: [(player: Player, net: Int)] {
        var net = Dictionary(uniqueKeysWithValues: game.players.map { ($0, 0) })
        for group in debtsByPayer {
            for debt in group.owes {
                net[group.player]! -= debt.amount
                net[debt.to]! += debt.amount
            }
        }
        return game.players.map { ($0, net[$0]!) }.sorted { $0.1 > $1.1 }
    }

    private var champion: Player? {
        if isTeamMode {
            return nil // Teams handle separately
        }
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
    // For Greenie, we sum the actual greenieValues per hole (respecting carry-over)
    // rather than counting occurrences (which would always be 1 per hole scored).
    // This matches calculateTotalDots() so the Stats tab stays consistent with dot totals.
    private var playerTaskCounts: [Player: [String: Int]] {
        var counts = [Player: [String: Int]]()
        for player in game.players {
            counts[player] = [:]
            for task in game.rules.tasks {
                counts[player]![task.name] = 0
            }
        }

        for hole in 1...18 {
            guard let holeScores = game.scores[hole] else { continue }
            for (playerName, tasks) in holeScores {
                guard let player = game.players.first(where: { $0.name == playerName }) else { continue }
                for (taskName, scored) in tasks where scored {
                    if taskName == "Greenie" {
                        // Use the stored greenie value for this hole (includes carry-over)
                        let greenieValue = game.greenieValues[hole] ?? 1
                        counts[player]![taskName, default: 0] += greenieValue
                    } else if taskName == "Low Hole" {
                        // Use the stored low hole value for this hole (includes carry-over)
                        let lowHoleValue = game.lowHoleValues[hole] ?? 1
                        counts[player]![taskName, default: 0] += lowHoleValue
                    } else {
                        counts[player]![taskName, default: 0] += 1
                    }
                }
            }
        }
        return counts
    }

    private var shareText: String {
        var t = "Papa Dot – Game Over!\n\n"

        if isTeamMode {
            if let winTeam = championTeam {
                t += "TEAM \(winTeam) WINS!\n\n"
            } else {
                t += "TEAMS TIED!\n\n"
            }
            t += "Team Scores:\n"
            for team in teamResults {
                t += "Team \(team.team): \(team.totalDots) dots\n"
                for player in team.players {
                    t += "  • \(player.name): \(totalDots[player] ?? 0) dots\n"
                }
                t += "\n"
            }
        } else {
            if let champ = champion {
                t += "\(champ.name) WINS!\n\n"
            } else {
                t += "NO ONE WINS!\n\n"
            }
            t += "Stats:\n"
            for player in game.players.sorted(by: { $0.name < $1.name }) {
                t += "\(player.name):\n"
                for task in game.rules.tasks {
                    let count = playerTaskCounts[player]?[task.name] ?? 0
                    if count > 0 { t += "  • \(task.name): \(count)\n" }
                }
                t += "\n"
            }
        }

        t += "\nPayouts:\n"
        for group in debtsByPayer {
            for debt in group.owes {
                t += "\(group.player.name) → \(debt.to.name): $\(debt.amount)\n"
            }
        }
        return t
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.4, blue: 0.2),
                    Color(red: 0.05, green: 0.25, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)
                        .padding(.top, 20)

                    Text("Round Complete!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if isTeamMode {
                        if let winTeam = championTeam {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill").foregroundStyle(.yellow)
                                Text("Team \(winTeam) Wins!")
                                    .font(.title2.bold())
                                    .foregroundStyle(winTeam == "A" ? .cyan : .orange)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background((winTeam == "A" ? Color.cyan : Color.orange).opacity(0.2))
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
                    tabButton(title: "Stats",   icon: "chart.bar.fill",      index: 0)
                    tabButton(title: "Payouts", icon: "dollarsign.circle.fill", index: 1)
                    tabButton(title: "Summary", icon: "list.bullet",          index: 2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        if selectedTab == 0 {
                            if isTeamMode {
                                teamStatsView()
                            } else {
                                statsView()
                            }
                        } else if selectedTab == 1 {
                            payoutsView()
                        } else {
                            summaryView()
                        }

                        // Action Buttons
                        VStack(spacing: 12) {
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
                                Button("Back to Hole 18") {
                                    manager.showGameOver = false
                                    manager.setHole(18)
                                }
                                .font(.subheadline.bold()).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)

                                Button("New Round") { manager.startNewGame() }
                                    .font(.headline.bold()).foregroundStyle(.black)
                                    .frame(maxWidth: .infinity).padding()
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
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
        Button {
            withAnimation(.spring(response: 0.3)) { selectedTab = index }
        } label: {
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

    // MARK: - Team Stats View

    private func teamStatsView() -> some View {
        VStack(spacing: 12) {
            ForEach(teamResults, id: \.team) { teamData in
                teamStatsCard(teamData: teamData)
            }
        }
        .padding(.horizontal, 16)
    }

    private func teamStatsCard(teamData: (team: String, players: [Player], totalDots: Int)) -> some View {
        let teamColor = teamData.team == "A" ? Color.cyan : Color.orange
        let isWinning = teamData.team == winningTeam

        return VStack(spacing: 0) {
            // Team Header
            HStack {
                Circle()
                    .fill(teamColor.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: isWinning ? "crown.fill" : "flag.fill")
                            .font(.title3.bold())
                            .foregroundStyle(teamColor)
                    }
                Text("Team \(teamData.team)")
                    .font(.title2.bold())
                    .foregroundStyle(teamColor)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(teamData.totalDots)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("dots").font(.caption).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(16)
            .background(teamColor.opacity(0.1))

            Divider().background(Color.white.opacity(0.2))

            // Team Players
            ForEach(teamData.players) { player in
                teamPlayerRow(player: player, isLast: player.id == teamData.players.last?.id)
            }
        }
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }

    private func teamPlayerRow(player: Player, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(String(player.name.prefix(1)))
                            .font(.caption.bold()).foregroundStyle(.white)
                    }
                Text(player.name)
                    .font(.body).foregroundStyle(.white)
                Spacer()
                Text("\(totalDots[player] ?? 0)")
                    .font(.headline.bold()).foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if !isLast {
                Divider().background(Color.white.opacity(0.1))
            }
        }
    }

    // MARK: - Stats View

    private func statsView() -> some View {
        VStack(spacing: 12) {
            ForEach(game.players.sorted(by: { totalDots[$0]! > totalDots[$1]! })) { player in
                VStack(spacing: 0) {
                    // Player Header
                    HStack {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Text(String(player.name.prefix(1)))
                                    .font(.title3.bold()).foregroundStyle(.white)
                            }
                        Text(player.name).font(.title3.bold()).foregroundStyle(.white)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(totalDots[player] ?? 0)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                            Text("dots").font(.caption).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.1))

                    Divider().background(Color.white.opacity(0.2))

                    // Task Breakdown
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(game.rules.tasks.filter { task in
                            (playerTaskCounts[player]?[task.name] ?? 0) > 0
                        }) { task in
                            HStack(spacing: 8) {
                                Image(systemName: taskIcon(for: task.name))
                                    .font(.caption)
                                    .foregroundStyle(task.isNegative ? .red : .green)

                                Text(task.name)
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.9))

                                Spacer()

                                // For carry-over tasks, show dot value (e.g. "4 pts") not just count
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
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Payouts View

    private var currentUser: Player {
        game.players.first ?? Player(name: "Unknown", phoneNumber: "")
    }

    private func payoutsView() -> some View {
        VStack(spacing: 12) {
            if debtsByPayer.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "equal.circle.fill")
                        .font(.system(size: 60)).foregroundStyle(.green)
                    Text("Everyone Even!").font(.title2.bold()).foregroundStyle(.white)
                    Text("No money changes hands")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity).padding(40)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20).padding(.horizontal, 16)
            } else {
                ForEach(debtsByPayer, id: \.player.id) { group in
                    VStack(spacing: 12) {
                        HStack {
                            Circle()
                                .fill(Color.red.opacity(0.2)).frame(width: 36, height: 36)
                                .overlay {
                                    Text(String(group.player.name.prefix(1)))
                                        .font(.headline).foregroundStyle(.white)
                                }
                            Text("\(group.player.name) owes")
                                .font(.headline).foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.top, 16)

                        ForEach(group.owes, id: \.to.id) { debt in
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.right").foregroundStyle(.white.opacity(0.4))
                                Text(debt.to.name).font(.body).foregroundStyle(.white)
                                Spacer()
                                Text("$\(debt.amount)")
                                    .font(.title3.bold()).foregroundStyle(.green).monospacedDigit()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)

                            // Only show payment buttons if current user is involved
                            if group.player.id == currentUser.id {
                                // Current user owes money - show Pay buttons
                                HStack(spacing: 8) {
                                    Button {
                                        openVenmo(toPlayer: debt.to, amount: debt.amount)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "v.circle.fill")
                                            Text("Venmo").font(.subheadline.bold())
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(Color.blue).cornerRadius(10)
                                    }

                                    Button {
                                        openCashApp(toPlayer: debt.to, amount: debt.amount)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "dollarsign.circle.fill")
                                            Text("Cash App").font(.subheadline.bold())
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(Color(red: 0, green: 0.7, blue: 0.2)).cornerRadius(10)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.bottom, 8)
                            } else if debt.to.id == currentUser.id {
                                // Current user is owed money - show Request buttons
                                HStack(spacing: 8) {
                                    Button {
                                        openVenmoRequest(fromPlayer: group.player, amount: debt.amount)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "v.circle.fill")
                                            Text("Request Venmo").font(.subheadline.bold())
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(Color.blue.opacity(0.7)).cornerRadius(10)
                                    }

                                    Button {
                                        openCashAppRequest(fromPlayer: group.player, amount: debt.amount)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "dollarsign.circle.fill")
                                            Text("Request Cash App").font(.subheadline.bold())
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(Color(red: 0, green: 0.7, blue: 0.2).opacity(0.7)).cornerRadius(10)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.bottom, 8)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Payment Actions

    private func openVenmo(toPlayer: Player, amount: Int) {
        let note = "Golf dots - PapaDot"
        let phoneNumber = toPlayer.phoneNumber.filter { $0.isNumber }
        let amountStr = String(format: "%.2f", Double(amount))
        let encodedNote = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Try deep link first
        if let deepLink = URL(string: "venmo://paycharge?txn=pay&recipients=\(phoneNumber)&amount=\(amountStr)&note=\(encodedNote)"),
           UIApplication.shared.canOpenURL(deepLink) {
            UIApplication.shared.open(deepLink)
        } else if let webLink = URL(string: "https://venmo.com/?txn=pay&recipients=\(phoneNumber)&amount=\(amountStr)&note=\(encodedNote)") {
            UIApplication.shared.open(webLink)
        }
    }

    private func openVenmoRequest(fromPlayer: Player, amount: Int) {
        let note = "Golf dots - PapaDot"
        let phoneNumber = fromPlayer.phoneNumber.filter { $0.isNumber }
        let amountStr = String(format: "%.2f", Double(amount))
        let encodedNote = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Try deep link first (charge instead of pay for requests)
        if let deepLink = URL(string: "venmo://paycharge?txn=charge&recipients=\(phoneNumber)&amount=\(amountStr)&note=\(encodedNote)"),
           UIApplication.shared.canOpenURL(deepLink) {
            UIApplication.shared.open(deepLink)
        } else if let webLink = URL(string: "https://venmo.com/?txn=charge&recipients=\(phoneNumber)&amount=\(amountStr)&note=\(encodedNote)") {
            UIApplication.shared.open(webLink)
        }
    }

    private func openCashApp(toPlayer: Player, amount: Int) {
        let amountStr = String(format: "%.2f", Double(amount))
        let cashtag = toPlayer.name.components(separatedBy: .whitespaces).joined()

        if let url = URL(string: "https://cash.app/$\(cashtag)?amount=\(amountStr)") {
            UIApplication.shared.open(url)
        }
    }

    private func openCashAppRequest(fromPlayer: Player, amount: Int) {
        let amountStr = String(format: "%.2f", Double(amount))
        let cashtag = fromPlayer.name.components(separatedBy: .whitespaces).joined()

        if let url = URL(string: "https://cash.app/$\(cashtag)?amount=\(amountStr)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Summary View

    private func summaryView() -> some View {
        VStack(spacing: 12) {
            ForEach(netSummary, id: \.player.id) { item in
                HStack {
                    Circle()
                        .fill(item.net >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Text(String(item.player.name.prefix(1)))
                                .font(.headline).foregroundStyle(.white)
                        }
                    Text(item.player.name).font(.title3.bold()).foregroundStyle(.white)
                    Spacer()
                    Text(item.net >= 0 ? "+$\(item.net)" : "-$\(abs(item.net))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(item.net >= 0 ? .green : .red)
                        .monospacedDigit()
                }
                .padding(16)
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Task Icons

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

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            dismiss()
        }
    }
}

#Preview {
    GameOverView(game: GameState(gameID: "TEST", players: [], rules: GameRules()), stake: 1)
        .environment(GameManager())
}
