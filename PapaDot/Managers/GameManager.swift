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
    var isOfflineMode = false  // NEW: Track if CloudKit is unavailable
    
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
        record["joinedPlayerIDsJSON"] = try! JSONEncoder().encode([players.first!.id]) // Host is auto-joined
        
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
                joinedPlayerIDs: [players.first!.id],
                golfCourse: golfCourse,
                courseData: courseData,
                greenieValues: [:],
                processedPar3Holes: []
            )
            isOfflineMode = false  // CloudKit worked!
            finishSetup(newGame, host: true)
            startListeningForChanges()
        } catch {
            print("⚠️ CloudKit unavailable - running in OFFLINE MODE")
            print("Error: \(error)")
            // Create local game without CloudKit sync
            let local = GameState(
                recordID: nil,
                gameID: gameID,
                players: players,
                rules: rules,
                currentHole: 1,
                scores: [:],
                isActive: false,
                joinedPlayerIDs: [players.first!.id],
                golfCourse: golfCourse,
                courseData: courseData,
                greenieValues: [:],
                processedPar3Holes: []
            )
            isOfflineMode = true  // Mark as offline
            finishSetup(local, host: true)
            // Don't start listening for changes in offline mode
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
                    _ = try? await database.save(record)
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
            print("⚠️ CloudKit unavailable - cannot join games in offline mode")
            isOfflineMode = true
        }
        
        isLoading = false
    }
    
    private func finishSetup(_ game: GameState, host: Bool) {
        self.game = game
        self.isMultiplayer = true
        self.joinCode = game.gameID
        self.isHost = host
        self.showWaitingRoom = true
        print("🎮 Game setup complete - Host: \(host), Offline: \(isOfflineMode), GameID: \(game.gameID)")
        haptic.impactOccurred()
        persistence.saveCurrent(game)
    }
    
    func startRound() {
        print("🎬 START ROUND CALLED - isHost: \(isHost), game exists: \(game != nil)")
        guard var g = game, isHost else {
            print("❌ Cannot start - not host or no game")
            return
        }
        print("✅ Starting round - setting active")
        g.isActive = true
        game = g
        showWaitingRoom = false
        print("🚪 showWaitingRoom = false, game.isActive = true")
        persistence.saveCurrent(g)
        Task { await updateCloudGame() }
    }
    
    // MARK: - Greenie Logic Integration
    func toggleScore(playerName: String, hole: Int, task: String) {
        guard var g = game, g.isActive else { return }
        let wasOn = g.scores[hole]?[playerName]?[task] ?? false
        g.scores[hole, default: [:]][playerName, default: [:]][task] = !wasOn
        
        // CRITICAL: If toggling ON a greenie, store the current greenie value for this hole
        if task == "Greenie" && !wasOn {
            g.greenieValues[hole] = g.rules.currentGreenieValue
            print("💎 Greenie scored on hole \(hole) - worth \(g.rules.currentGreenieValue) points")
        }
        
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
        
        print("🎯 Moving from hole \(g.currentHole) to hole \(hole)")
        print("   Par 3 holes: \(g.rules.par3Holes)")
        print("   Current greenie value: \(g.rules.currentGreenieValue)")
        
        // Only check greenie value when moving forward from a par 3
        if hole > g.currentHole {
            print("   ✅ Moving forward")
            if g.rules.par3Holes.contains(g.currentHole) {
                print("   ✅ Hole \(g.currentHole) IS a par 3!")
                // Always process greenie when leaving a par 3, even if no scores marked
                checkAndUpdateGreenieValue(forHole: g.currentHole)
                
                // CRITICAL: Get fresh copy after greenie update!
                guard let updated = game else { return }
                g = updated
                print("   🔄 Refreshed game copy - greenie value now: \(g.rules.currentGreenieValue)")
            } else {
                print("   ❌ Hole \(g.currentHole) is NOT a par 3")
            }
        } else {
            print("   ⏪ Moving backward or staying on same hole")
        }
        
        // Update hole number
        g.currentHole = min(18, max(1, hole))
        game = g
        persistence.saveCurrent(g)
        
        print("   📍 Now on hole \(g.currentHole)")
        
        // Show game over if finishing hole 18
        if g.currentHole == 18 && !showGameOver && hole > 18 {
            showGameOver = true
            persistence.saveToHistory(g)
        }
        
        Task { await updateCloudGame() }
    }
    
    private func checkAndUpdateGreenieValue(forHole hole: Int) {
        print("🟢 Checking greenie for hole \(hole)")
        
        // Get a mutable copy
        guard var g = game else { return }
        
        // Only process if this was a par 3 hole
        guard g.rules.par3Holes.contains(hole) else {
            print("   ❌ Not a par 3 hole")
            return
        }
        
        print("   ✅ Is a par 3 - current greenie value: \(g.rules.currentGreenieValue)")
        
        // Check if anyone got a greenie on this hole
        let scores = g.scores[hole] ?? [:]
        var someoneGotGreenie = false
        
        print("   📊 Scores on hole: \(scores)")
        
        for (_, tasks) in scores {
            if tasks["Greenie"] == true {
                someoneGotGreenie = true
                break
            }
        }
        
        print("   Someone got greenie: \(someoneGotGreenie)")
        
        // Modify the COPY
        if !someoneGotGreenie {
            g.rules.currentGreenieValue += 1
            print("   ⬆️ Incremented greenie value to: \(g.rules.currentGreenieValue)")
        } else {
            g.rules.currentGreenieValue = 1
            print("   ♻️ Reset greenie value to: 1")
        }
        
        // CRITICAL: Assign back to game BEFORE any other operations
        game = g
        print("   💾 Assigned back to game - value: \(game!.rules.currentGreenieValue)")
        
        // Now save
        persistence.saveCurrent(game!)
        print("   💿 Saved to persistence")
        
        Task { await updateCloudGame() }
    }
    
    // MARK: - Photo Management
    
    func addPhoto(_ image: UIImage, forHole hole: Int, caption: String?) {
        guard var g = game else { return }
        
        let photo = HolePhoto(holeNumber: hole, image: image, caption: caption)
        g.holePhotos.append(photo)
        game = g
        persistence.saveCurrent(g)
        
        print("📸 Photo added for hole \(hole)")
        
        // Upload to CloudKit (only if online)
        if !isOfflineMode {
            Task {
                await uploadPhotos()
            }
        }
    }
    
    func deletePhoto(_ photo: HolePhoto) {
        guard var g = game else { return }
        
        g.holePhotos.removeAll { $0.id == photo.id }
        game = g
        persistence.saveCurrent(g)
        
        // Update CloudKit
        if !isOfflineMode {
            Task {
                await uploadPhotos()
            }
        }
    }
    
    private func uploadPhotos() async {
        guard let g = game, let recordID = g.recordID else { return }
        
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            
            // Encode photos to JSON
            let photosData = try? JSONEncoder().encode(g.holePhotos)
            record["photosJSON"] = photosData
            
            _ = try await database.save(record)
            print("✅ Photos uploaded to CloudKit")
        } catch {
            print("❌ Failed to upload photos: \(error)")
        }
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
        
        let subscriptionID = "game-updates-\(recordID)"
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: NSPredicate(format: "recordName == %@", recordID),
            subscriptionID: subscriptionID,
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
        let greenieValuesData = record["greenieValuesJSON"] as? Data ?? Data()
        let processedPar3HolesData = record["processedPar3HolesJSON"] as? Data ?? Data()
        
        let players = (try? JSONDecoder().decode([Player].self, from: playersData)) ?? []
        let rules = (try? JSONDecoder().decode(GameRules.self, from: rulesData)) ?? GameRules()
        let currentHole = record["currentHole"] as? Int ?? 1
        let isActive = record["isActive"] as? Bool ?? false
        let scores = (try? JSONDecoder().decode([Int: [String: [String: Bool]]].self, from: scoresData)) ?? [:]
        let joinedIDs = (try? JSONDecoder().decode(Set<String>.self, from: joinedIDsData)) ?? []
        let greenieValues = (try? JSONDecoder().decode([Int: Int].self, from: greenieValuesData)) ?? [:]
        let processedPar3HolesArray = (try? JSONDecoder().decode([Int].self, from: processedPar3HolesData)) ?? []
        let processedPar3Holes = Set(processedPar3HolesArray)
        
        // Load golf course if present
        let golfCourseData = record["golfCourseJSON"] as? Data
        let golfCourse = golfCourseData.flatMap { try? JSONDecoder().decode(GolfCourse.self, from: $0) }
        
        // Load course data if present
        let courseDataJSON = record["courseDataJSON"] as? Data
        let courseData = courseDataJSON.flatMap { try? JSONDecoder().decode(GolfCourseData.self, from: $0) }
        
        // Load photos if present
        let photosData = record["photosJSON"] as? Data ?? Data()
        let holePhotos = (try? JSONDecoder().decode([HolePhoto].self, from: photosData)) ?? []
        
        return GameState(
            recordID: record.recordID.recordName,
            gameID: gameID,
            players: players,
            rules: rules,
            currentHole: currentHole,
            scores: scores,
            isActive: isActive,
            joinedPlayerIDs: joinedIDs,
            golfCourse: golfCourse,
            courseData: courseData,
            greenieValues: greenieValues,
            processedPar3Holes: processedPar3Holes,
            holePhotos: holePhotos
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
        isOfflineMode = false
    }
    
    // Alias for startNewGame (for compatibility)
    func newRound() {
        startNewGame()
    }
    
    // Start the game (host only) - marks game as active
    @MainActor
    func startGame() async {
        guard var g = game, isHost, let recordID = g.recordID else { return }
        
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
            // In offline mode, just start locally
            g.isActive = true
            game = g
            showWaitingRoom = false
            persistence.saveCurrent(g)
        }
    }
}
