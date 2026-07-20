//  Managers/GameManager+Widget.swift
import Foundation
import WidgetKit

extension GameManager {
    /// Save current game to App Group shared container for widget access
    @MainActor
    func shareGameWithWidget() {
        guard let game = game else { return }
        
        let sharedDefaults = UserDefaults(suiteName: "group.com.jeffpaz.PapaDot")
        
        do {
            let gameData = try JSONEncoder().encode(game)
            sharedDefaults?.set(gameData, forKey: "currentGame")

            // Reload all timelines
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Silent fail - widget update is non-critical
        }
    }
    
    /// Clear widget data when game ends
    @MainActor
    func clearWidgetData() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.jeffpaz.PapaDot")
        sharedDefaults?.removeObject(forKey: "currentGame")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
