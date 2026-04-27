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

    private var teamScores: [(team: String, players: [Player], totalDots: Int, net: Int)] {
        guard game.rules.isTeamMode && game.players.count == 4 else { return [] }

        let dots = calculateTotalDots(game: game)
        let stake = game.rules.stakePerPoint

        let teamA = [game.players[0], game.players[1]]
        let teamB = [game.players[2], game.players[3]]

        let teamADots = teamA.map { dots[$0] ?? 0 }.reduce(0, +)
        let teamBDots = teamB.map { dots[$0] ?? 0 }.reduce(0, +)

        let diff = teamADots - teamBDots
        let netA = diff * stake * 2  // Each player owes/receives
        let netB = -netA

        return [
            (team: "A", players: teamA, totalDots: teamADots, net: netA),
            (team: "B", players: teamB, totalDots: teamBDots, net: netB)
        ].sorted { $0.totalDots > $1.totalDots }
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

            // Team Mode: Show team scores
            if game.rules.isTeamMode {
                VStack(spacing: 0) {
                    ForEach(Array(teamScores.enumerated()), id: \.element.team) { index, team in
                        TeamLeaderboardRow(
                            rank: index + 1,
                            team: team.team,
                            players: team.players,
                            totalDots: team.totalDots,
                            net: team.net,
                            isLeading: index == 0 && team.totalDots > 0
                        )

                        if index < teamScores.count - 1 {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
            } else {
                // Regular Mode: Show individual player scores
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
        }
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
}

// MARK: - Team Leaderboard Row

private struct TeamLeaderboardRow: View {
    let rank: Int
    let team: String
    let players: [Player]
    let totalDots: Int
    let net: Int
    let isLeading: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 28, height: 28)
                Image(systemName: rank == 1 ? "crown.fill" : "medal.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Team Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Team \(team)")
                    .font(.system(size: 16, weight: isLeading ? .bold : .semibold))
                    .foregroundStyle(team == "A" ? .cyan : .orange)

                HStack(spacing: 4) {
                    ForEach(players) { player in
                        Text(player.name)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        if player.id != players.last?.id {
                            Text("&").font(.caption2).foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
            }

            if isLeading {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }

            Spacer()

            // Dots
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(totalDots)")
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
        .background(isLeading ? (team == "A" ? Color.cyan.opacity(0.06) : Color.orange.opacity(0.06)) : Color.clear)
    }

    private var rankColor: Color {
        if rank == 1 {
            return team == "A" ? .cyan.opacity(0.8) : .orange.opacity(0.8)
        } else {
            return .gray.opacity(0.6)
        }
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
