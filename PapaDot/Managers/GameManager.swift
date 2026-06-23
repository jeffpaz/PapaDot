// Managers/GameManager.swift
import SwiftUI
import CloudKit
import UIKit
import Network

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
    /// Set when joinGame fails; cleared on each new attempt and on code change in JoinGameView.
    var joinError: String?

    private let container = CKContainer(identifier: "iCloud.com.jeffpaz.PapaDot")
    private var database: CKDatabase { container.privateCloudDatabase }
    private let recordType = "PapaDotGame"
    private let haptic = UIImpactFeedbackGenerator(style: .heavy)
    private let persistence = PersistenceManager()
    private var syncTask: Task<Void, Never>?
    private var pendingCloudSync: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var hasPendingLocalChanges = false
    // True while a CloudKit save is awaiting database.save() — blocks fetch from overwriting
    private var isSaving = false
    // Prevents startListeningForChanges from spawning duplicate polling loops
    private var isPolling = false
    // Belt-and-suspenders guard against saveToHistory being called more than once per game
    private var historySaved = false
    // Monitors network path to upload an offline-created game when connectivity is restored
    private var networkMonitor: NWPathMonitor?

    init() {
        guard let saved = persistence.loadCurrent(),
              GameManager.isValidRestoredState(saved) else {
            // Discard corrupted or unusable persisted state rather than crashing on it
            persistence.clearCurrent()
            return
        }
        game = saved
        isMultiplayer = saved.recordID != nil
        joinCode = saved.gameID
        isHost = saved.recordID != nil
        showWaitingRoom = !saved.isActive
        Task { @MainActor in self.startListeningForChanges() }
        // If the game was created offline, resume watching for connectivity so we
        // can upload it to CloudKit the moment the network becomes available.
        if saved.recordID == nil {
            startNetworkMonitorForOfflineGame()
        }
    }

    /// Returns false for states that would cause immediate crashes or corrupt data.
    private static func isValidRestoredState(_ g: GameState) -> Bool {
        !g.gameID.isEmpty &&
        !g.players.isEmpty &&
        (1...18).contains(g.currentHole)
    }

    // MARK: - Create Game

    @MainActor
    func createGame(players: [Player], rules: GameRules, golfCourse: GolfCourse? = nil, courseData: GolfCourseData? = nil) async {
        isLoading = true

        // Stamp lastUsedHandicap so history lookup pre-populates handicaps in future games
        var stampedPlayers = players
        for i in stampedPlayers.indices { stampedPlayers[i].lastUsedHandicap = stampedPlayers[i].handicap }

        let gameID = String(UUID().uuidString.prefix(6)).uppercased()
        let record = CKRecord(recordType: recordType)
        record["gameID"] = gameID

        guard let playersData = try? JSONEncoder().encode(stampedPlayers),
              let rulesData = try? JSONEncoder().encode(rules),
              let joinedData = try? JSONEncoder().encode([stampedPlayers.first?.id ?? ""]) else {
            isLoading = false; return
        }

        record["playersJSON"] = playersData
        record["rulesJSON"] = rulesData
        record["currentHole"] = rules.startingHole
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
                             players: stampedPlayers, rules: rules, golfCourse: golfCourse, courseData: courseData)
            isOfflineMode = false
            finishSetup(g, host: true, multiplayer: true)
            startListeningForChanges()
        } catch {
            isOfflineMode = true
            let g = makeGame(recordID: nil, gameID: gameID,
                             players: stampedPlayers, rules: rules, golfCourse: golfCourse, courseData: courseData)
            finishSetup(g, host: true, multiplayer: false)
            // Watch for connectivity so we can upload this game to CloudKit once online
            startNetworkMonitorForOfflineGame()
        }
        isLoading = false
    }

    /// Scans game history to find the most recently used handicap for a player.
    /// Returns nil if the player has no history — callers should default to 10.
    func lookupLastHandicap(name: String, phone: String) -> Int? {
        let history = persistence.loadHistory()
        for game in history {
            guard let player = game.players.first(where: {
                (!phone.isEmpty && $0.phoneNumber == phone) || $0.name == name
            }) else { continue }
            // lastUsedHandicap >= 0: field was explicitly saved (0 = scratch, positive = normal).
            // lastUsedHandicap == -1: field was absent in an old record; fall back to handicap,
            // and return nil if that is also 0 so callers apply their ?? 10 default.
            if player.lastUsedHandicap >= 0 { return player.lastUsedHandicap }
            return player.handicap > 0 ? player.handicap : nil
        }
        return nil
    }

    private func makeGame(recordID: String?, gameID: String, players: [Player], rules: GameRules,
                          golfCourse: GolfCourse?, courseData: GolfCourseData?) -> GameState {
        GameState(recordID: recordID, gameID: gameID, players: players, rules: rules,
                  currentHole: rules.startingHole, scores: [:], isActive: false,
                  joinedPlayerIDs: [players.first?.id ?? ""],
                  golfCourse: golfCourse, courseData: courseData,
                  greenieValues: [:], processedPar3Holes: [],
                  lowHoleValues: [:], processedLowHoleHoles: [])
    }

    // MARK: - Join Game

    @MainActor
    func joinGame(with code: String) async {
        joinError = nil
        guard code.count == 7 else {
            joinError = "Enter the full 7-character code."
            return
        }
        guard let playerIndex = Int(String(code.last ?? "X")), playerIndex >= 0 else {
            joinError = "Invalid join code. Check the code and try again."
            return
        }

        isLoading = true
        let gameID = String(code.prefix(6))
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "gameID == %@", gameID))

        do {
            let results = try await database.records(matching: query)
            var matched = false

            for (_, result) in results.matchResults {
                guard case .success(let record) = result else { continue }
                matched = true

                var fetched = gameState(from: record)
                guard playerIndex < fetched.players.count else {
                    isLoading = false
                    joinError = "Invalid join code. Check the code and try again."
                    return
                }

                let playerID = fetched.players[playerIndex].id
                let alreadyJoined = fetched.joinedPlayerIDs.contains(playerID)

                if !alreadyJoined {
                    fetched.joinedPlayerIDs.insert(playerID)
                    if let d = try? JSONEncoder().encode(fetched.joinedPlayerIDs) {
                        record["joinedPlayerIDsJSON"] = d
                        _ = try? await database.save(record)
                    }
                }

                finishSetup(fetched, host: false, multiplayer: true)

                // If the host started the round before this player joined, skip the
                // waiting room and land directly in the scoring view.
                if fetched.isActive {
                    showWaitingRoom = false
                }

                startListeningForChanges()
                isLoading = false
                return
            }

            if !matched {
                joinError = "Game not found. Check your code or ask the host for a new invite."
            }
        } catch let e as CKError where e.code == .networkUnavailable || e.code == .networkFailure {
            joinError = "No connection. Check your network and try again."
        } catch {
            joinError = "Could not join. Check your code and connection, then try again."
        }
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

    @MainActor
    func setStrokeScore(playerName: String, hole: Int, strokes: Int) {
        guard var g = game, g.isActive else { return }
        g.strokeScores[hole, default: [:]][playerName] = strokes
        g.lastModified = Date()
        game = g
        updateCounter += 1
        haptic.impactOccurred()
        persistence.saveCurrent(g)
        shareGameWithWidget()
        scheduleCloudSync()
    }

    /// Auto-award Low Hole to the player with the lowest net score on the given hole.
    /// Players without a stroke score are assumed to have scored par (defaults to 4 when no course data).
    private func autoAwardLowHole(game: inout GameState, hole: Int) {
        let holePar = game.courseData?.holes?.first(where: { $0.number == hole })?.par ?? 4

        var netScores: [(player: Player, netScore: Int)] = []
        for player in game.players {
            let grossScore = game.strokeScores[hole]?[player.name] ?? holePar
            let netScore = game.rules.useHandicap
                ? calculateNetScore(
                    playerHandicap: player.handicap,
                    grossScore: grossScore,
                    holeNumber: hole,
                    holePar: holePar,
                    courseData: game.courseData
                )
                : grossScore
            netScores.append((player, netScore))
        }

        guard let lowestScore = netScores.map({ $0.netScore }).min() else { return }
        let winners = netScores.filter { $0.netScore == lowestScore }

        if winners.count == 1 {
            let winner = winners[0]
            let lowHoleTask = game.rules.tasks.first(where: { $0.name == "Low Hole" })
            let lhBasePoints = max(1, lowHoleTask?.points ?? 1)
            for player in game.players {
                let shouldHaveLowHole = player.id == winner.player.id
                game.scores[hole, default: [:]][player.name, default: [:]]["Low Hole"] = shouldHaveLowHole
                if shouldHaveLowHole {
                    game.lowHoleValues[hole] = cappedLowHolePayout(task: lowHoleTask, currentValue: game.rules.currentLowHoleValue, basePoints: lhBasePoints)
                }
            }
        } else {
            // Tie — no one wins; carryover continues
            for player in game.players {
                game.scores[hole, default: [:]][player.name, default: [:]]["Low Hole"] = false
            }
        }
    }

    /// Auto-award Team Low to the team with the lowest best net score on the given hole.
    private func autoAwardTeamLow(game: inout GameState, hole: Int) {
        guard game.rules.isTeamMode, game.players.count == 4 else { return }
        let holePar = game.courseData?.holes?.first(where: { $0.number == hole })?.par ?? 4

        var bestNetByTeam: [String: Int] = [:]
        for player in game.players {
            guard let team = game.teamForPlayer(player) else { continue }
            let gross = game.strokeScores[hole]?[player.name] ?? holePar
            let net = game.rules.useHandicap
                ? calculateNetScore(playerHandicap: player.handicap, grossScore: gross,
                                    holeNumber: hole, holePar: holePar, courseData: game.courseData)
                : gross
            if let existing = bestNetByTeam[team] {
                bestNetByTeam[team] = min(existing, net)
            } else {
                bestNetByTeam[team] = net
            }
        }

        let aScore = bestNetByTeam["A"] ?? Int.max
        let bScore = bestNetByTeam["B"] ?? Int.max
        if aScore < bScore {
            game.teamLowWinner[hole] = "A"
        } else if bScore < aScore {
            game.teamLowWinner[hole] = "B"
        } else {
            game.teamLowWinner[hole] = nil  // tie
        }
    }

    /// Calculate net score for a player on a specific hole.
    /// Par 3 holes receive no handicap strokes. Strokes are distributed only among non-par-3 holes
    /// that have handicap stroke-index data; holes missing that data receive no strokes.
    private func calculateNetScore(playerHandicap: Int, grossScore: Int, holeNumber: Int, holePar: Int, courseData: GolfCourseData?) -> Int {
        guard playerHandicap > 0 else { return grossScore }
        guard holePar != 3 else { return grossScore }
        guard let allHoles = courseData?.holes else { return grossScore }

        let nonPar3 = allHoles.filter { $0.par != 3 && $0.handicap != nil }
                              .sorted { $0.handicap! < $1.handicap! }
        guard !nonPar3.isEmpty, let rankIndex = nonPar3.firstIndex(where: { $0.number == holeNumber }) else {
            return grossScore
        }
        let rank = rankIndex + 1
        let strokesReceived = playerHandicap / nonPar3.count + (rank <= playerHandicap % nonPar3.count ? 1 : 0)
        return max(1, grossScore - strokesReceived)
    }

    /// Recalculate Low Hole carryover in play order from startingHole up to and including `upToHole`.
    private func recalculateLowHoleCarryover(game: inout GameState, upToHole: Int) {
        let lowHoleTask = game.rules.tasks.first(where: { $0.name == "Low Hole" })
        let basePoints = max(1, lowHoleTask?.points ?? 2)
        var carryover = basePoints

        for hole in holePlaySequence(startingHole: game.rules.startingHole, throughHole: upToHole) {
            let someoneWon = game.scores[hole]?.values.contains { $0["Low Hole"] == true } ?? false
            if someoneWon {
                let result = calculateCarryOverResult(
                    holesCarried: carryover / basePoints - 1,
                    pointValue: basePoints,
                    limitEnabled: lowHoleTask?.carryOverLimitEnabled ?? false,
                    limit: lowHoleTask?.carryOverLimit ?? 3,
                    resetToZero: lowHoleTask?.carryOverResetToZero ?? false
                )
                game.lowHoleValues[hole] = result.payout
                carryover = result.newCarryOver
            } else {
                game.lowHoleValues[hole] = nil
                if lowHoleTask?.hasCarryOver == true {
                    carryover += basePoints
                }
            }
        }

        game.rules.currentLowHoleValue = carryover
    }

    /// Recalculate Greenie carryover in play order from startingHole up to and including `upToHole`.
    private func recalculateGreenieCarryover(game: inout GameState, upToHole: Int) {
        let basePoints = game.rules.tasks.first(where: { $0.name == "Greenie" })?.points ?? 1
        var carryover = basePoints

        for hole in holePlaySequence(startingHole: game.rules.startingHole, throughHole: upToHole) {
            guard game.rules.par3Holes.contains(hole) else { continue }
            let someoneWon = game.scores[hole]?.values.contains { $0["Greenie"] == true } ?? false
            if someoneWon {
                game.greenieValues[hole] = carryover
                carryover = basePoints
            } else {
                game.greenieValues[hole] = nil
                carryover += basePoints
            }
        }

        game.rules.currentGreenieValue = carryover
    }

    /// Returns hole numbers in play order from startingHole through throughHole (inclusive).
    private func holePlaySequence(startingHole: Int, throughHole: Int) -> [Int] {
        var sequence: [Int] = []
        var h = startingHole
        while true {
            sequence.append(h)
            if h == throughHole { break }
            h = h == 18 ? 1 : h + 1
            if h == startingHole { break }
        }
        return sequence
    }

    /// Increment or decrement a repeatable-task count for one player on a hole.
    @MainActor
    func adjustRepeatableCount(playerName: String, hole: Int, task: String, delta: Int) {
        guard var g = game, g.isActive else { return }
        let current = g.repeatableCounts[hole]?[playerName]?[task] ?? 0
        let updated = max(0, min(3, current + delta))
        g.repeatableCounts[hole, default: [:]][playerName, default: [:]][task] = updated

        if task == "OB" {
            let strokeDelta = updated - current
            let par = g.courseData?.holes?.first(where: { $0.number == hole })?.par ?? 4
            let currentStrokes = g.strokeScores[hole]?[playerName] ?? par
            g.strokeScores[hole, default: [:]][playerName] = max(0, currentStrokes + strokeDelta)
        }

        g.lastModified = Date()
        game = g
        updateCounter += 1
        haptic.impactOccurred()
        persistence.saveCurrent(g)
        shareGameWithWidget()
        scheduleCloudSync()
    }

    @MainActor
    func toggleScore(playerName: String, hole: Int, task: String) {
        guard var g = game, g.isActive else { return }
        // Repeatable tasks use adjustRepeatableCount — ignore stray toggleScore calls for them.
        if g.rules.tasks.first(where: { $0.name == task })?.isRepeatable == true { return }
        let wasOn = g.scores[hole]?[playerName]?[task] ?? false
        g.scores[hole, default: [:]][playerName, default: [:]][task] = !wasOn

        // When Birdie is toggled on, set stroke score to par - 1; when toggled off, reset to par
        if task == "Birdie",
           let holeData = g.courseData?.holes?.first(where: { $0.number == hole }) {
            g.strokeScores[hole, default: [:]][playerName] = wasOn ? holeData.par : holeData.par - 1
        }

        // Store current value for carry-over tasks when scored
        if task == "Greenie" && !wasOn {
            g.greenieValues[hole] = g.rules.currentGreenieValue
        }
        if task == "Low Hole" && !wasOn {
            let lhTask = g.rules.tasks.first(where: { $0.name == "Low Hole" })
            let lhBase = max(1, lhTask?.points ?? 1)
            g.lowHoleValues[hole] = cappedLowHolePayout(task: lhTask, currentValue: g.rules.currentLowHoleValue, basePoints: lhBase)
        }

        // Handle exclusive tasks (works for both individual and team mode)
        // In team mode, this ensures Low Hole is exclusive across all players
        if let taskObj = g.rules.tasks.first(where: { $0.name == task }), taskObj.isExclusive && !wasOn {
            for p in g.players where p.name != playerName {
                g.scores[hole, default: [:]][p.name, default: [:]][task] = false
            }
        }

        g.lastModified = Date()
        game = g
        updateCounter += 1
        haptic.impactOccurred()
        persistence.saveCurrent(g)
        shareGameWithWidget()
        scheduleCloudSync()
    }

    /// Advances to the next hole (with wrap-around from 18 → 1) or triggers game over
    /// when all 18 holes are complete. Only the host may call this.
    @MainActor
    func advanceHole() {
        guard var g = game, isHost else { return }

        autoAwardLowHole(game: &g, hole: g.currentHole)
        autoAwardTeamLow(game: &g, hole: g.currentHole)
        game = g
        updateCounter += 1

        if g.rules.par3Holes.contains(g.currentHole) {
            checkAndUpdateGreenieValue(forHole: g.currentHole)
            guard let updated = game else { return }
            g = updated
        }
        checkAndUpdateLowHoleValue(forHole: g.currentHole)
        guard let updated = game else { return }
        g = updated

        if g.isLastHole {
            g.completedDate = g.completedDate ?? Date()
            g.lastModified = Date()
            game = g
            persistence.saveCurrent(g)
            shareGameWithWidget()
            if !historySaved {
                historySaved = true
                persistence.saveToHistory(g)
                clearWidgetData()
            } else {
                // User went back to edit scores — replace the history entry with updated scores
                persistence.removeFromHistory(gameID: g.gameID)
                persistence.saveToHistory(g)
            }
            showGameOver = true
        } else {
            g.currentHole = g.currentHole == 18 ? 1 : g.currentHole + 1
            g.lastModified = Date()
            game = g
            persistence.saveCurrent(g)
            shareGameWithWidget()
        }
        scheduleCloudSync()
    }

    @MainActor
    func setHole(_ hole: Int) {
        guard (1...18).contains(hole) else { return }
        guard var g = game else { return }

        if hole > g.currentHole {
            autoAwardLowHole(game: &g, hole: g.currentHole)
            autoAwardTeamLow(game: &g, hole: g.currentHole)
            game = g
            updateCounter += 1

            if g.rules.par3Holes.contains(g.currentHole) {
                checkAndUpdateGreenieValue(forHole: g.currentHole)
                guard let updated = game else { return }
                g = updated
            }
            checkAndUpdateLowHoleValue(forHole: g.currentHole)
            guard let updated = game else { return }
            g = updated
        } else if hole < g.currentHole {
            // Clear processed state, stored values, and score booleans for all holes
            // from the target forward so they recalculate on next forward navigation.
            for h in hole...g.currentHole {
                g.processedLowHoleHoles.remove(h)
                g.processedPar3Holes.remove(h)
                g.lowHoleValues[h] = nil
                g.greenieValues[h] = nil
                g.teamLowWinner[h] = nil
                for player in g.players {
                    g.scores[h, default: [:]][player.name, default: [:]]["Low Hole"] = false
                    g.scores[h, default: [:]][player.name, default: [:]]["Greenie"] = false
                }
            }

            // Recalculate carryover in play order up to the hole before the target.
            // When startingHole > 1, hole 1's predecessor in play order is hole 18.
            let startingHole = g.rules.startingHole
            let prevHole = (hole == 1 && startingHole > 1) ? 18 : hole - 1
            if hole == startingHole {
                let basePointsLH = g.rules.tasks.first(where: { $0.name == "Low Hole" })?.points ?? 2
                g.rules.currentLowHoleValue = basePointsLH
                let basePointsG = g.rules.tasks.first(where: { $0.name == "Greenie" })?.points ?? 1
                g.rules.currentGreenieValue = basePointsG
            } else {
                recalculateLowHoleCarryover(game: &g, upToHole: prevHole)
                recalculateGreenieCarryover(game: &g, upToHole: prevHole)
            }

            game = g
            updateCounter += 1
            persistence.saveCurrent(g)
        }

        g.currentHole = hole
        g.lastModified = Date()
        game = g
        persistence.saveCurrent(g)
        shareGameWithWidget()
        scheduleCloudSync()
    }

    /// Single source of truth for Low Hole carry-over math.
    /// - Parameters:
    ///   - holesCarried: consecutive holes without a winner (currentValue/basePoints − 1)
    ///   - pointValue: base dots per hole (the Low Hole task's point value)
    ///   - limitEnabled: whether a carry-over cap is active
    ///   - limit: max holes a winner can collect when the cap is on
    ///   - resetToZero: when true the winner takes the full pot regardless of limit; carry resets to base
    /// - Returns: (payout, newCarryOver) — dots paid to winner, dots carried into the next hole
    private func calculateCarryOverResult(
        holesCarried: Int,
        pointValue: Int,
        limitEnabled: Bool,
        limit: Int,
        resetToZero: Bool
    ) -> (payout: Int, newCarryOver: Int) {
        let currentPot = (holesCarried + 1) * pointValue

        guard limitEnabled else {
            // No limit: winner takes full pot, carry resets to base
            return (payout: currentPot, newCarryOver: pointValue)
        }

        if resetToZero {
            // resetToZero overrides the cap: winner still takes the full pot
            return (payout: currentPot, newCarryOver: pointValue)
        }

        // Cap active, no full-reset: pay min(holesCarried, limit)+1 holes; carry forward the excess,
        // clamped to at most (limit-1) unclaimed holes so the carry never triggers a second capped win.
        let cappedPayout = (min(holesCarried, limit) + 1) * pointValue
        let remainder = max(0, holesCarried - limit)
        let clampedRemainder = min(remainder, max(0, limit - 1))
        return (payout: cappedPayout, newCarryOver: (clampedRemainder + 1) * pointValue)
    }

    private func cappedLowHolePayout(task: CustomTask?, currentValue: Int, basePoints: Int) -> Int {
        calculateCarryOverResult(
            holesCarried: currentValue / basePoints - 1,
            pointValue: basePoints,
            limitEnabled: task?.carryOverLimitEnabled ?? false,
            limit: task?.carryOverLimit ?? 3,
            resetToZero: task?.carryOverResetToZero ?? false
        ).payout
    }

    private func checkAndUpdateGreenieValue(forHole hole: Int) {
        guard var g = game, g.rules.par3Holes.contains(hole), !g.processedPar3Holes.contains(hole) else { return }
        let someoneGot = g.scores[hole]?.values.contains { $0["Greenie"] == true } ?? false
        let basePoints = g.rules.tasks.first(where: { $0.name == "Greenie" })?.points ?? 1
        g.rules.currentGreenieValue = someoneGot ? basePoints : g.rules.currentGreenieValue + basePoints
        g.processedPar3Holes.insert(hole)
        game = g
        // Callers (advanceHole / setHole) always save and sync after this returns
    }

    private func checkAndUpdateLowHoleValue(forHole hole: Int) {
        guard var g = game, !g.processedLowHoleHoles.contains(hole) else { return }
        let someoneGot = g.scores[hole]?.values.contains { $0["Low Hole"] == true } ?? false

        let lowHoleTask = g.rules.tasks.first(where: { $0.name == "Low Hole" })
        let basePoints = max(1, lowHoleTask?.points ?? 1)

        if someoneGot {
            g.rules.currentLowHoleValue = calculateCarryOverResult(
                holesCarried: g.rules.currentLowHoleValue / basePoints - 1,
                pointValue: basePoints,
                limitEnabled: lowHoleTask?.carryOverLimitEnabled ?? false,
                limit: lowHoleTask?.carryOverLimit ?? 3,
                resetToZero: lowHoleTask?.carryOverResetToZero ?? false
            ).newCarryOver
        } else {
            if lowHoleTask?.hasCarryOver == true {
                g.rules.currentLowHoleValue += basePoints
            }
        }

        g.processedLowHoleHoles.insert(hole)
        game = g
        // Callers (advanceHole / setHole) always save and sync after this returns
    }

    // MARK: - Side Bets

    @MainActor
    func addSideBet(_ bet: SideBet) {
        guard var g = game else { return }
        g.sideBets.append(bet)
        g.lastModified = Date()
        game = g
        persistence.saveCurrent(g)
        scheduleCloudSync()
    }

    @MainActor
    func settleSideBet(id: String, winner: String) {
        guard var g = game, let idx = g.sideBets.firstIndex(where: { $0.id == id }) else { return }
        g.sideBets[idx].winnerId = winner
        g.sideBets[idx].status = .settled
        g.sideBets[idx].settledDate = Date()
        g.lastModified = Date()
        game = g
        persistence.saveCurrent(g)
        scheduleCloudSync()
    }

    @MainActor
    func deleteSideBet(id: String) {
        guard var g = game else { return }
        g.sideBets.removeAll { $0.id == id }
        g.lastModified = Date()
        game = g
        persistence.saveCurrent(g)
        scheduleCloudSync()
    }

    // MARK: - CloudKit Sync

    /// Debounced sync: cancels any pending sync and waits 0.5s before pushing to CloudKit.
    /// This coalesces rapid-fire changes (e.g., quick score taps) into a single upload.
    private func scheduleCloudSync() {
        hasPendingLocalChanges = true
        pendingCloudSync?.cancel()
        pendingCloudSync = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await updateCloudGame()
        }
    }

    @MainActor
    private func updateCloudGame() async {
        guard let g = game, let recordID = g.recordID, !isOfflineMode else {
            hasPendingLocalChanges = false
            return
        }

        isSaving = true
        defer { isSaving = false }

        // Snapshot the modification stamp so we can tell if new changes arrive during the save.
        let stampAtStart = g.lastModified
        var attempts = 0

        while attempts < 3 {
            attempts += 1
            // Exponential backoff: 0s / 2s / 4s before each successive attempt
            if attempts > 1 {
                let delay = UInt64(pow(2.0, Double(attempts - 1))) * 1_000_000_000
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
            }
            do {
                let record = try await database.record(for: CKRecord.ID(recordName: recordID))
                // Re-read latest game state — a toggle may have fired during the CloudKit fetch.
                guard let latest = game else { return }
                if let d = try? JSONEncoder().encode(latest.scores) { record["scoresJSON"] = d }
                if let d = try? JSONEncoder().encode(latest.strokeScores) { record["strokeScoresJSON"] = d }
                record["currentHole"] = latest.currentHole
                record["isActive"] = latest.isActive
                if let d = try? JSONEncoder().encode(latest.rules) { record["rulesJSON"] = d }
                if let d = try? JSONEncoder().encode(latest.greenieValues) { record["greenieValuesJSON"] = d }
                if let d = try? JSONEncoder().encode(Array(latest.processedPar3Holes)) { record["processedPar3HolesJSON"] = d }
                if let d = try? JSONEncoder().encode(latest.lowHoleValues) { record["lowHoleValuesJSON"] = d }
                if let d = try? JSONEncoder().encode(Array(latest.processedLowHoleHoles)) { record["processedLowHoleHolesJSON"] = d }
                if let d = try? JSONEncoder().encode(latest.holePhotos) { record["photosJSON"] = d }
                if let d = try? JSONEncoder().encode(latest.sideBets) { record["sideBetsJSON"] = d }
                if let d = try? JSONEncoder().encode(latest.repeatableCounts) { record["repeatableCountsJSON"] = d }
                if let d = try? JSONEncoder().encode(latest.teamLowWinner) { record["teamLowWinnerJSON"] = d }
                if let d = latest.completedDate { record["completedDate"] = d as NSDate }
                // Persist lastModified so fetchLatestGame can make a meaningful timestamp comparison.
                record["lastModifiedDate"] = latest.lastModified as NSDate
                _ = try await database.save(record)
                // Only clear the pending flag if no new toggle arrived while the save was in flight.
                if game?.lastModified == stampAtStart {
                    hasPendingLocalChanges = false
                }
                return
            } catch let e as CKError where e.code == .networkUnavailable || e.code == .networkFailure {
                if attempts < 3 { continue }
                // Data is already persisted locally. Schedule a retry after 30 s so the
                // polling loop doesn't starve while hasPendingLocalChanges stays true.
                scheduleRetrySync(afterSeconds: 30)
                // hasPendingLocalChanges intentionally left true — prevents fetchLatestGame
                // from overwriting unsaved local state until the retry succeeds.
            } catch {
                scheduleRetrySync(afterSeconds: 30)
            }
            return
        }
    }

    /// Schedules a delayed retry of updateCloudGame without resetting the debounce window.
    private func scheduleRetrySync(afterSeconds: Double) {
        retryTask?.cancel()
        retryTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(afterSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await updateCloudGame()
        }
    }

    @MainActor
    func startListeningForChanges() {
        guard !isOfflineMode else { return }
        // Cancel any in-flight loop before starting a replacement.
        // Because this method is @MainActor it cannot be entered concurrently,
        // so cancel + immediate restart is the correct duplicate-prevention pattern.
        syncTask?.cancel()
        syncTask = nil
        isPolling = true
        syncTask = Task { [weak self] in
            defer { Task { @MainActor [weak self] in self?.isPolling = false } }
            while !Task.isCancelled {
                do {
                    // Propagate cancellation immediately — do not use try? here.
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    return  // Task was cancelled during sleep — exit immediately.
                }
                guard !Task.isCancelled else { return }
                guard let self else { return }
                // Stop if the game was cleared (startNewGame) or offline mode flipped on.
                let shouldContinue = await MainActor.run { self.game != nil && !self.isOfflineMode }
                guard shouldContinue else { return }
                await self.fetchLatestGame()
            }
        }
    }

    @MainActor
    private func fetchLatestGame() async {
        // Don't poll while the app is backgrounded — saves battery and avoids stale writes.
        guard UIApplication.shared.applicationState == .active else { return }

        guard let g = game, let recordID = g.recordID else { return }
        guard !hasPendingLocalChanges, !isSaving else { return }
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            let latest = gameState(from: record)

            // Re-read local state after the async fetch — a toggle may have fired during the await.
            // Using `game` here (not the stale `g`) ensures we compare against the true current state.
            guard let currentGame = game else { return }

            // Re-check: a toggle or save could have started while we were fetching.
            guard !hasPendingLocalChanges, !isSaving else { return }

            guard latest.gameID == currentGame.gameID else { return }

            // Remote must be strictly newer than current local state. Because lastModified is
            // now stored in CloudKit, this comparison is meaningful (no more Date() = always-now).
            guard latest.lastModified > currentGame.lastModified else { return }

            var updatedGame = latest
            // Never let a remote sync reduce currentHole — the local host is authoritative.
            if latest.currentHole < currentGame.currentHole {
                updatedGame.currentHole = currentGame.currentHole
            }

            if !currentGame.isActive && updatedGame.isActive {
                showWaitingRoom = false
            }

            // Non-host players auto-advance to results when the host finishes the round.
            if !isHost && updatedGame.completedDate != nil && !showGameOver {
                showGameOver = true
            }

            game = updatedGame
            persistence.saveCurrent(updatedGame)
            shareGameWithWidget()
        } catch {
            // On network error keep playing locally — do NOT touch game state.
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
            completedDate: record["completedDate"] as? Date,
            // lastModifiedDate is the explicit stamp written by updateCloudGame.
            // Fall back to distantPast (not Date()) so old records without the field
            // are always treated as older than local state rather than "just now".
            lastModified: (record["lastModifiedDate"] as? Date) ?? .distantPast,
            joinedPlayerIDs: decode(Set<String>.self, "joinedPlayerIDsJSON") ?? [],
            golfCourse: decode(GolfCourse.self, "golfCourseJSON"),
            courseData: decode(GolfCourseData.self, "courseDataJSON"),
            greenieValues: decode([Int: Int].self, "greenieValuesJSON") ?? [:],
            processedPar3Holes: Set(decode([Int].self, "processedPar3HolesJSON") ?? []),
            lowHoleValues: decode([Int: Int].self, "lowHoleValuesJSON") ?? [:],
            processedLowHoleHoles: Set(decode([Int].self, "processedLowHoleHolesJSON") ?? []),
            holePhotos: decode([HolePhoto].self, "photosJSON") ?? [],
            sideBets: decode([SideBet].self, "sideBetsJSON") ?? [],
            repeatableCounts: decode([Int: [String: [String: Int]]].self, "repeatableCountsJSON") ?? [:],
            teamLowWinner: decode([Int: String].self, "teamLowWinnerJSON") ?? [:]
        )
    }

    // MARK: - Game Lifecycle

    @MainActor
    func startRound() {
        guard var g = game, isHost else { return }
        g.isActive = true
        game = g
        showWaitingRoom = false
        persistence.saveCurrent(g)
        scheduleCloudSync()
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
        }
    }

    @MainActor
    func startNewGame() {
        syncTask?.cancel()
        syncTask = nil
        pendingCloudSync?.cancel()
        pendingCloudSync = nil
        retryTask?.cancel()
        retryTask = nil
        networkMonitor?.cancel()
        networkMonitor = nil
        hasPendingLocalChanges = false
        isSaving = false
        isPolling = false
        historySaved = false
        persistence.clearCurrent(); clearWidgetData()
        game = nil; showWaitingRoom = false; showGameOver = false
        isMultiplayer = false; isHost = false; joinCode = ""
        showHistory = false; isOfflineMode = false
        updateCounter = 0; isLoading = false; joinError = nil
    }

    @MainActor func newRound() { startNewGame() }

    // MARK: - Offline Recovery

    /// Starts a network path monitor that fires `uploadOfflineGameToCloudKit` the first
    /// time connectivity is restored after a game was created without a CloudKit record.
    private func startNetworkMonitorForOfflineGame() {
        networkMonitor?.cancel()
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in
                await self?.uploadOfflineGameToCloudKit()
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.jeffpaz.PapaDot.network", qos: .utility))
    }

    /// Attempts to create a CloudKit record for a game that was originally created offline.
    /// On success: assigns the new recordID, clears offline mode, starts the polling loop.
    /// On failure: leaves isOfflineMode true so the monitor retries on the next path event.
    @MainActor
    private func uploadOfflineGameToCloudKit() async {
        guard isOfflineMode, let g = game, g.recordID == nil else { return }

        let record = CKRecord(recordType: recordType)
        record["gameID"] = g.gameID
        guard let playersData = try? JSONEncoder().encode(g.players),
              let rulesData = try? JSONEncoder().encode(g.rules),
              let joinedData = try? JSONEncoder().encode(g.joinedPlayerIDs) else { return }

        record["playersJSON"] = playersData
        record["rulesJSON"] = rulesData
        record["currentHole"] = g.currentHole
        record["isActive"] = g.isActive
        record["scoresJSON"] = (try? JSONEncoder().encode(g.scores)) ?? Data()
        record["strokeScoresJSON"] = (try? JSONEncoder().encode(g.strokeScores)) ?? Data()
        record["joinedPlayerIDsJSON"] = joinedData
        if let c = g.golfCourse { record["golfCourseJSON"] = try? JSONEncoder().encode(c) }
        if let d = g.courseData { record["courseDataJSON"] = try? JSONEncoder().encode(d) }
        if let d = try? JSONEncoder().encode(g.greenieValues) { record["greenieValuesJSON"] = d }
        if let d = try? JSONEncoder().encode(Array(g.processedPar3Holes)) { record["processedPar3HolesJSON"] = d }
        if let d = try? JSONEncoder().encode(g.lowHoleValues) { record["lowHoleValuesJSON"] = d }
        if let d = try? JSONEncoder().encode(Array(g.processedLowHoleHoles)) { record["processedLowHoleHolesJSON"] = d }
        if let d = try? JSONEncoder().encode(g.sideBets) { record["sideBetsJSON"] = d }
        if let d = try? JSONEncoder().encode(g.repeatableCounts) { record["repeatableCountsJSON"] = d }
        if let d = try? JSONEncoder().encode(g.teamLowWinner) { record["teamLowWinnerJSON"] = d }
        record["lastModifiedDate"] = g.lastModified as NSDate

        do {
            let saved = try await database.save(record)
            var updated = g
            updated.recordID = saved.recordID.recordName
            isOfflineMode = false
            game = updated
            persistence.saveCurrent(updated)
            // Monitor is no longer needed — cancel before starting the poll loop
            networkMonitor?.cancel()
            networkMonitor = nil
            startListeningForChanges()
        } catch {
            // Connectivity satisfied but CK refused (e.g., quota) — stay offline,
            // the monitor will retry on the next path-satisfied event.
        }
    }

    @MainActor func addPhoto(_ photo: HolePhoto) {
        guard var g = game else { return }
        g.holePhotos.append(photo)
        g.lastModified = Date()
        game = g
        persistence.saveCurrent(g); scheduleCloudSync()
    }

    @MainActor func removePhoto(id: String) {
        guard var g = game else { return }
        g.holePhotos.removeAll { $0.id == id }
        g.lastModified = Date()
        game = g
        persistence.saveCurrent(g); scheduleCloudSync()
    }
}
