//  Views/PaymentView.swift
import SwiftUI
import PassKit

struct PaymentView: View {
    let game: GameState
    @Environment(\.dismiss) var dismiss
    
    private var payments: [PaymentSummary] {
        game.calculatePayments()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.4, blue: 0.2),
                        Color(red: 0.05, green: 0.25, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)
                                .padding(.top, 20)
                            
                            Text("Settle Up")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            if payments.isEmpty {
                                Text("Everyone's even!")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                            } else {
                                Text("\(payments.count) payment\(payments.count > 1 ? "s" : "") needed")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .padding(.bottom, 10)
                        
                        if payments.isEmpty {
                            // Everyone even
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.green)
                                
                                Text("No payments needed")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                
                                Text("Everyone scored the same!")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(40)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        } else {
                            // Payment list
                            VStack(spacing: 16) {
                                ForEach(payments) { payment in
                                    PaymentCard(payment: payment)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct PaymentCard: View {
    let payment: PaymentSummary
    
    var body: some View {
        VStack(spacing: 16) {
            // Payment Flow
            HStack(spacing: 16) {
                // From Player
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Text(String(payment.fromPlayer.name.prefix(1)))
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                    
                    Text(payment.fromPlayer.name)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                
                // Arrow with amount
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text(payment.formattedAmount)
                        .font(.title.bold())
                        .foregroundStyle(.green)
                }
                
                // To Player
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Text(String(payment.toPlayer.name.prefix(1)))
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                    
                    Text(payment.toPlayer.name)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 16)
            
            // Payment Method Buttons
            VStack(spacing: 12) {
                Text("Pay with:")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                
                HStack(spacing: 12) {
                    // Venmo Button
                    PaymentMethodButton(
                        icon: "v.circle.fill",
                        label: "Venmo",
                        color: .blue
                    ) {
                        openVenmo(payment)
                    }
                    
                    // Cash App Button
                    PaymentMethodButton(
                        icon: "dollarsign.circle.fill",
                        label: "Cash App",
                        color: .green
                    ) {
                        openCashApp(payment)
                    }
                    
                    // Apple Pay Button (if available)
                    if PKPaymentAuthorizationController.canMakePayments() {
                        PaymentMethodButton(
                            icon: "apple.logo",
                            label: "Apple Pay",
                            color: .black
                        ) {
                            // Apple Pay integration
                            print("Apple Pay tapped - implement PKPaymentRequest")
                        }
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
    
    private func openVenmo(_ payment: PaymentSummary) {
        let amount = String(format: "%.2f", payment.amount)
        let note = "Golf dots - PapaDot"
        
        // Try to extract username/phone from player
        // Venmo supports phone numbers without +1
        let recipient = payment.toPlayer.phoneNumber
            .replacingOccurrences(of: "+1", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        // Venmo URL scheme
        let urlString = "venmo://paycharge?txn=pay&recipients=\(recipient)&amount=\(amount)&note=\(note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url) { success in
                if !success {
                    // Fallback to Venmo website
                    if let webURL = URL(string: "https://venmo.com/") {
                        UIApplication.shared.open(webURL)
                    }
                }
            }
        }
    }
    
    private func openCashApp(_ payment: PaymentSummary) {
        let amount = String(format: "%.2f", payment.amount)
        let note = "Golf dots"
        
        // Cash App URL - can use $cashtag or phone number
        // Try to create a cashtag from name (simplified)
        let cashtag = payment.toPlayer.name.replacingOccurrences(of: " ", with: "")
        
        let urlString = "https://cash.app/$\(cashtag)?amount=\(amount)&note=\(note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

struct PaymentMethodButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color)
            .cornerRadius(12)
        }
    }
}

#Preview {
    PaymentView(game: GameState(
        gameID: "TEST",
        players: [
            Player(name: "Jeff", phoneNumber: "+15551234567"),
            Player(name: "Mike", phoneNumber: "+15559876543")
        ],
        rules: GameRules(stakePerPoint: 1)
    ))
}
