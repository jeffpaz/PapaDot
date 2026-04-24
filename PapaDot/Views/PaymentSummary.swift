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
    
    // Venmo deep link
    func venmoDeepLink(note: String) -> URL? {
        let amount = String(format: "%.2f", self.amount)
        let venmoNote = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try phone number first, fall back to username if available
        var recipient = ""
        if !toPlayer.phoneNumber.isEmpty {
            // Clean phone number (remove non-digits)
            let cleaned = toPlayer.phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            recipient = cleaned
        } else {
            // Use name as fallback (user will need to search)
            recipient = toPlayer.name.replacingOccurrences(of: " ", with: "-")
        }
        
        let urlString = "venmo://paycharge?txn=pay&recipients=\(recipient)&amount=\(amount)&note=\(venmoNote)"
        return URL(string: urlString)
    }
    
    func venmoWebLink(note: String) -> URL? {
        let amount = String(format: "%.2f", self.amount)
        let venmoNote = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        var recipient = ""
        if !toPlayer.phoneNumber.isEmpty {
            let cleaned = toPlayer.phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            recipient = cleaned
        } else {
            recipient = toPlayer.name.replacingOccurrences(of: " ", with: "-")
        }
        
        let urlString = "https://venmo.com/?txn=pay&recipients=\(recipient)&amount=\(amount)&note=\(venmoNote)"
        return URL(string: urlString)
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
