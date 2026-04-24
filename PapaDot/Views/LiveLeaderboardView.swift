//
//  LiveLeaderboardView.swift
//  PapaDot
//
//  Created by Jeff Pazahanick on 4/23/26.
//


// Views/LiveLeaderboardView.swift
import SwiftUI

/// Compact live leaderboard shown during play — pulls from calculateTotalDots in real time
struct LiveLeaderboardView: View {
    let game: GameState

    private var ranked: [(player: Player, dots: Int, net: Int)] {
        let dots = calculateTotalDots(game: game)
        let stake = game.rules.stakePerPoint
        let sorted = game.players.sorted { dots[$0]! > dots[$1]! }

        return sorted.map { player in
            var net = 0
            let myDots = dots[player]!
            for other in game.players where other.id != player.id {
                let diff = myDots - dots[other]!
                net += diff * stake
            }
            return (player: player, dots: myDots, net: net)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.caption).foregroundStyle(.yellow)
                Text("LEADERBOARD")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.yellow)
                    .tracking(1.5)
                Spacer()
                Text("Hole \(game.currentHole) of 18")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))

            // Player rows
            VStack(spacing: 0) {
                ForEach(Array(ranked.enumerated()), id: \.element.player.id) { index, item in
                    LeaderboardRow(
                        rank: index + 1,
                        player: item.player,
                        dots: item.dots,
                        net: item.net,
                        stake: game.rules.stakePerPoint,
                        isLeading: index == 0 && item.dots > 0
                    )

                    if index < ranked.count - 1 {
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
            }
        }
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
}

// MARK: - Leaderboard Row

private struct LeaderboardRow: View {
    let rank: Int
    let player: Player
    let dots: Int
    let net: Int
    let stake: Int
    let isLeading: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 28, height: 28)
                if rank <= 3 {
                    Image(systemName: rankIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(rank)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            // Name
            Text(player.name)
                .font(.system(size: 15, weight: isLeading ? .bold : .medium))
                .foregroundStyle(.white)

            if isLeading {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }

            Spacer()

            // Dots
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(dots)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.green)
                    Text("dots")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Net money
                Text(net >= 0 ? "+$\(net)" : "-$\(abs(net))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(net >= 0 ? .green.opacity(0.8) : .red.opacity(0.8))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isLeading ? Color.yellow.opacity(0.06) : Color.clear)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow.opacity(0.8)
        case 2: return .gray.opacity(0.6)
        case 3: return .orange.opacity(0.6)
        default: return .white.opacity(0.15)
        }
    }

    private var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return ""
        }
    }
}

#Preview {
    ZStack {
        Color(red: 0.1, green: 0.35, blue: 0.2).ignoresSafeArea()
        LiveLeaderboardView(game: GameState(
            gameID: "TEST",
            players: [
                Player(name: "Jeff", phoneNumber: ""),
                Player(name: "Mike", phoneNumber: ""),
                Player(name: "Benoit", phoneNumber: "")
            ],
            rules: GameRules(stakePerPoint: 2)
        ))
        .padding()
    }
}
