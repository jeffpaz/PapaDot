//  ContentView.swift
//  PapaDot
//
//  Created by Jeff Pazahanick on 12/1/25.
//
import SwiftUI

struct ContentView: View {
    @Environment(GameManager.self) var manager
    
    var body: some View {
        Group {
            if manager.showHistory {
                GameHistoryView()
            } else if manager.showGameOver, let game = manager.game {
                GameOverView(game: game, stake: game.rules.stakePerPoint)
            } else if manager.showWaitingRoom, let game = manager.game {
                WaitingRoomView(game: game, isHost: manager.isHost) { manager.startRound() }
            } else if manager.game != nil {
                MainGameView()
            } else {
                HomeView()  // ← Changed from ModeSelectionView to HomeView
            }
        }
        .animation(.easeInOut, value: manager.showWaitingRoom)
        .animation(.easeInOut, value: manager.showGameOver)
    }
}

#Preview {
    ContentView()
        .environment(GameManager())
}
