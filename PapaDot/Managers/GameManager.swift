// Managers/GameManager.swift
import SwiftUI
import CloudKit

@Observable
final class GameManager {
    var game: GameState?
    var updateCounter = 0
    var isMultiplayer = false
    var joinCode = ""
    var showGameOver = false
    var isLoading = false
    var isHost = false
    var showWaitingRoom = false
    var showHistory = false
    var isOfflineMode = false

    private let container = CKContainer(identifier: "iCloud.com.jeffpaz.PapaDot")
    private var database: CKDatabase { container.privateCloudDatabase }
    private let recordType = "PapaDotGame"
    private let haptic = UIImpactFeedbackGenerator(style: .heavy)
    private let persistence = PersistenceManager()

    init() {
        if let saved = persistence.loadCurrent() {
            game = saved
            isMultiplayer = saved.recordID != nil
            joinCode = saved.gameID
            isHost = saved.recordID != nil
            showWaitingRoom = !saved.isActive
            startListeningForChanges()
        }
    }

    // MARK: - Create Game

    @MainActor
    func createGame(players: [Player], rules: GameRules, golfCourse: GolfCourse? = nil, courseData: GolfCourseData? = nil) async {
        isLoading = true
        let gameID = String(UUID().uuidString.prefix(6)).uppercased()
        let record = CKRecord(recordType: recordType)
        record["gameID"] = gameID

        guard let playersData = try? JSONEncoder().encode(players),
              let rulesData = try? JSONEncoder().encode(rules),
              let joinedData = try? JSONEncoder().encode([players.first?.id ?? ""]) else {
            isLoading = false; return
        }

        record["playersJSON"] = playersData
        record["rulesJSON"] = rulesData
        record["currentHole"] = 1
        record["isActive"] = false
        record["scoresJSON"] = Data()
        record["strokeScoresJSON"] = Data()
        record["joinedPlayerIDsJSON"] = joinedData
        if let c = golfCourse { record["golfCourseJSON"] = try? JSONEncoder().encode(c) }
        if let d = courseData { record["courseDataJSON"] = try? JSONEncoder().encode(d) }

        do {
            var saved: CKRecord?
            var attempts = 0
            while saved == nil && attempts < 3 {
                attempts += 1
                do { saved = try await database.save(record) }
                catch let e as CKError {
                    if attempts < 3 && (e.code == .networkUnavailable || e.code == .networkFailure) {
                        try? await Task.sleep(nanoseconds: 2_000_000_000); continue
                    }
                    throw e
                }
            }
            guard let r = saved else { throw CKError(.unknownItem) }
            let g = makeGame(recordID: r.recordID.recordName, gameID: gameID,
                             players: players, rules: rules, golfCourse: golfCourse, courseData: courseData)
            isOfflineMode = false
            finishSetup(g, host: true, multiplayer: true)
            startListeningForChanges()
        } catch {
            isOfflineMode = true
            let g = makeGame(recordID: nil, gameID: gameID,
                             players: players, rules: rules, golfCourse: golfCourse, courseData: courseData)
            finishSetup(g, host: true, multiplayer: false)
        }
        isLoading = false
    }

    private func makeGame(recordID: String?, gameID: String, players: [Player], rules: GameRules,
                          golfCourse: GolfCourse?, courseData: GolfCourseData?) -> GameState {
        GameState(recordID: recordID, gameID: gameID, players: players, rules: rules,
                  currentHole: 1, scores: [:], isActive: false,
                  joinedPlayerIDs: [players.first?.id ?? ""],
                  golfCourse: golfCourse, courseData: courseData,
                  greenieValues: [:], processedPar3Holes: [],
                  lowHoleValues: [:], processedLowHoleHoles: [])
    }

    // MARK: - Join Game

