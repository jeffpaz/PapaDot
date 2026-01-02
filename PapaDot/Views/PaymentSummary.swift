//  Models/PaymentSummary.swift
import Foundation

struct PaymentSummary: Identifiable {
    let id = UUID()
    let fromPlayer: Player
    let toPlayer: Player
    let amount: Double
    
    var description: String {
        "$\(String(format: "%.2f", amount)) from \(fromPlayer.name) to \(toPlayer.name)"
    }
    
    var formattedAmount: String {
        "$\(String(format: "%.2f", amount))"
    }
}

extension GameState {
    /// Calculate optimized payments (fewest transactions)
    func calculatePayments() -> [PaymentSummary] {
        // Calculate total dots for each player using existing helper
        let totalDots = calculateTotalDots(game: self)
        let wager = Double(rules.stakePerPoint)
        
        // Calculate average dots
        let totalDotsSum = totalDots.values.reduce(0, +)
        let averageDots = Double(totalDotsSum) / Double(players.count)
        
        // Calculate net amount for each player (positive = receives, negative = pays)
        let netAmounts: [(player: Player, amount: Double)] = players.map { player in
            let playerDots = totalDots[player] ?? 0
            let net = (Double(playerDots) - averageDots) * wager
            return (player, net)
        }
        
        // Separate into payers (negative) and receivers (positive)
        var payers = netAmounts.filter { $0.amount < -0.01 }.map { (player: $0.player, amount: abs($0.amount)) }
        var receivers = netAmounts.filter { $0.amount > 0.01 }
        
        // Generate optimized payment list
        var payments: [PaymentSummary] = []
        
        var payerIndex = 0
        var receiverIndex = 0
        
        while payerIndex < payers.count && receiverIndex < receivers.count {
            let payer = payers[payerIndex]
            let receiver = receivers[receiverIndex]
            
            // Amount to transfer is the minimum of what's owed and what's due
            let transferAmount = min(payer.amount, receiver.amount)
            
            // Create payment
            payments.append(PaymentSummary(
                fromPlayer: payer.player,
                toPlayer: receiver.player,
                amount: transferAmount
            ))
            
            // Update remaining amounts
            payers[payerIndex].amount -= transferAmount
            receivers[receiverIndex].amount -= transferAmount
            
            // Move to next payer/receiver if current one is settled
            if payers[payerIndex].amount < 0.01 {
                payerIndex += 1
            }
            if receivers[receiverIndex].amount < 0.01 {
                receiverIndex += 1
            }
        }
        
        return payments
    }
}
