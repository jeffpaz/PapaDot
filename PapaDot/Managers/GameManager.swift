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
    
    private let container = CKContainer.default()
    private let database = CKContainer.default().privateCloudDatabase
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
        
        do {
            let saved = try await database.save(record)
            let newGame = GameState(
                recordID: saved.recordID.recordName,
                gameID: gameID,
                players: players,
                rules: rules
            )
            finishSetup(newGame, host: true)
            startListeningForChanges()
        } catch {
            print("Cloud save failed: \(error)")
            let local = GameState(recordID: nil, gameID: gameID, players: players, rules: rules)
            finishSetup(local, host: true)
        }
        isLoading = false
    }
    
    @MainActor
    func joinGame(with code: String) async {
        isLoading = true
        
        let predicate = NSPredicate(format: "gameID == %@", code)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    let fetched = gameState(from: record)
                    finishSetup(fetched, host: false)
                    startListeningForChanges()
                    isLoading = false
                    return
                }
            }
        } catch {
            print("Join failed: \(error)")
        }
        
        let local = GameState(recordID: nil, gameID: code, players: [], rules: GameRules())
        finishSetup(local, host: false)
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
    
    func toggleScore(playerName: String, hole: Int, task: String) {
        guard var g = game, g.isActive else { return }
        let wasOn = g.scores[hole]?[playerName]?[task] ?? false
        g.scores[hole, default: [:]][playerName, default: [:]][task] = !wasOn
        
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
        g.currentHole = min(18, max(1, hole))
        game = g
        persistence.saveCurrent(g)
        if g.currentHole == 18 && !showGameOver {
            showGameOver = true
            persistence.saveToHistory(g)
        }
        Task { await updateCloudGame() }
    }
    
    private func updateCloudGame() async {
        guard let game = game,
              let recordID = game.recordID else { return }
        
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            record["currentHole"] = game.currentHole
            record["isActive"] = game.isActive
            record["scoresJSON"] = try JSONEncoder().encode(game.scores)
            try await database.save(record)
        } catch {
            print("Cloud update failed: \(error)")
        }
    }
    
    private func startListeningForChanges() {
        guard let recordID = game?.recordID else { return }
        
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
    
    private func gameState(from record: CKRecord) -> GameState {
        let gameID = record["gameID"] as? String ?? ""
        let playersData = record["playersJSON"] as? Data ?? Data()
        let rulesData = record["rulesJSON"] as? Data ?? Data()
        let scoresData = record["scoresJSON"] as? Data ?? Data()
        
        let players = (try? JSONDecoder().decode([Player].self, from: playersData)) ?? []
        let rules = (try? JSONDecoder().decode(GameRules.self, from: rulesData)) ?? GameRules()
        let currentHole = record["currentHole"] as? Int ?? 1
        let isActive = record["isActive"] as? Bool ?? false
        let scores = (try? JSONDecoder().decode([Int: [String: [String: Bool]]].self, from: scoresData)) ?? [:]
        
        return GameState(
            recordID: record.recordID.recordName,
            gameID: gameID,
            players: players,
            rules: rules,
            currentHole: currentHole,
            scores: scores,
            isActive: isActive
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
