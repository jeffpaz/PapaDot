//  Managers/GameManager.swift
import SwiftUI
import CloudKit

@Observable
final class GameManager {
    var game: GameState?
    var isMultiplayer = false
    var joinCode = ""
    var showGameOver = false
    var isLoading = false
    var isHost = false
    var showWaitingRoom = false
    var showHistory = false
    
    private let container = CKContainer(identifier: "iCloud.com.jeffpaz.PapaDot")
    private var database: CKDatabase { container.privateCloudDatabase }
    private let recordType = "PapaDotGame"
    private let haptic = UIImpactFeedbackGenerator(style: .heavy)
    private let persistence = PersistenceManager()
    
    init() {
        if let saved = persistence.loadCurrent() {
            game = saved
            isMultiplayer = true
            joinCode = saved.gameID
            isHost = saved.recordID != nil
            showWaitingRoom = !saved.isActive
            startListeningForChanges()
        }
    }
    
    @MainActor
    func createGame(players: [Player], rules: GameRules) async {
        isLoading = true
        let gameID = String(UUID().uuidString.prefix(6)).uppercased()
        
        let record = CKRecord(recordType: recordType)
        record["gameID"] = gameID
        record["playersJSON"] = try! JSONEncoder().encode(players)
        record["rulesJSON"] = try! JSONEncoder().encode(rules)
        record["currentHole"] = 1
        record["isActive"] = false
        record["scoresJSON"] = Data()
        record["joinedPlayerIDsJSON"] = try! JSONEncoder().encode([players.first!.id]) // Host is auto-joined
        
        do {
            let saved = try await database.save(record)
            var newGame = GameState(
                recordID: saved.recordID.recordName,
                gameID: gameID,
                players: players,
                rules: rules
            )
            newGame.joinedPlayerIDs = [players.first!.id] // Host is joined
            finishSetup(newGame, host: true)
            startListeningForChanges()
        } catch {
            print("Cloud save failed: \(error)")
            var local = GameState(recordID: nil, gameID: gameID, players: players, rules: rules)
            local.joinedPlayerIDs = [players.first!.id]
            finishSetup(local, host: true)
        }
        isLoading = false
    }
    
