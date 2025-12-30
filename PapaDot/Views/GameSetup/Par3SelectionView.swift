//
//  Par3SelectionView.swift
//  PapaDot
//
//  Created by Jeff Pazahanick on 12/15/25.
//


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
            Form {
                Section("Select Par 3 Holes") {
                    ForEach(1...18, id: \.self) { hole in
                        HStack {
                            Text("Hole \(hole)")
                            Spacer()
                            if selectedHoles.contains(hole) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedHoles.contains(hole) {
                                selectedHoles.remove(hole)
                            } else {
                                selectedHoles.insert(hole)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Create Game") {
                        var rules = GameRules(stakePerPoint: wager)
                        rules.par3Holes = selectedHoles
                        rules.currentGreenieValue = 1
                        
                        Task { @MainActor in
                            await manager.createGame(players: players, rules: rules)
                            dismiss()
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Par 3 Selection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    Par3SelectionView(wager: 1, players: [])
        .environment(GameManager())
}