//  Views/WaitingRoomView.swift
import SwiftUI
import MessageUI

struct WaitingRoomView: View {
    let game: GameState
    let isHost: Bool
    let onStart: () -> Void
    @Environment(GameManager.self) private var manager
    @State private var selectedPlayerForInvite: Player?
    @State private var showMessagingUnavailableAlert = false

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

            ScrollView {
                VStack(spacing: 32) {
                    if manager.isOfflineMode {
                        OfflineModeBanner()
                    }

                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: isHost ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                            .font(.system(size: 80))
                            .foregroundStyle(.white)
                            .padding(.top, 40)

                        Text(isHost ? "Game Created!" : "You've Joined!")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(isHost ? "Send join links to each player" : "Waiting for host to start")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    // Golf Course Info
                    if let course = game.golfCourse {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "map.fill").foregroundStyle(.white.opacity(0.7))
                                Text("Course").font(.title3.bold()).foregroundStyle(.white)
                            }
                            .padding(.horizontal, 20)

                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .overlay {
                                        Image(systemName: "flag.fill")
                                            .foregroundStyle(.green).font(.title3)
                                    }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(course.name).font(.headline.bold()).foregroundStyle(.white)
                                    Text(course.address).font(.caption)
                                        .foregroundStyle(.white.opacity(0.6)).lineLimit(2)
                                    if let rating = course.rating {
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill").font(.caption2)
                                            Text(String(format: "%.1f", rating)).font(.caption)
                                            if let count = course.userRatingsTotal {
                                                Text("(\(count) reviews)").font(.caption2)
                                            }
                                        }
                                        .foregroundStyle(.yellow)
                                    }
                                }
                                Spacer()
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                    }

                    // Players List
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "person.3.fill").foregroundStyle(.white.opacity(0.7))
                            Text("Players (\(game.players.count))").font(.title3.bold()).foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)

                        VStack(spacing: 12) {
                            ForEach(game.players) { player in
                                playerCard(player: player)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Action Buttons
                    VStack(spacing: 12) {
                        if isHost {
                            // Send individual invite to each non-host player
                            ForEach(game.players.dropFirst()) { player in
                                Button {
                                    if MFMessageComposeViewController.canSendText() {
                                        selectedPlayerForInvite = player
                                    } else {
                                        showMessagingUnavailableAlert = true
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "message.fill")
                                        Text("Send Link to \(player.name.components(separatedBy: " ").first ?? player.name)")
                                            .font(.headline.bold())
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .leading, endPoint: .trailing))
                                    .cornerRadius(14)
                                }
                                .disabled(player.phoneNumber.isEmpty)
                                .opacity(player.phoneNumber.isEmpty ? 0.5 : 1.0)
                            }

                            Button {
                                Task { await manager.startGame() }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "flag.fill")
                                    Text("Start Round").font(.headline.bold())
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity).padding(.vertical, 18)
                                .background(LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(16)
                            }
                        } else {
                            HStack(spacing: 12) {
                                ProgressView().tint(.white)
                                Text("Waiting for host to start...")
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 18)
                            .background(Color.white.opacity(0.1)).cornerRadius(16)
                        }

                        Button {
                            manager.startNewGame()
                        } label: {
                            Text(isHost ? "Cancel Game" : "Leave Game")
                                .font(.headline).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(Color.red.opacity(0.6)).cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedPlayerForInvite) { player in
            InviteMessageComposer(
                player: player,
                joinCode: playerJoinCode(player),
                courseName: game.golfCourse?.name ?? "golf"
            )
        }
        .alert("Messaging Unavailable", isPresented: $showMessagingUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("iMessage is not available on this device. Please test on a physical device with Messages configured, or share the join code manually: \(game.gameID)")
        }
    }

    // MARK: - Player Card

    private func playerCard(player: Player) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(playerHasJoined(player) ? Color.green.opacity(0.3) : Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(String(player.name.prefix(1))).font(.title2.bold()).foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(player.name).font(.headline).foregroundStyle(.white)
                    if game.players.first?.id == player.id {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill").font(.caption)
                            Text("Host").font(.caption.bold())
                        }
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.2)).cornerRadius(8)
                    }
                    if player.handicap > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill").font(.caption)
                            Text("HCP \(player.handicap)").font(.caption.bold())
                        }
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.2)).cornerRadius(8)
                    }
                }
                if !player.phoneNumber.isEmpty {
                    Text(player.phoneNumber).font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                if isHost && game.players.first?.id != player.id {
                    Text("Code: \(playerJoinCode(player))")
                        .font(.caption.bold()).foregroundStyle(.yellow.opacity(0.8))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.white.opacity(0.1)).cornerRadius(6)
                }
            }

            Spacer()

            if playerHasJoined(player) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill").font(.caption)
                    Text("Waiting").font(.caption)
                }
                .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func playerHasJoined(_ player: Player) -> Bool {
        game.joinedPlayerIDs.contains(player.id)
    }

    private func playerJoinCode(_ player: Player) -> String {
        let index = game.players.firstIndex(where: { $0.id == player.id }) ?? 0
        return "\(game.gameID)\(index)"
    }
}

// MARK: - Invite Message Composer

struct InviteMessageComposer: UIViewControllerRepresentable {
    let player: Player
    let joinCode: String
    let courseName: String
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        print("📱 Creating message composer - canSendText: \(MFMessageComposeViewController.canSendText())")

        let controller = MFMessageComposeViewController()
        controller.recipients = [player.phoneNumber]

        let firstName = player.name.components(separatedBy: " ").first ?? player.name
        let deepLink = "papadot://join?code=\(joinCode)"
        let message = "Hey \(firstName)! Join my PapaDot game at \(courseName). Tap to join: \(deepLink)\n\nOr enter code manually: \(joinCode)"

        controller.body = message
        controller.messageComposeDelegate = context.coordinator

        print("📱 Message composer created with recipients: \(controller.recipients ?? [])")
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            print("📱 Message composer finished with result: \(result.rawValue)")
            switch result {
            case .cancelled:
                print("📱 User cancelled")
            case .sent:
                print("📱 Message sent successfully")
            case .failed:
                print("📱 Message failed to send")
            @unknown default:
                print("📱 Unknown result")
            }
            dismiss()
        }
    }
}

#Preview {
    WaitingRoomView(
        game: GameState(
            gameID: "ABC123",
            players: [
                Player(name: "Jeff", phoneNumber: "+15551234567"),
                Player(name: "Benoit", phoneNumber: "+15559876543"),
                Player(name: "Mike", phoneNumber: "+15551112222")
            ],
            rules: GameRules()
        ),
        isHost: true,
        onStart: {}
    )
    .environment(GameManager())
}
