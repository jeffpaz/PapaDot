// Managers/FavoritesManager.swift
import Foundation

/// Manages a list of favorite players for quick addition to new games.
/// Favorites can come from Contacts or be manually entered players.
@Observable
final class FavoritesManager {
    private let defaults = UserDefaults.standard
    private let storageKey = "favoritePlayers"

    var favorites: [Player] = []

    init() {
        load()
    }

    // MARK: - CRUD

    func add(_ player: Player) {
        guard !isFavorite(player) else { return }
        favorites.append(player)
        persist()
    }

    func remove(_ player: Player) {
        favorites.removeAll { $0.id == player.id }
        persist()
    }

    /// Toggle favorite status — returns true if now a favorite
    @discardableResult
    func toggle(_ player: Player) -> Bool {
        if let idx = favorites.firstIndex(where: { $0.phoneNumber == player.phoneNumber && !player.phoneNumber.isEmpty }) {
            favorites.remove(at: idx)
            persist()
            return false
        } else {
            add(player)
            return true
        }
    }

    func isFavorite(_ player: Player) -> Bool {
        if !player.phoneNumber.isEmpty {
            return favorites.contains { $0.phoneNumber == player.phoneNumber }
        }
        return favorites.contains { $0.name == player.name }
    }

    /// Updates the stored handicap for a favorited player so next-game pre-population is current.
    func updateHandicap(for player: Player, handicap: Int) {
        guard let idx = favorites.firstIndex(where: {
            (!player.phoneNumber.isEmpty && $0.phoneNumber == player.phoneNumber) || $0.name == player.name
        }) else { return }
        favorites[idx].handicap = handicap
        favorites[idx].lastUsedHandicap = handicap
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([Player].self, from: data) else { return }
        favorites = saved
    }
}
