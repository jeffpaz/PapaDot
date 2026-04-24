//  Views/GameOverView.swift
import SwiftUI
import PassKit

struct GameOverView: View {
    let game: GameState
    let stake: Int
    @Environment(GameManager.self) var manager
    @State private var selectedTab = 0
    @State private var applePayDelegate: ApplePayDelegate?

    private var totalDots: [Player: Int] { calculateTotalDots(game: game) }

    private var debtsByPayer: [(player: Player, owes: [(to: Player, amount: Int)])] {
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
        let max = netSummary.first?.net ?? 0
        let winners = netSummary.filter { $0.net == max }
        return winners.count == game.players.count ? nil : winners.first?.player
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
                            statsView()
                        } else if selectedTab == 1 {
                            payoutsView()
                        } else {
                            summaryView()
                        }

                        // Action Buttons
                        VStack(spacing: 12) {
                            Button { openGroupMessage() } label: {
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

                                // For Greenie, show dot value (e.g. "4 pts") not just count
                                if task.name == "Greenie" {
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

                            // Apple Pay
                            Button {
                                requestApplePay(to: debt.to.name, amount: debt.amount, isRequest: false)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "apple.logo")
                                    Text("Pay with Apple Pay").font(.subheadline.bold())
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.black).cornerRadius(10)
                            }
                            .padding(.horizontal, 16).padding(.bottom, 8)
                        }
                    }
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                }
                .padding(.horizontal, 16)
            }
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

    // MARK: - Apple Pay

    private func requestApplePay(to recipient: String, amount: Int, isRequest: Bool) {
        guard PKPaymentAuthorizationController.canMakePayments() else { return }

        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.jeffpaz.PapaDot"
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = .threeDSecure
        request.countryCode = "US"
        request.currencyCode = "USD"

        let label = isRequest ? "Request from \(recipient)" : "Payment to \(recipient) – PapaDot"
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(value: amount))
        ]

        let delegate = ApplePayDelegate()
        applePayDelegate = delegate
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = delegate
        controller.present()
    }

    // MARK: - Share via Share Sheet

    private func openGroupMessage() {
        // Use UIActivityViewController — handles text natively with no URL encoding issues.
        // This lets the user choose Messages, Mail, AirDrop, copy, etc.
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        // Present from the root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            // On iPad, set popover source to avoid crash
            activityVC.popoverPresentationController?.sourceView = root.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0
            )
            root.present(activityVC, animated: true)
        }
    }
}

#Preview {
    GameOverView(game: GameState(gameID: "TEST", players: [], rules: GameRules()), stake: 1)
        .environment(GameManager())
}
