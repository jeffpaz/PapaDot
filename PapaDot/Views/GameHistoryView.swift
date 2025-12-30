//  Views/GameHistoryView.swift
import SwiftUI

struct GameHistoryView: View {
    @Environment(GameManager.self) private var manager
    @State private var history: [GameState] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                if history.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "trophy.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                        Text("No games played yet")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(history, id: \.gameID) { game in
                            NavigationLink {
                                GameOverView(game: game, stake: game.rules.stakePerPoint)
                                    .navigationBarBackButtonHidden(false)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(championName(for: game))
                                            .font(.headline.bold())
                                            .foregroundStyle(.green)
                                        Text("\(game.players.map { $0.name }.joined(separator: ", "))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let date = game.completedDate {
                                        Text(date, format: .dateTime.month(.abbreviated).day().year())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteGames)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Game History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        manager.showHistory = false
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !history.isEmpty {
                        EditButton()
                    }
                }
            }
            .onAppear {
                history = PersistenceManager().loadHistory()
            }
        }
    }
    
    private func championName(for game: GameState) -> String {
        let dots = calculateTotalDots(game: game) // ← Changed to direct call
        return game.players.max(by: { dots[$0]! < dots[$1]! })?.name ?? "Unknown"
    }
    
    private func deleteGames(at offsets: IndexSet) {
        var all = PersistenceManager().loadHistory()
        all.remove(atOffsets: offsets)
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: "gameHistory")
        }
        history.remove(atOffsets: offsets)
    }
}

#Preview {
    GameHistoryView()
        .environment(GameManager())
}
