//  Views/WaitingRoomView.swift
import SwiftUI

struct WaitingRoomView: View {
    let game: GameState
    let isHost: Bool
    let onStart: () -> Void
    @Environment(GameManager.self) private var manager
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 44) {
                Text(isHost ? "Game Created!" : "You've Joined!")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.green)
                    .shadow(color: .green.opacity(0.6), radius: 12)
                
                VStack(spacing: 12) {
                    Text("Game Code")
                        .font(.title3.bold())
                        .foregroundColor(.secondary)
                    
                    Text(game.gameID)
                        .font(.system(size: 64, weight: .black, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .tracking(8)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(.white.opacity(0.12))
                        .cornerRadius(16)
                }
                
                ShareLink(item: game.gameID) {
                    Label("Share Code", systemImage: "square.and.arrow.up")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 50)
                
                if isHost {
                    Button("Start Round") {
                        onStart()
                    }
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundColor(.black)
                    .cornerRadius(16)
                    .padding(.horizontal, 50)
                } else {
                    Text("Waiting for host to start...")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                Spacer()
                
                // NEW: Leave Game button for non-hosts
                if !isHost {
                    Button("Leave Game") {
                        manager.startNewGame()
                    }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 50)
                }
            }
            .padding(.top, 40)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    manager.startNewGame()
                }
                .foregroundColor(.blue)
            }
        }
    }
}
