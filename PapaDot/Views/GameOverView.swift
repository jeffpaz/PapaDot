//  Views/GameOverView.swift
import SwiftUI
import PassKit

struct GameOverView: View {
    let game: GameState
    let stake: Int
    @Environment(GameManager.self) var manager
    @State private var showSummary = false
    
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
    
    private var myPlayer: Player? {
        game.players.first
    }
    
    private var myNet: Int {
        guard let me = myPlayer else { return 0 }
        return netSummary.first(where: { $0.player.id == me.id })?.net ?? 0
    }
    
    private var shareText: String {
        var t = "Papa Dot – Game Over!\n\n"
        if let champ = champion {
            t += "\(champ.name) WINS!\n\n"
        } else {
            t += "NO ONE WINS!\n\n"
        }
        for group in debtsByPayer {
            for debt in group.owes {
                t += "\(group.player.name) → \(debt.to.name): $\(debt.amount)\n"
            }
        }
        return t
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 8) {
                            Text("GAME OVER")
                                .font(.system(size: 36, weight: .black))
                            if let champ = champion {
                                Text("\(champ.name) WINS!")
                                    .font(.title.bold())
                                    .foregroundStyle(.green)
                            } else {
                                Text("NO ONE WINS!")
                                    .font(.title.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        HStack(spacing: 20) {
                            Button("Who Owes Who") { withAnimation { showSummary = false } }
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(showSummary ? Color.secondary.opacity(0.3) : Color.accentColor)
                                .foregroundColor(showSummary ? .primary : .white)
                                .cornerRadius(16)
                            
                            Button("Summary") { withAnimation { showSummary = true } }
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(showSummary ? Color.accentColor : Color.secondary.opacity(0.3))
                                .foregroundColor(showSummary ? .white : .primary)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 40)
                        
                        if !showSummary {
                            if debtsByPayer.isEmpty {
                                Text("Everyone even!")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(debtsByPayer, id: \.player.id) { group in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("\(group.player.name) owes")
                                                .font(.headline)
                                                .foregroundColor(.red)
                                            
                                            ForEach(group.owes, id: \.to.id) { debt in
                                                HStack {
                                                    Text("→ \(debt.to.name)")
                                                        .font(.body)
                                                    Spacer()
                                                    Text("$\(debt.amount)")
                                                        .font(.title3.bold())
                                                        .monospacedDigit()
                                                    
                                                    // Apple Pay
                                                    Button {
                                                        let isOwed = myNet > 0 && debt.to.id == myPlayer?.id
                                                        requestApplePay(to: debt.to.name, amount: debt.amount, isRequest: isOwed)
                                                    } label: {
                                                        Image(systemName: "applelogo")
                                                            .font(.title3)
                                                            .foregroundStyle(.black)
                                                            .padding(8)
                                                            .background(Color.white)
                                                            .clipShape(Circle())
                                                            .overlay(Circle().stroke(Color.black, lineWidth: 1))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(16)
                                    }
                                }
                                .padding(.horizontal, 32)
                            }
                        } else {
                            VStack(spacing: 12) {
                                ForEach(netSummary, id: \.player.id) { item in
                                    HStack {
                                        Text(item.player.name)
                                            .font(.title3.bold())
                                        Spacer()
                                        Text(item.net >= 0 ? "+$\(item.net)" : "-$\(abs(item.net))")
                                            .font(.title2.bold())
                                            .foregroundColor(item.net >= 0 ? .green : .red)
                                            .monospacedDigit()
                                    }
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                        
                        VStack(spacing: 16) {
                            ShareLink(item: shareText) {
                                Label("Share Results", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                            
                            Button {
                                openGroupMessage()
                            } label: {
                                Label("Message Group", systemImage: "message.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                            
                            HStack(spacing: 20) {
                                Button("Back to Hole 18") {
                                    manager.showGameOver = false
                                    manager.setHole(18)
                                }
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                
                                Button("New Round") {
                                    manager.startNewGame()
                                }
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.green)
                                .foregroundColor(.black)
                                .cornerRadius(14)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Apple Pay
    private func requestApplePay(to recipient: String, amount: Int, isRequest: Bool) {
        guard PKPaymentAuthorizationController.canMakePayments() else { return }
        
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.papadot"
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = .capability3DS
        request.countryCode = "US"
        request.currencyCode = "USD"
        
        let label = isRequest ? "Papa Dot – Request from \(recipient)" : "Papa Dot – Payment to \(recipient)"
        let item = PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(value: amount))
        request.paymentSummaryItems = [item]
        
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = ApplePayDelegate()
        controller.present(completion: nil)
    }
    
    class ApplePayDelegate: NSObject, PKPaymentAuthorizationControllerDelegate {
        func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
            controller.dismiss(completion: nil)
        }
        
        func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController,
                                            didAuthorizePayment payment: PKPayment,
                                            handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
            completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        }
    }
    
    // MARK: - Group Message
    private func openGroupMessage() {
        let message = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "sms:?&body=\(message)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    GameOverView(game: GameState(gameID: "TEST", players: [], rules: GameRules()), stake: 1)
        .environment(GameManager())
}
