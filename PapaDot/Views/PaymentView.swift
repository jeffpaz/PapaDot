// Views/PaymentView.swift
import SwiftUI
import PassKit

struct PaymentView: View {
    let game: GameState
    @Environment(\.dismiss) var dismiss

    private var stake: Int { game.rules.stakePerPoint }

    // calculatePayments() is an extension on GameState (defined in PaymentSummary.swift)
    private var payments: [PaymentSummary] {
        game.calculatePayments()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.2, blue: 0.1), Color(red: 0.02, green: 0.1, blue: 0.05)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.green)
                                .padding(.top, 20)
                            Text("Payments")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("$\(stake) per dot")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.bottom, 10)

                        if payments.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.green)
                                Text("No payments needed")
                                    .font(.title2.bold()).foregroundStyle(.white)
                                Text("Everyone scored the same!")
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(40)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        } else {
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
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Payment Card

struct PaymentCard: View {
    let payment: PaymentSummary
    @State private var applePayDelegate: ApplePayDelegate?
    @State private var showApplePayError = false

    var body: some View {
        VStack(spacing: 16) {
            // Payment flow
            HStack(spacing: 16) {
                playerAvatar(payment.fromPlayer, color: .blue)
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.title3).foregroundStyle(.white.opacity(0.6))
                    Text(payment.formattedAmount)
                        .font(.title.bold()).foregroundStyle(.green)
                }
                playerAvatar(payment.toPlayer, color: .green)
            }
            .padding(.top, 16)

            // Payment buttons
            VStack(spacing: 12) {
                Text("Pay with:")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 12) {
                    PaymentMethodButton(icon: "v.circle.fill", label: "Venmo", color: .blue) {
                        openVenmo(payment)
                    }
                    PaymentMethodButton(
                        icon: "dollarsign.circle.fill",
                        label: "Cash App",
                        color: Color(red: 0, green: 0.7, blue: 0.2)
                    ) {
                        openCashApp(payment)
                    }
                    if PKPaymentAuthorizationController.canMakePayments(),
                       !payment.toPlayer.phoneNumber.isEmpty {
                        PaymentMethodButton(icon: "apple.logo", label: "Apple Pay", color: .black) {
                            initiateApplePay(payment)
                        }
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .alert("Apple Pay Unavailable", isPresented: $showApplePayError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Make sure you have a card set up in Wallet.")
        }
    }

    @ViewBuilder
    private func playerAvatar(_ player: Player, color: Color) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(String(player.name.prefix(1)))
                        .font(.title2.bold()).foregroundStyle(.white)
                }
            Text(player.name)
                .font(.caption.bold()).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Payment Actions

    private func openVenmo(_ payment: PaymentSummary) {
        let note = "Golf dots - PapaDot"
        if let deepLink = payment.venmoDeepLink(note: note),
           UIApplication.shared.canOpenURL(deepLink) {
            UIApplication.shared.open(deepLink)
        } else if let webLink = payment.venmoWebLink(note: note) {
            UIApplication.shared.open(webLink)
        }
    }

    private func openCashApp(_ payment: PaymentSummary) {
        let amount = String(format: "%.2f", payment.amount)
        let cashtag = payment.toPlayer.name.components(separatedBy: .whitespaces).joined()
        let note = "Golf dots".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://cash.app/$\(cashtag)?amount=\(amount)&note=\(note)") {
            UIApplication.shared.open(url)
        }
    }

    private func initiateApplePay(_ payment: PaymentSummary) {
        guard PKPaymentAuthorizationController.canMakePayments() else {
            showApplePayError = true
            return
        }

        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.jeffpaz.PapaDot"
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = .threeDSecure  // .capability3DS was deprecated in iOS 17
        request.countryCode = "US"
        request.currencyCode = "USD"
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: "Golf Dots → \(payment.toPlayer.name)",
                amount: NSDecimalNumber(value: payment.amount)
            )
        ]

        let delegate = ApplePayDelegate {
            print("✅ Apple Pay authorized for \(payment.formattedAmount)")
        }
        applePayDelegate = delegate  // retain for duration of payment sheet

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = delegate
        controller.present()
    }
}

// MARK: - Apple Pay Delegate
// Single app-wide definition — used by both PaymentView and PaymentTrackingView.

class ApplePayDelegate: NSObject, PKPaymentAuthorizationControllerDelegate {
    var onPaymentComplete: (() -> Void)?

    init(onPaymentComplete: (() -> Void)? = nil) {
        self.onPaymentComplete = onPaymentComplete
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        onPaymentComplete?()
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }
}

// MARK: - Payment Method Button

struct PaymentMethodButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2).foregroundStyle(.white)
                Text(label)
                    .font(.caption.bold()).foregroundStyle(.white)
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
