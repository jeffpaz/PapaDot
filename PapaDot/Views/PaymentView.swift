// Views/PaymentView.swift
import SwiftUI

struct PaymentView: View {
    let game: GameState
    @Environment(\.dismiss) var dismiss

    private var stake: Int { game.rules.stakePerPoint }

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

    var body: some View {
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
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
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
