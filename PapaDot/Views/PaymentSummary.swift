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
    let originalAmount: Double
    let isCapped: Bool
    var status: PaymentStatus
    var paidDate: Date?

    init(fromPlayer: Player, toPlayer: Player, amount: Double,
         originalAmount: Double? = nil, isCapped: Bool = false,
         status: PaymentStatus = .pending) {
        self.id = UUID()
        self.fromPlayer = fromPlayer
        self.toPlayer = toPlayer
        self.amount = amount
        self.originalAmount = originalAmount ?? amount
        self.isCapped = isCapped
        self.status = status
        self.paidDate = nil
    }

    var description: String {
        "$\(String(format: "%.2f", amount)) from \(fromPlayer.name) to \(toPlayer.name)"
    }

    var formattedAmount: String {
        "$\(String(format: "%.2f", amount))"
    }

    var formattedOriginalAmount: String {
        "$\(Int(originalAmount))"
    }

    var formattedCappedAmount: String {
        "$\(Int(amount))"
    }

    var statusEmoji: String {
        switch status {
        case .pending: return "⏳"
        case .paid: return "✅"
        case .confirmed: return "✅"
        }
    }
}

// Custom Codable so fields added after v1 don't crash old stored records.
extension PaymentSummary {
    private enum CodingKeys: String, CodingKey {
        case id, fromPlayer, toPlayer, amount, originalAmount, isCapped, status, paidDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,          forKey: .id)
        fromPlayer     = try c.decode(Player.self,        forKey: .fromPlayer)
        toPlayer       = try c.decode(Player.self,        forKey: .toPlayer)
        amount         = try c.decode(Double.self,        forKey: .amount)
        status         = try c.decode(PaymentStatus.self, forKey: .status)
        paidDate       = try c.decodeIfPresent(Date.self,   forKey: .paidDate)
        originalAmount = try c.decodeIfPresent(Double.self, forKey: .originalAmount) ?? amount
        isCapped       = try c.decodeIfPresent(Bool.self,   forKey: .isCapped)       ?? false
    }
}

extension GameState {
    /// Calculate pairwise payments with optional max-owed cap applied.
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

        return applyMaxOwedCap(payments: payments, rules: rules)
    }
}
