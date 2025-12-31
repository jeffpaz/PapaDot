//  Views/GameSetup/Par3SelectionView.swift
import SwiftUI

struct Par3SelectionView: View {
    let wager: Int
    let players: [Player]
    @Environment(GameManager.self) var manager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedHoles: Set<Int> = []
    
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
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.yellow)
                        
                        Text("Select Par 3 Holes")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Tap holes that are par 3s")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // Two Column Grid
                    HStack(alignment: .top, spacing: 20) {
                        // Holes 1-9
                        VStack(spacing: 0) {
                            Text("Front 9")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .padding(.bottom, 12)
                            
                            VStack(spacing: 8) {
                                ForEach(1...9, id: \.self) { hole in
                                    holeButton(hole: hole)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Holes 10-18
                        VStack(spacing: 0) {
                            Text("Back 9")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .padding(.bottom, 12)
                            
                            VStack(spacing: 8) {
                                ForEach(10...18, id: \.self) { hole in
                                    holeButton(hole: hole)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    
                    // Summary
                    if !selectedHoles.isEmpty {
                        VStack(spacing: 8) {
                            Text("\(selectedHoles.count) Par 3\(selectedHoles.count == 1 ? "" : "s") Selected")
                                .font(.headline)
                                .foregroundStyle(.yellow)
                            
                            Text(selectedHoles.sorted().map { String($0) }.joined(separator: ", "))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    // Create Game Button
                    Button {
                        createGame()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Create Game")
                                .font(.headline.bold())
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Par 3 Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - Hole Button
    private func holeButton(hole: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                if selectedHoles.contains(hole) {
                    selectedHoles.remove(hole)
                } else {
                    selectedHoles.insert(hole)
                }
            }
        } label: {
            HStack {
                Text("Hole \(hole)")
                    .font(.body.bold())
                    .foregroundStyle(selectedHoles.contains(hole) ? .black : .white)
                
                Spacer()
                
                if selectedHoles.contains(hole) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                selectedHoles.contains(hole) ?
                Color.yellow :
                Color.white.opacity(0.15)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Create Game
    private func createGame() {
        var rules = GameRules(stakePerPoint: wager)
        rules.par3Holes = selectedHoles
        rules.currentGreenieValue = 1
        
        Task { @MainActor in
            await manager.createGame(players: players, rules: rules)
            dismiss()
        }
    }
}

#Preview {
    Par3SelectionView(wager: 1, players: [
        Player(name: "Alice", phoneNumber: "555-1234"),
        Player(name: "Bob", phoneNumber: "555-5678")
    ])
    .environment(GameManager())
}
