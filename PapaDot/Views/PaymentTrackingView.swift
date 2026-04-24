//  Views/PaymentTrackingView.swift
import SwiftUI
import PassKit

struct PaymentTrackingView: View {
    @Environment(GameManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    @State private var payments: [PaymentSummary] = []
    @State private var selectedPayment: PaymentSummary?
    @StateObject private var applePayDelegate = ApplePayDelegate()
    
    private var g: GameState { manager.game! }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.2, blue: 0.1),
                        Color(red: 0.02, green: 0.15, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)
                            
                            Text("Payment Summary")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                            
                            Text("\(paidCount) of \(payments.count) paid")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 40)
                        
                        // Payment List
                        VStack(spacing: 12) {
                            ForEach($payments) { $payment in
                                PaymentCardView(
                                    payment: $payment,
                                    onMarkPaid: {
                                        markPaymentPaid(payment)
                                    },
                                    onVenmo: {
                                        openVenmo(payment: payment)
                                    },
                                    onApplePay: {
                                        selectedPayment = payment
                                        applePayDelegate.onPaymentComplete = {
                                            markPaymentPaid(payment)
                                        }
                                        presentApplePay(for: payment)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Summary
                        if payments.allSatisfy({ $0.status != .pending }) {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.green)
                                
                                Text("All Settled Up! 🎉")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            }
                            .padding(.top, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.green)
                }
            }
            .onAppear {
                loadPayments()
            }
        }
    }
    
    private var paidCount: Int {
        payments.filter { $0.status != .pending }.count
    }
    
    private func loadPayments() {
        // If payments already exist in game state, use them
        if !g.payments.isEmpty {
            payments = g.payments
        } else {
            // Calculate new payments
            payments = g.calculatePayments()
            // Save to game state
            var updatedGame = g
            updatedGame.payments = payments
            manager.game = updatedGame
            // Note: updateCloudGame is private, will sync on next game update
        }
    }
    
    private func markPaymentPaid(_ payment: PaymentSummary) {
        if let index = payments.firstIndex(where: { $0.id == payment.id }) {
            payments[index].status = .paid
            payments[index].paidDate = Date()
            
            // Update game state
            var updatedGame = g
            updatedGame.payments = payments
            manager.game = updatedGame
            // Note: updateCloudGame is private, will sync on next game update
        }
    }
    
    private func openVenmo(payment: PaymentSummary) {
        let note = "PapaDot - \(g.golfCourse?.name ?? "Golf")"
        
        // Try deep link first
        if let deepLink = payment.venmoDeepLink(note: note),
           UIApplication.shared.canOpenURL(deepLink) {
            UIApplication.shared.open(deepLink)
        } else if let webLink = payment.venmoWebLink(note: note) {
            // Fallback to web
            UIApplication.shared.open(webLink)
        }
    }
    
    private func presentApplePay(for payment: PaymentSummary) {
        guard PKPaymentAuthorizationController.canMakePayments() else {
            print("Apple Pay not available")
            return
        }
        
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.jeffpaz.PapaDot"
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = .threeDSecure
        request.countryCode = "US"
        request.currencyCode = "USD"
        
        let label = "PapaDot Payment to \(payment.toPlayer.name)"
        let item = PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(value: payment.amount))
        request.paymentSummaryItems = [item]
        
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = applePayDelegate
        controller.present()
    }
}

// MARK: - Payment Card Component
struct PaymentCardView: View {
    @Binding var payment: PaymentSummary
    let onMarkPaid: () -> Void
    let onVenmo: () -> Void
    let onApplePay: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(payment.fromPlayer.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("pays")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text(payment.toPlayer.name)
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(payment.formattedAmount)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 4) {
                        Text(payment.statusEmoji)
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(statusColor)
                    }
                }
            }
            
            // Payment Buttons
            if payment.status == .pending {
                HStack(spacing: 12) {
                    // Venmo Button
                    Button {
                        onVenmo()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "app.fill")
                            Text("Venmo")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                    
                    // Apple Pay Button
                    Button {
                        onApplePay()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "apple.logo")
                            Text("Pay")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .cornerRadius(10)
                    }
                }
                
                // Mark as Paid button
                Button {
                    onMarkPaid()
                } label: {
                    Text("Mark as Paid")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            } else {
                // Paid status
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Paid")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                    
                    if let date = payment.paidDate {
                        Text("• \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.2))
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var statusText: String {
        switch payment.status {
        case .pending: return "Pending"
        case .paid: return "Paid"
        case .confirmed: return "Confirmed"
        }
    }
    
    private var statusColor: Color {
        switch payment.status {
        case .pending: return .orange
        case .paid: return .green
        case .confirmed: return .green
        }
    }
}

// MARK: - Apple Pay Delegate (Class-based)
class ApplePayDelegate: NSObject, PKPaymentAuthorizationControllerDelegate, ObservableObject {
    var onPaymentComplete: (() -> Void)?
    
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
    }
    
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController,
                                        didAuthorizePayment payment: PKPayment,
                                        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // Payment authorized
        onPaymentComplete?()
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }
}

#Preview {
    PaymentTrackingView()
        .environment(GameManager())
}
