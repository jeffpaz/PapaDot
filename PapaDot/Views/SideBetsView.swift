//
//  SideBetsView.swift
//  PapaDot
//
//  Created by Jeff Pazahanick on 4/23/26.
//


// Views/SideBetsView.swift
import SwiftUI

struct SideBetsView: View {
    @Environment(GameManager.self) var manager
    @Environment(\.dismiss) var dismiss
    @State private var showingAddBet = false

    private var game: GameState { manager.game! }
    private var activeBets: [SideBet] { game.sideBets.filter { $0.status == .active } }
    private var settledBets: [SideBet] { game.sideBets.filter { $0.status == .settled } }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.35, blue: 0.2), Color(red: 0.05, green: 0.2, blue: 0.1)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Active Bets
                        if !activeBets.isEmpty {
                            sectionHeader(title: "Active Bets", icon: "bolt.fill", color: .yellow)

                            ForEach(activeBets) { bet in
                                SideBetCard(bet: bet, players: game.players,
                                    onSettle: { winner in manager.settleSideBet(id: bet.id, winner: winner) },
                                    onDelete: { manager.deleteSideBet(id: bet.id) }
                                )
                            }
                        }

                        // Settled Bets
                        if !settledBets.isEmpty {
                            sectionHeader(title: "Settled", icon: "checkmark.circle.fill", color: .green)

                            ForEach(settledBets) { bet in
                                SettledBetCard(bet: bet)
                            }
                        }

                        // Empty state
                        if game.sideBets.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "dollarsign.circle")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text("No side bets yet")
                                    .font(.title3.bold()).foregroundStyle(.white)
                                Text("Add a bet for longest drive, closest to pin, and more")
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                                    .multilineTextAlignment(.center).padding(.horizontal, 40)
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }

                // FAB
                VStack {
                    Spacer()
                    Button { showingAddBet = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill").font(.title2)
                            Text("New Side Bet").font(.headline.bold())
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.yellow)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Side Bets 💰")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showingAddBet) {
                AddSideBetView(players: game.players) { bet in
                    manager.addSideBet(bet)
                }
            }
        }
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color)
            Text(title).font(.headline.bold()).foregroundStyle(.white)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Active Bet Card

struct SideBetCard: View {
    let bet: SideBet
    let players: [Player]
    let onSettle: (String) -> Void
    let onDelete: () -> Void
    @State private var showingSettle = false
    @State private var showingDelete = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bet.title)
                        .font(.headline.bold()).foregroundStyle(.white)
                    if !bet.description.isEmpty {
                        Text(bet.description)
                            .font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                }
                Spacer()
                Text("$\(bet.amount)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
            }

            HStack(spacing: 8) {
                Label("By \(bet.createdBy)", systemImage: "person.fill")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                if let hole = bet.hole {
                    Text("• Hole \(hole)")
                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text("\(bet.participants.count) players")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 12) {
                Button {
                    showingSettle = true
                } label: {
                    Label("Settle", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(10)
                }

                Button {
                    showingDelete = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 36)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        // Settle confirmation
        .confirmationDialog("Who won the bet?", isPresented: $showingSettle, titleVisibility: .visible) {
            ForEach(players) { player in
                Button(player.name) { onSettle(player.name) }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Delete confirmation
        .alert("Delete Bet?", isPresented: $showingDelete) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Settled Bet Card

struct SettledBetCard: View {
    let bet: SideBet

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(bet.title).font(.subheadline.bold()).foregroundStyle(.white)
                if let winner = bet.winnerId {
                    Text("🏆 \(winner) won $\(bet.amount)")
                        .font(.caption).foregroundStyle(.green)
                }
            }
            Spacer()
            Text("$\(bet.amount)")
                .font(.headline.bold())
                .foregroundStyle(.white.opacity(0.4))
                .strikethrough()
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
}

// MARK: - Add Side Bet Sheet

struct AddSideBetView: View {
    @Environment(\.dismiss) var dismiss
    let players: [Player]
    let onAdd: (SideBet) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var amount = 5
    @State private var hole: Int? = nil
    @State private var selectedParticipants: Set<String> = []
    @AppStorage("userName") private var userName = "Me"

    private let quickTitles = ["Longest Drive", "Closest to Pin", "Most Birdies", "Low Round", "Fewest Putts", "First Birdie"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick Pick") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickTitles, id: \.self) { t in
                                Button {
                                    title = t
                                } label: {
                                    Text(t)
                                        .font(.caption.bold())
                                        .foregroundStyle(title == t ? .black : .white)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(title == t ? Color.yellow : Color.white.opacity(0.2))
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Bet Details") {
                    TextField("Title (e.g. Longest Drive)", text: $title)
                    TextField("Notes (optional)", text: $description)
                    Stepper("$\(amount)", value: $amount, in: 1...500, step: 5)
                }

                Section("Hole (optional)") {
                    Picker("Hole", selection: $hole) {
                        Text("Any").tag(nil as Int?)
                        ForEach(1...18, id: \.self) { h in
                            Text("Hole \(h)").tag(h as Int?)
                        }
                    }
                }

                Section("Participants") {
                    ForEach(players) { player in
                        HStack {
                            Text(player.name)
                            Spacer()
                            if selectedParticipants.contains(player.name) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else {
                                Image(systemName: "circle").foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedParticipants.contains(player.name) {
                                selectedParticipants.remove(player.name)
                            } else {
                                selectedParticipants.insert(player.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Side Bet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let bet = SideBet(
                            title: title.trimmingCharacters(in: .whitespaces),
                            description: description,
                            amount: amount,
                            createdBy: userName,
                            participants: selectedParticipants.isEmpty
                                ? players.map { $0.name }
                                : Array(selectedParticipants),
                            hole: hole
                        )
                        onAdd(bet)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selectedParticipants = Set(players.map { $0.name })
            }
        }
    }
}
