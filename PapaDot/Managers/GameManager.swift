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
    
    // NEW: Track pending cloud updates to prevent refresh race conditions
    private var pendingCloudUpdate = false
    
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
    func createGame(players: [Player], rules: GameRules, golfCourse: GolfCourse? = nil, courseData: GolfCourseData? = nil) async {
        isLoading = true
        let gameID = String(UUID().uuidString.prefix(6)).uppercased()
        
        print("🎮 Creating game with courseData: \(courseData != nil ? "YES" : "NO")")
        if let data = courseData {
            print("📊 Course: \(data.courseName), Total Par: \(data.totalPar), Par 3s: \(data.par3Holes)")
        }
        
        let record = CKRecord(recordType: recordType)
        record["gameID"] = gameID
        record["playersJSON"] = try! JSONEncoder().encode(players)
        record["rulesJSON"] = try! JSONEncoder().encode(rules)
        record["currentHole"] = 1
        record["isActive"] = false
        record["scoresJSON"] = Data()
        record["joinedPlayerIDsJSON"] = try! JSONEncoder().encode(Array([players.first!.id])) // Encode Set as Array
        
        // Store golf course if provided
        if let course = golfCourse {
            record["golfCourseJSON"] = try? JSONEncoder().encode(course)
        }
        
        // Store course data if provided
        if let data = courseData {
            record["courseDataJSON"] = try? JSONEncoder().encode(data)
        }
        
        do {
            let saved = try await database.save(record)
            let newGame = GameState(
                recordID: saved.recordID.recordName,
                gameID: gameID,
                players: players,
                rules: rules,
                currentHole: 1,
                scores: [:],
                isActive: false,
                joinedPlayerIDs: [players.first!.id], // Set literal
                golfCourse: golfCourse,
                courseData: courseData,
                greenieValues: [:],
                processedPar3Holes: []
            )
            
            game = newGame
            isMultiplayer = true
            self.joinCode = gameID
            isHost = true
            showWaitingRoom = true
            persistence.saveCurrent(newGame)
            startListeningForChanges()
        } catch {
            print("Failed to create game: \(error)")
        }
        
        isLoading = false
    }
    
    func setHole(_ hole: Int) {
        guard var g = game else { return }
        
        // ALWAYS check greenie value when moving forward from a par 3
        // Increment happens whether anyone scored or not
        if hole > g.currentHole && g.rules.par3Holes.contains(g.currentHole) {
            checkAndUpdateGreenieValue(forHole: g.currentHole)
            // Reload game after greenie update to get the new value
            guard var updatedG = game else { return }
            g = updatedG
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
        
        // NEW: Mark that we have a pending cloud update
        pendingCloudUpdate = true
        
        Task {
            await updateCloudGame()
            // Clear the flag after update completes
            await MainActor.run {
                self.pendingCloudUpdate = false
            }
        }
    }
    
    private func checkAndUpdateGreenieValue(forHole hole: Int) {
        guard var g = game else { return }
        
        // Only process if this was a par 3 hole
        guard g.rules.par3Holes.contains(hole) else { return }
        
        // Check if we've already processed this hole
        guard !g.processedPar3Holes.contains(hole) else {
            print("⏭️ Par 3 hole \(hole) already processed, skipping increment")
            return
        }
        
        // Mark this hole as processed
        g.processedPar3Holes.insert(hole)
        
        // Check if anyone scored a greenie on this hole
        var anyoneGotGreenie = false
        if let holeScores = g.scores[hole] {
            for (_, tasks) in holeScores {
                if tasks["Greenie"] == true {
                    anyoneGotGreenie = true
                    break
                }
            }
        }
        
        // ALWAYS increment after a par 3, whether greenie was scored or not
        if anyoneGotGreenie {
            print("💚 Greenie awarded on hole \(hole) worth \(g.rules.currentGreenieValue)! Incrementing to \(g.rules.currentGreenieValue + 1)")
        } else {
            print("⚪️ No greenie on hole \(hole), value \(g.rules.currentGreenieValue) carries over. Incrementing to \(g.rules.currentGreenieValue + 1)")
        }
        
        g.rules.currentGreenieValue += 1
        game = g
        persistence.saveCurrent(g)
    }
    
    func toggleScore(player: Player, task: CustomTask, hole: Int) {
        guard var g = game else { return }
        
        if g.scores[hole] == nil {
            g.scores[hole] = [:]
        }
        
        if g.scores[hole]![player.name] == nil {
            g.scores[hole]![player.name] = [:]
        }
        
        let currentlyOn = g.scores[hole]![player.name]![task.name] ?? false
        let wasOn = currentlyOn
        
        if task.isExclusive {
            for p in g.players {
                g.scores[hole]![p.name]?[task.name] = (p.id == player.id)
            }
        } else {
            g.scores[hole]![player.name]![task.name] = !currentlyOn
        }
        
        // Store the greenie value when it's scored
        if task.name == "Greenie" && !wasOn && g.rules.par3Holes.contains(hole) {
            print("💚 Greenie value for hole \(hole) saved as \(g.rules.currentGreenieValue)")
            g.greenieValues[hole] = g.rules.currentGreenieValue
        }
        
        haptic.impactOccurred()
        game = g
        persistence.saveCurrent(g)
        
        // NEW: Mark that we have a pending cloud update
        pendingCloudUpdate = true
        
        Task {
            await updateCloudGame()
            // Clear the flag after update completes
            await MainActor.run {
                self.pendingCloudUpdate = false
            }
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
            subscriptionID: "game-updates-\(recordID)",
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
        // NEW: Skip refresh if we have a pending cloud update
        guard !pendingCloudUpdate else {
            print("⏭️ Skipping refresh - pending cloud update")
            return
        }
        
        guard let recordID = game?.recordID else { return }
        
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            let updated = gameState(from: record)
            
            print("🔄 Synced: Hole \(updated.currentHole), Active: \(updated.isActive)")
            
            game = updated
            
            if updated.isActive && showWaitingRoom {
                showWaitingRoom = false
            }
            
            persistence.saveCurrent(updated)
        } catch {
            print("Failed to refresh: \(error)")
        }
    }
    
    @MainActor
    private func updateCloudGame() async {
        guard let g = game, let recordID = g.recordID else { return }
        
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            record["currentHole"] = g.currentHole
            record["scoresJSON"] = try! JSONEncoder().encode(g.scores)
            record["greenieValuesJSON"] = try? JSONEncoder().encode(g.greenieValues)
            record["processedPar3HolesJSON"] = try? JSONEncoder().encode(Array(g.processedPar3Holes))
            record["rulesJSON"] = try! JSONEncoder().encode(g.rules)
            record["isActive"] = g.isActive
            
            _ = try await database.save(record)
            print("✅ Cloud updated: Hole \(g.currentHole)")
        } catch {
            print("Failed to update cloud: \(error)")
        }
    }
    
    private func gameState(from record: CKRecord) -> GameState {
        let gameID = record["gameID"] as? String ?? ""
        let playersData = record["playersJSON"] as? Data ?? Data()
        let players = (try? JSONDecoder().decode([Player].self, from: playersData)) ?? []
        
        let rulesData = record["rulesJSON"] as? Data ?? Data()
        let rules = (try? JSONDecoder().decode(GameRules.self, from: rulesData)) ?? GameRules()
        
        let currentHole = record["currentHole"] as? Int ?? 1
        
        let scoresData = record["scoresJSON"] as? Data ?? Data()
        let scores = (try? JSONDecoder().decode([Int: [String: [String: Bool]]].self, from: scoresData)) ?? [:]
        
        let greenieValuesData = record["greenieValuesJSON"] as? Data ?? Data()
        let greenieValues = (try? JSONDecoder().decode([Int: Int].self, from: greenieValuesData)) ?? [:]
        
        let isActive = record["isActive"] as? Bool ?? false
        
        let joinedPlayerIDsData = record["joinedPlayerIDsJSON"] as? Data ?? Data()
        let joinedPlayerIDsArray = (try? JSONDecoder().decode([String].self, from: joinedPlayerIDsData)) ?? []
        let joinedPlayerIDs = Set(joinedPlayerIDsArray) // Convert array to Set
        
        let golfCourseData = record["golfCourseJSON"] as? Data
        let golfCourse = golfCourseData.flatMap { try? JSONDecoder().decode(GolfCourse.self, from: $0) }
        
        let courseDataJSON = record["courseDataJSON"] as? Data
        let courseData = courseDataJSON.flatMap { try? JSONDecoder().decode(GolfCourseData.self, from: $0) }
        
        let processedPar3HolesData = record["processedPar3HolesJSON"] as? Data ?? Data()
        let processedPar3HolesArray = (try? JSONDecoder().decode([Int].self, from: processedPar3HolesData)) ?? []
        let processedPar3Holes = Set(processedPar3HolesArray)
        
        return GameState(
            recordID: record.recordID.recordName,
            gameID: gameID,
            players: players,
            rules: rules,
            currentHole: currentHole,
            scores: scores,
            isActive: isActive,
            joinedPlayerIDs: joinedPlayerIDs,
            golfCourse: golfCourse,
            courseData: courseData,
            greenieValues: greenieValues,
            processedPar3Holes: processedPar3Holes
        )
    }
    
    // Rest of the methods remain the same...
    @MainActor
    func joinGame(code: String) async {
        isLoading = true
        
        let predicate = NSPredicate(format: "gameID == %@", code)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        do {
            let results = try await database.records(matching: query)
            
            if let record = results.matchResults.first?.1 {
                let ckRecord = try record.get()
                let gameState = self.gameState(from: ckRecord)
                
                game = gameState
                isMultiplayer = true
                joinCode = code
                isHost = false
                showWaitingRoom = !gameState.isActive
                persistence.saveCurrent(gameState)
                startListeningForChanges()
            }
        } catch {
            print("Failed to join: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func startGame() async {
        guard var g = game, let recordID = g.recordID else { return }
        
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            record["isActive"] = true
            
            _ = try await database.save(record)
            
            g.isActive = true
            game = g
            showWaitingRoom = false
            persistence.saveCurrent(g)
        } catch {
            print("Failed to start game: \(error)")
        }
    }
    
    func endGame() {
        showGameOver = true
        if let g = game {
            persistence.saveToHistory(g)
        }
    }
    
    func newRound() {
        game = nil
        isMultiplayer = false
        joinCode = ""
        showGameOver = false
        isHost = false
        showWaitingRoom = false
        persistence.clearCurrent()
    }
}