    @MainActor
    func joinGame(with code: String) async {
        isLoading = true
        guard code.count == 7 else { isLoading = false; return }
        let gameID = String(code.prefix(6))
        guard let playerIndex = Int(String(code.last ?? "0")) else { isLoading = false; return }

        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "gameID == %@", gameID))
        do {
            let results = try await database.records(matching: query)
            for (_, result) in results.matchResults {
                if case .success(let record) = result {
                    var fetched = gameState(from: record)
                    guard playerIndex < fetched.players.count else { isLoading = false; return }
                    fetched.joinedPlayerIDs.insert(fetched.players[playerIndex].id)
                    if let d = try? JSONEncoder().encode(fetched.joinedPlayerIDs) {
                        record["joinedPlayerIDsJSON"] = d
                        _ = try? await database.save(record)
                    }
                    finishSetup(fetched, host: false, multiplayer: true)
                    startListeningForChanges()
                    isLoading = false; return
                }
            }
        } catch { isOfflineMode = true }
        isLoading = false
    }

    @MainActor
    private func finishSetup(_ game: GameState, host: Bool, multiplayer: Bool) {
        self.game = game
        self.isMultiplayer = multiplayer
        self.joinCode = game.gameID
        self.isHost = host
        self.showWaitingRoom = true
        haptic.impactOccurred()
        persistence.saveCurrent(game)
        shareGameWithWidget()
    }

    // MARK: - Scoring

    /// Set stroke score (Low Hole will be calculated when moving to next hole)
    func setStrokeScore(playerName: String, hole: Int, strokes: Int) {
        guard var g = game, g.isActive else {
            print("⚠️ setStrokeScore blocked: game=\(game != nil), isActive=\(game?.isActive ?? false)")
            return
        }

        print("⛳️ Setting stroke score: \(playerName) hole \(hole) = \(strokes)")
        g.strokeScores[hole, default: [:]][playerName] = strokes
        print("⛳️ Stroke scores for hole \(hole): \(g.strokeScores[hole] ?? [:])")

        g.lastModified = Date()
        game = g
        updateCounter += 1
        haptic.impactOccurred()
        persistence.saveCurrent(g)
        shareGameWithWidget()
        Task { await updateCloudGame() }
    }

    /// Calculate net score and auto-award Low Hole to player with lowest net score
    /// If a player hasn't entered a score, assume they scored par
    private func autoAwardLowHole(game: inout GameState, hole: Int) {
        guard let holeData = game.courseData?.holes?.first(where: { $0.number == hole }) else {
            print("🏌️ Hole \(hole): No hole data found")
            return
        }

        print("\n🏌️ === Low Hole Calculation for Hole \(hole) ===")
        print("🏌️ Hole Par: \(holeData.par), Handicap Index: \(holeData.handicap ?? 0)")

        // Calculate net scores for ALL players (default to par if not entered)
        var netScores: [(player: Player, netScore: Int, grossScore: Int)] = []
        for player in game.players {
            // If no score entered, assume they scored par
            let grossScore = game.strokeScores[hole]?[player.name] ?? holeData.par

            let netScore = calculateNetScore(
                playerHandicap: player.handicap,
                grossScore: grossScore,
                holeHandicap: holeData.handicap ?? 10,
                holeNumber: hole
            )
            netScores.append((player, netScore, grossScore))

            if game.strokeScores[hole]?[player.name] == nil {
                print("🏌️ \(player.name): No score entered, assuming par \(holeData.par) → Net \(netScore)")
            } else {
                print("🏌️ \(player.name): Gross \(grossScore), HCP \(player.handicap), Net \(netScore)")
            }
        }

        // Find player(s) with lowest net score
        guard let lowestScore = netScores.map({ $0.netScore }).min() else { return }
        let winners = netScores.filter { $0.netScore == lowestScore }

        print("🏌️ ✅ Lowest Net Score: \(lowestScore)")

        // Only award if there's a single winner (no tie)
        if winners.count == 1 {
            let winner = winners[0]
            let carryoverValue = game.rules.currentLowHoleValue
            print("🏌️ 🏆 Winner: \(winner.player.name)")
            print("🏌️ 💎 Awarding \(carryoverValue) dot(s) (carryover value)")

            // Award Low Hole to the winner, clear for others
            for player in game.players {
                let shouldHaveLowHole = player.id == winner.player.id
                game.scores[hole, default: [:]][player.name, default: [:]]["Low Hole"] = shouldHaveLowHole

                // Store the value for this hole
                if shouldHaveLowHole {
                    game.lowHoleValues[hole] = game.rules.currentLowHoleValue
                    print("🏌️ 📝 Stored lowHoleValues[\(hole)] = \(game.rules.currentLowHoleValue)")
                }

                print("🏌️   \(player.name): Low Hole = \(shouldHaveLowHole)")
            }
        } else {
            // Tie - no one wins, carryover continues
            let tiedNames = winners.map { $0.player.name }.joined(separator: ", ")
            print("🏌️ 🤝 TIE: \(tiedNames)")
            print("🏌️ 💎 No winner - Low Hole carries over (no one awarded)")

            // Clear Low Hole for all players
            for player in game.players {
                game.scores[hole, default: [:]][player.name, default: [:]]["Low Hole"] = false
                print("🏌️   \(player.name): Low Hole = false")
            }
        }
        print("🏌️ === End Low Hole Calculation ===\n")
    }

    /// Calculate net score for a player on a specific hole
    private func calculateNetScore(playerHandicap: Int, grossScore: Int, holeHandicap: Int, holeNumber: Int) -> Int {
        guard playerHandicap > 0 else { return grossScore }

        // Calculate strokes received on this hole
        let strokesPerHole = playerHandicap / 18
        let extraStrokeHoles = playerHandicap % 18
        let strokesReceived = strokesPerHole + (holeHandicap <= extraStrokeHoles ? 1 : 0)

        return max(1, grossScore - strokesReceived)
    }

    /// Recalculate Low Hole carryover value from scratch based on holes played so far
    private func recalculateLowHoleCarryover(game: inout GameState, upToHole: Int) {
        let basePoints = game.rules.tasks.first(where: { $0.name == "Low Hole" })?.points ?? 2
        var carryover = basePoints

        print("🔄 Recalculating Low Hole carryover from holes 1 to \(upToHole)")

        for hole in 1...upToHole {
            let someoneWon = game.scores[hole]?.values.contains { $0["Low Hole"] == true } ?? false

            if someoneWon {
                print("🔄 Hole \(hole): Someone won - reset carryover to \(basePoints)")
                carryover = basePoints
            } else {
                print("🔄 Hole \(hole): No winner (tie) - carryover += \(basePoints) = \(carryover + basePoints)")
                carryover += basePoints
            }
        }

        game.rules.currentLowHoleValue = carryover
        print("🔄 Final carryover value: \(carryover)")
    }

    func toggleScore(playerName: String, hole: Int, task: String) {
        guard var g = game, g.isActive else { return }
        let wasOn = g.scores[hole]?[playerName]?[task] ?? false
        g.scores[hole, default: [:]][playerName, default: [:]][task] = !wasOn

        // Store current value for carry-over tasks when scored
        if task == "Greenie" && !wasOn {
            g.greenieValues[hole] = g.rules.currentGreenieValue
        }
        if task == "Low Hole" && !wasOn {
            g.lowHoleValues[hole] = g.rules.currentLowHoleValue
        }

        // Handle exclusive tasks (works for both individual and team mode)
        // In team mode, this ensures Low Hole is exclusive across all players
        if let taskObj = g.rules.tasks.first(where: { $0.name == task }), taskObj.isExclusive && !wasOn {
            for p in g.players where p.name != playerName {
                g.scores[hole, default: [:]][p.name, default: [:]][task] = false
            }
        }

        g.lastModified = Date() // Update timestamp to ensure this is authoritative over sync
        game = g
        updateCounter += 1
        haptic.impactOccurred()
        persistence.saveCurrent(g)
        shareGameWithWidget()
        Task { await updateCloudGame() }
    }

    func setHole(_ hole: Int) {
        guard var g = game else { return }

        // When moving forward, calculate Low Hole for the hole we're leaving
        if hole > g.currentHole {
            print("🎯 Moving from hole \(g.currentHole) to \(hole) - calculating Low Hole")
            autoAwardLowHole(game: &g, hole: g.currentHole)

            // CRITICAL: Update game state immediately so Low Hole changes are persisted
            game = g
            updateCounter += 1
            print("✅ Low Hole changes committed to game state, updateCounter = \(updateCounter)")

            // Check carry-over for tasks on the hole we're leaving
            if g.rules.par3Holes.contains(g.currentHole) {
                checkAndUpdateGreenieValue(forHole: g.currentHole)
                guard let updated = game else { return }
                g = updated
            }
            checkAndUpdateLowHoleValue(forHole: g.currentHole)
            guard let updated = game else { return }
            g = updated
        } else if hole < g.currentHole {
            // When moving backwards, clear the current hole and recalculate carryover
            print("⬅️ Moving backwards from hole \(g.currentHole) to \(hole)")

            // Remove current hole from processed sets so it can be recalculated later
            g.processedLowHoleHoles.remove(g.currentHole)
            g.processedPar3Holes.remove(g.currentHole)

            // Clear stored values for this hole
            g.lowHoleValues[g.currentHole] = nil
            g.greenieValues[g.currentHole] = nil

            // Recalculate carryover value based on all previous holes
            recalculateLowHoleCarryover(game: &g, upToHole: hole)

            game = g
            updateCounter += 1
            persistence.saveCurrent(g)
            print("✅ Carryover recalculated, currentLowHoleValue = \(g.rules.currentLowHoleValue)")
        }

        g.currentHole = min(18, max(1, hole))
        g.lastModified = Date() // Update timestamp to ensure this is authoritative over sync
        game = g
        persistence.saveCurrent(g) // CRITICAL: Persist BEFORE async CloudKit call
        shareGameWithWidget()
        if g.currentHole == 18 && !showGameOver && hole > 18 {
            showGameOver = true
            persistence.saveToHistory(g)
            clearWidgetData()
        }
        Task { await updateCloudGame() }
    }

    private func checkAndUpdateGreenieValue(forHole hole: Int) {
        guard var g = game, g.rules.par3Holes.contains(hole), !g.processedPar3Holes.contains(hole) else { return }
        let someoneGot = g.scores[hole]?.values.contains { $0["Greenie"] == true } ?? false

        // Get the base points from the Greenie task
        let basePoints = g.rules.tasks.first(where: { $0.name == "Greenie" })?.points ?? 1

        // If won, reset to base points. If not won, add base points (carry over)
        g.rules.currentGreenieValue = someoneGot ? basePoints : g.rules.currentGreenieValue + basePoints
        g.processedPar3Holes.insert(hole)
        game = g
        persistence.saveCurrent(g)
        Task { await updateCloudGame() }
    }

    private func checkAndUpdateLowHoleValue(forHole hole: Int) {
        guard var g = game, !g.processedLowHoleHoles.contains(hole) else { return }
        let someoneGot = g.scores[hole]?.values.contains { $0["Low Hole"] == true } ?? false

        // Get the base points from the Low Hole task
        let basePoints = g.rules.tasks.first(where: { $0.name == "Low Hole" })?.points ?? 1

        // If won, reset to base points. If not won, add base points (carry over)
        g.rules.currentLowHoleValue = someoneGot ? basePoints : g.rules.currentLowHoleValue + basePoints
        g.processedLowHoleHoles.insert(hole)
        game = g
        persistence.saveCurrent(g)
        Task { await updateCloudGame() }
    }

    // MARK: - Side Bets

    func addSideBet(_ bet: SideBet) {
        guard var g = game else { return }
        g.sideBets.append(bet)
        game = g
        persistence.saveCurrent(g)
        Task { await updateCloudGame() }
    }

    func settleSideBet(id: String, winner: String) {
        guard var g = game, let idx = g.sideBets.firstIndex(where: { $0.id == id }) else { return }
        g.sideBets[idx].winnerId = winner
        g.sideBets[idx].status = .settled
        g.sideBets[idx].settledDate = Date()
        game = g
        persistence.saveCurrent(g)
        Task { await updateCloudGame() }
    }

    func deleteSideBet(id: String) {
        guard var g = game else { return }
        g.sideBets.removeAll { $0.id == id }
        game = g
        persistence.saveCurrent(g)
        Task { await updateCloudGame() }
    }

    // MARK: - CloudKit Sync

    @MainActor
    func updateCloudGame() async {
        guard let g = game, let recordID = g.recordID, !isOfflineMode else { return }
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            if let d = try? JSONEncoder().encode(g.scores) { record["scoresJSON"] = d }
            if let d = try? JSONEncoder().encode(g.strokeScores) { record["strokeScoresJSON"] = d }
            record["currentHole"] = g.currentHole
            record["isActive"] = g.isActive
            if let d = try? JSONEncoder().encode(g.rules) { record["rulesJSON"] = d }
            if let d = try? JSONEncoder().encode(g.greenieValues) { record["greenieValuesJSON"] = d }
            if let d = try? JSONEncoder().encode(Array(g.processedPar3Holes)) { record["processedPar3HolesJSON"] = d }
            if let d = try? JSONEncoder().encode(g.lowHoleValues) { record["lowHoleValuesJSON"] = d }
            if let d = try? JSONEncoder().encode(Array(g.processedLowHoleHoles)) { record["processedLowHoleHolesJSON"] = d }
            if let d = try? JSONEncoder().encode(g.holePhotos) { record["photosJSON"] = d }
            if let d = try? JSONEncoder().encode(g.sideBets) { record["sideBetsJSON"] = d }
            _ = try await database.save(record)
        } catch { print("⚠️ CloudKit update failed: \(error)") }
    }

    func startListeningForChanges() {
        guard !isOfflineMode else { return }
        Task {
            while game != nil && !isOfflineMode {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await fetchLatestGame()
            }
        }
    }

    @MainActor
    private func fetchLatestGame() async {
        guard let g = game, let recordID = g.recordID else { return }
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            let latest = gameState(from: record)

            // CRITICAL: Only update if the fetched game matches our current game ID
            // and has a newer timestamp. NEVER set game = nil.
            guard latest.gameID == g.gameID else {
                print("⚠️ Ignoring sync - gameID mismatch (local: \(g.gameID), remote: \(latest.gameID))")
                return
            }

            guard latest.lastModified > g.lastModified else {
                print("⏭️ Ignoring sync - stale data (local: \(g.lastModified), remote: \(latest.lastModified))")
                return
            }

            // CRITICAL: Never allow currentHole to move backwards via sync
            // The host's local setHole() call is authoritative
            var updatedGame = latest
            if latest.currentHole < g.currentHole {
                print("🛡️ Preventing hole from moving backwards (local: \(g.currentHole), remote: \(latest.currentHole))")
                updatedGame.currentHole = g.currentHole
            }

            // Check if game became active - if so, hide waiting room
            if !g.isActive && updatedGame.isActive {
                showWaitingRoom = false
            }

            game = updatedGame
            persistence.saveCurrent(updatedGame)
            shareGameWithWidget()
        } catch {
            print("⚠️ Fetch failed: \(error)")
            // CRITICAL: On network error, DO NOT reset game state - keep playing locally
        }
    }

    func gameState(from record: CKRecord) -> GameState {
        func decode<T: Decodable>(_ t: T.Type, _ key: String) -> T? {
            guard let d = record[key] as? Data else { return nil }
            return try? JSONDecoder().decode(t, from: d)
        }
        return GameState(
            recordID: record.recordID.recordName,
            gameID: record["gameID"] as? String ?? "",
            players: decode([Player].self, "playersJSON") ?? [],
            rules: decode(GameRules.self, "rulesJSON") ?? GameRules(),
            currentHole: record["currentHole"] as? Int ?? 1,
            scores: decode([Int: [String: [String: Bool]]].self, "scoresJSON") ?? [:],
            strokeScores: decode([Int: [String: Int]].self, "strokeScoresJSON") ?? [:],
            isActive: record["isActive"] as? Bool ?? false,
            joinedPlayerIDs: decode(Set<String>.self, "joinedPlayerIDsJSON") ?? [],
            golfCourse: decode(GolfCourse.self, "golfCourseJSON"),
            courseData: decode(GolfCourseData.self, "courseDataJSON"),
            greenieValues: decode([Int: Int].self, "greenieValuesJSON") ?? [:],
            processedPar3Holes: Set(decode([Int].self, "processedPar3HolesJSON") ?? []),
            lowHoleValues: decode([Int: Int].self, "lowHoleValuesJSON") ?? [:],
            processedLowHoleHoles: Set(decode([Int].self, "processedLowHoleHolesJSON") ?? []),
            holePhotos: decode([HolePhoto].self, "photosJSON") ?? [],
            sideBets: decode([SideBet].self, "sideBetsJSON") ?? []
        )
    }

    // MARK: - Game Lifecycle

    /// Called directly by WaitingRoomView
    func startRound() {
        guard var g = game, isHost else { return }
        g.isActive = true
        game = g
        showWaitingRoom = false
        persistence.saveCurrent(g)
        Task { await updateCloudGame() }
    }

    @MainActor
    func startGame() async {
        guard var g = game, isHost else { return }

        // Offline mode or no CloudKit record — start locally without syncing
        guard let recordID = g.recordID else {
            g.isActive = true
            game = g
            showWaitingRoom = false
            persistence.saveCurrent(g)
            print("🎮 Game started in offline mode")
            return
        }

        // Online — update CloudKit then start
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            record["isActive"] = true
            _ = try await database.save(record)
            g.isActive = true; game = g
            showWaitingRoom = false
            persistence.saveCurrent(g)
        } catch {
            // CloudKit failed — start locally anyway so the game isn't blocked
            g.isActive = true; game = g
            showWaitingRoom = false
            persistence.saveCurrent(g)
            print("⚠️ CloudKit update failed, started locally: \(error)")
        }
    }

    func startNewGame() {
        persistence.clearCurrent(); clearWidgetData()
        game = nil; showWaitingRoom = false; showGameOver = false
        isMultiplayer = false; isHost = false; joinCode = ""
        showHistory = false; isOfflineMode = false
    }

    func newRound() { startNewGame() }

    func addPhoto(_ photo: HolePhoto) {
        guard var g = game else { return }
        g.holePhotos.append(photo); game = g
        persistence.saveCurrent(g); Task { await updateCloudGame() }
    }

    func removePhoto(id: String) {
        guard var g = game else { return }
        g.holePhotos.removeAll { $0.id == id }; game = g
        persistence.saveCurrent(g); Task { await updateCloudGame() }
    }
}
