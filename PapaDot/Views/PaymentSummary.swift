//  Models/PaymentSummary.swift
import Foundation

enum PaymentStatus: String, Codable {
    case pending = "pending"
    case paid = "paid"
    case confirmed = "confirmed"
}

struct PaymentSummary: Identifiable, Codable {
    let id: UUID
    let fromPlayer: Player
    let toPlayer: Player
    let amount: Double
    var status: PaymentStatus
    var paidDate: Date?
    
    init(fromPlayer: Player, toPlayer: Player, amount: Double, status: PaymentStatus = .pending) {
        self.id = UUID()
        self.fromPlayer = fromPlayer
        self.toPlayer = toPlayer
        self.amount = amount
        self.status = status
        self.paidDate = nil
    }
    
    var description: String {
        "$\(String(format: "%.2f", amount)) from \(fromPlayer.name) to \(toPlayer.name)"
    }
    
    var formattedAmount: String {
        "$\(String(format: "%.2f", amount))"
    }
    
    var statusEmoji: String {
        switch status {
        case .pending: return "⏳"
        case .paid: return "✅"
        case .confirmed: return "✅"
        }
    }
    
}

extension GameState {
    /// Calculate pairwise payments: each player pays each other player based on their dot difference.
    /// Matches the standard golf betting format used in GameOverView's debtsByPayer.
    func calculatePayments() -> [PaymentSummary] {
        let totalDots = calculateTotalDots(game: self)
        let stake = rules.stakePerPoint
        var payments: [PaymentSummary] = []

        for player in players {
            let myDots = totalDots[player] ?? 0
            for other in players where other.id != player.id {
                let diff = (totalDots[other] ?? 0) - myDots
                if diff > 0 {
                    payments.append(PaymentSummary(
                        fromPlayer: player,
                        toPlayer: other,
                        amount: Double(diff * stake)
                    ))
                }
            }
        }

        return payments
    }
}
