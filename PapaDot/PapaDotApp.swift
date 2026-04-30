// PapaDotApp.swift
import SwiftUI

@main
struct PapaDotApp: App {
    @State private var manager = GameManager()
    @State private var savedTasksManager = SavedTasksManager()
    @State private var favoritesManager = FavoritesManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(manager)
                .environment(savedTasksManager)
                .environment(favoritesManager)
                // Handle deep links: papadot://join?code=XXXXXX1
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Expected format: papadot://join?code=XXXXXX1
        guard url.scheme == "papadot",
              url.host == "join",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
              let code = codeItem.value,
              !code.isEmpty else { return }

        if let existing = manager.game, existing.isActive { return }

        Task {
            await manager.joinGame(with: code)
        }
    }
}