    @MainActor
    func joinGame(with code: String) async {
        isLoading = true
        print("🔵 Attempting to join with code: \(code)")
        
        // Parse the 7-character code: first 6 = gameID, last digit = player index
        guard code.count == 7 else {
            print("❌ Invalid code length: \(code.count)")
            isLoading = false
            return
        }
        
        let gameID = String(code.prefix(6))
        let playerIndexChar = code.last ?? "0"
        guard let playerIndex = Int(String(playerIndexChar)) else {
            print("❌ Invalid player index: \(playerIndexChar)")
            isLoading = false
            return
        }
        
        print("🔵 Searching for game: \(gameID), player index: \(playerIndex)")
        
        let predicate = NSPredicate(format: "gameID == %@", gameID)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            print("🔵 Found \(results.matchResults.count) results")
            
            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    var fetched = gameState(from: record)
                    print("🔵 Game found with \(fetched.players.count) players")
                    
                    // Verify player index is valid
                    guard playerIndex < fetched.players.count else {
                        print("❌ Player index \(playerIndex) out of range (max: \(fetched.players.count - 1))")
                        isLoading = false
                        return
                    }
                    
                    // Mark this player as joined
                    let joiningPlayer = fetched.players[playerIndex]
                    fetched.joinedPlayerIDs.insert(joiningPlayer.id)
                    print("✅ Player \(joiningPlayer.name) marked as joined")
                    
                    // Update CloudKit with joined status
                    record["joinedPlayerIDsJSON"] = try! JSONEncoder().encode(fetched.joinedPlayerIDs)
                    try? await database.save(record)
                    print("✅ CloudKit updated")
                    
                    finishSetup(fetched, host: false)
                    startListeningForChanges()
                    isLoading = false
                    print("✅ Join complete, showing waiting room")
                    return
                }
            }
            
            print("❌ No game found with gameID: \(gameID)")
        } catch {
            print("❌ Join failed with error: \(error)")
        }
        
        isLoading = false
    }
    
    private func finishSetup(_ game: GameState, host: Bool) {
        self.game = game
        self.isMultiplayer = true
        self.joinCode = game.gameID
        self.isHost = host
        self.showWaitingRoom = true
        haptic.impactOccurred()
        persistence.saveCurrent(game)
    }
    
    func startRound() {
        guard var g = game, isHost else { return }
        g.isActive = true
        game = g
        showWaitingRoom = false
        persistence.saveCurrent(g)
        Task { await updateCloudGame() }
    }
    
    // MARK: - Greenie Logic Integration
    func toggleScore(playerName: String, hole: Int, task: String) {
        guard var g = game, g.isActive else { return }
        let wasOn = g.scores[hole]?[playerName]?[task] ?? false
        g.scores[hole, default: [:]][playerName, default: [:]][task] = !wasOn
        
        // Handle exclusive tasks (Greenie, Low Hole)
        if let taskObj = g.rules.tasks.first(where: { $0.name == task }), taskObj.isExclusive && !wasOn {
            for p in g.players where p.name != playerName {
                g.scores[hole, default: [:]][p.name, default: [:]][task] = false
            }
        }
        
        game = g
        haptic.impactOccurred()
        persistence.saveCurrent(g)
        Task { await updateCloudGame() }
    }
    
    func setHole(_ hole: Int) {
        guard var g = game else { return }
        
        // Only check greenie value when moving forward from a par 3 that has scores
        if hole > g.currentHole && g.rules.par3Holes.contains(g.currentHole) {
            // Only process greenie if there are actual scores recorded for this hole
            if g.scores[g.currentHole] != nil {
                checkAndUpdateGreenieValue(forHole: g.currentHole)
            }
        }
        
        // Update hole number
        g.currentHole = min(18, max(1, hole))
        game = g
        persistence.saveCurrent(g)
        
        // Show game over if finishing hole 18
        if g.currentHole == 18 && !showGameOver && hole > 18 {
            showGameOver = true
            persistence.saveToHistory(g)
        }
        
        Task { await updateCloudGame() }
    }
    
    private func checkAndUpdateGreenieValue(forHole hole: Int) {
        guard var g = game else { return }
        
        // Only process if this was a par 3 hole
        guard g.rules.par3Holes.contains(hole) else { return }
        
        // Check if anyone got a greenie on this hole
        let scores = g.scores[hole] ?? [:]
        var someoneGotGreenie = false
        
        for (_, tasks) in scores {
            if tasks["Greenie"] == true {
                someoneGotGreenie = true
                break
            }
        }
        
        // Update greenie value for next par 3
        if !someoneGotGreenie {
            // No one got it - increment the value
            g.rules.currentGreenieValue += 1
        } else {
            // Someone got it - reset to 1
            g.rules.currentGreenieValue = 1
        }
        
        game = g
        persistence.saveCurrent(g)
        Task { await updateCloudGame() }
    }
    
    // MARK: - CloudKit Sync
    private func updateCloudGame() async {
        guard let game = game,
              let recordID = game.recordID else { return }
        
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            record["currentHole"] = game.currentHole
            record["isActive"] = game.isActive
            record["scoresJSON"] = try JSONEncoder().encode(game.scores)
            record["rulesJSON"] = try JSONEncoder().encode(game.rules)
            record["joinedPlayerIDsJSON"] = try JSONEncoder().encode(game.joinedPlayerIDs)
            try await database.save(record)
        } catch {
            print("Cloud update failed: \(error)")
        }
    }
    
    private func startListeningForChanges() {
        guard let recordID = game?.recordID else { return }
        
        // Poll for changes every 2 seconds while in waiting room OR during active game
        Task {
            while showWaitingRoom || (game?.isActive == true) {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await refreshGameState()
                
                // Stop polling if game is no longer active
                if game?.isActive == false && !showWaitingRoom {
                    break
                }
            }
        }
        
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: NSPredicate(format: "recordName == %@", recordID),
            options: .firesOnRecordUpdate
        )
        
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        
        database.save(subscription) { _, error in
            if let error = error {
                print("Subscription failed: \(error)")
            }
        }
    }
    
    @MainActor
    private func refreshGameState() async {
        guard let recordID = game?.recordID else { return }
        
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            let updated = gameState(from: record)
            
            print("🔄 Synced: Hole \(updated.currentHole), Active: \(updated.isActive)")
            
            game = updated
            
            // If game became active, close waiting room
            if updated.isActive && showWaitingRoom {
                showWaitingRoom = false
            }
        } catch {
            print("Refresh failed: \(error)")
        }
    }
    
    private func gameState(from record: CKRecord) -> GameState {
        let gameID = record["gameID"] as? String ?? ""
        let playersData = record["playersJSON"] as? Data ?? Data()
        let rulesData = record["rulesJSON"] as? Data ?? Data()
        let scoresData = record["scoresJSON"] as? Data ?? Data()
        let joinedIDsData = record["joinedPlayerIDsJSON"] as? Data ?? Data()
        
        let players = (try? JSONDecoder().decode([Player].self, from: playersData)) ?? []
        let rules = (try? JSONDecoder().decode(GameRules.self, from: rulesData)) ?? GameRules()
        let currentHole = record["currentHole"] as? Int ?? 1
        let isActive = record["isActive"] as? Bool ?? false
        let scores = (try? JSONDecoder().decode([Int: [String: [String: Bool]]].self, from: scoresData)) ?? [:]
                    let joinedIDs = (try? JSONDecoder().decode(Set<String>.self, from: joinedIDsData)) ?? []
        
        return GameState(
            recordID: record.recordID.recordName,
            gameID: gameID,
            players: players,
            rules: rules,
            currentHole: currentHole,
            scores: scores,
            isActive: isActive,
            joinedPlayerIDs: joinedIDs
        )
    }
    
    func startNewGame() {
        persistence.clearCurrent()
        game = nil
        showWaitingRoom = false
        showGameOver = false
        isMultiplayer = false
        isHost = false
        joinCode = ""
        showHistory = false
    }
}
