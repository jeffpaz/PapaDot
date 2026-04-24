//  Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @Environment(GameManager.self) var manager

    // @State resets to true every cold launch so the splash always shows,
    // while game persistence underneath is unaffected.
    @State private var showSplash = true

    var body: some View {
        ZStack {
            // Main app content — already loaded/restored underneath the splash
            Group {
                if manager.showHistory {
                    GameHistoryView()
                } else if manager.showGameOver, let game = manager.game {
                    GameOverView(game: game, stake: game.rules.stakePerPoint)
                } else if manager.showWaitingRoom, let game = manager.game {
                    WaitingRoomView(game: game, isHost: manager.isHost) {
                        Task { await manager.startGame() }
                    }
                } else if manager.game != nil {
                    MainGameView()
                } else {
                    HomeView()
                }
            }
            .animation(.easeInOut, value: manager.showWaitingRoom)
            .animation(.easeInOut, value: manager.showGameOver)

            // Birthday splash overlaid on top — fades away on continue
            if showSplash {
                BirthdaySplashView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showSplash = false
                    }
                }
                .zIndex(10)
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(GameManager())
}
