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
    var incomingReaction: Reaction? = nil

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
                  greenieValues: [:], processedPar3Holes: [])
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

    func toggleScore(playerName: String, hole: Int, task: String) {
        guard var g = game, g.isActive else { return }
        let wasOn = g.scores[hole]?[playerName]?[task] ?? false
        g.scores[hole, default: [:]][playerName, default: [:]][task] = !wasOn

        if task == "Greenie" && !wasOn {
            g.greenieValues[hole] = g.rules.currentGreenieValue
        }
        if let taskObj = g.rules.tasks.first(where: { $0.name == task }), taskObj.isExclusive && !wasOn {
            for p in g.players where p.name != playerName {
                g.scores[hole, default: [:]][p.name, default: [:]][task] = false
            }
        }
        game = g; updateCounter += 1
        haptic.impactOccurred()
        persistence.saveCurrent(g)
        shareGameWithWidget()
        Task { await updateCloudGame() }
    }

    func setHole(_ hole: Int) {
        guard var g = game else { return }
        if hole > g.currentHole && g.rules.par3Holes.contains(g.currentHole) {
            checkAndUpdateGreenieValue(forHole: g.currentHole)
            guard let updated = game else { return }
            g = updated
        }
        g.currentHole = min(18, max(1, hole))
        game = g
        persistence.saveCurrent(g)
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
        g.rules.currentGreenieValue = someoneGot ? 1 : g.rules.currentGreenieValue + 1
        g.processedPar3Holes.insert(hole)
        game = g
        persistence.saveCurrent(g)
        Task { await updateCloudGame() }
    }

    // MARK: - Reactions

    func addReaction(_ reaction: Reaction) {
        guard var g = game else { return }
        g.reactions.append(reaction)
        game = g
        showIncomingReaction(reaction)
        persistence.saveCurrent(g)
        Task { await updateCloudGame() }
    }

    private func showIncomingReaction(_ reaction: Reaction) {
        incomingReaction = reaction
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { if incomingReaction?.id == reaction.id { incomingReaction = nil } }
        }
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
            record["currentHole"] = g.currentHole
            record["isActive"] = g.isActive
            if let d = try? JSONEncoder().encode(g.rules) { record["rulesJSON"] = d }
            if let d = try? JSONEncoder().encode(g.greenieValues) { record["greenieValuesJSON"] = d }
            if let d = try? JSONEncoder().encode(Array(g.processedPar3Holes)) { record["processedPar3HolesJSON"] = d }
            if let d = try? JSONEncoder().encode(g.holePhotos) { record["photosJSON"] = d }
            if let d = try? JSONEncoder().encode(g.reactions) { record["reactionsJSON"] = d }
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
            if latest.lastModified > (game?.lastModified ?? Date.distantPast) {
                let newReactions = latest.reactions.filter { r in
                    !(game?.reactions.contains(where: { $0.id == r.id }) ?? false)
                }
                game = latest
                persistence.saveCurrent(latest)
                shareGameWithWidget()
                if let first = newReactions.first { showIncomingReaction(first) }
            }
        } catch { print("⚠️ Fetch failed: \(error)") }
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
            isActive: record["isActive"] as? Bool ?? false,
            joinedPlayerIDs: decode(Set<String>.self, "joinedPlayerIDsJSON") ?? [],
            golfCourse: decode(GolfCourse.self, "golfCourseJSON"),
            courseData: decode(GolfCourseData.self, "courseDataJSON"),
            greenieValues: decode([Int: Int].self, "greenieValuesJSON") ?? [:],
            processedPar3Holes: Set(decode([Int].self, "processedPar3HolesJSON") ?? []),
            holePhotos: decode([HolePhoto].self, "photosJSON") ?? [],
            reactions: decode([Reaction].self, "reactionsJSON") ?? [],
            sideBets: decode([SideBet].self, "sideBetsJSON") ?? []
        )
    }

    // MARK: - Game Lifecycle

    @MainActor
    func startGame() async {
        guard var g = game, isHost, let recordID = g.recordID else { return }
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: recordID))
            record["isActive"] = true
            _ = try await database.save(record)
            g.isActive = true; game = g
            showWaitingRoom = false
            persistence.saveCurrent(g)
        } catch {
            var g2 = g; g2.isActive = true; game = g2
            showWaitingRoom = false; persistence.saveCurrent(g2)
        }
    }

    func startNewGame() {
        persistence.clearCurrent(); clearWidgetData()
        game = nil; showWaitingRoom = false; showGameOver = false
        isMultiplayer = false; isHost = false; joinCode = ""
        showHistory = false; isOfflineMode = false; incomingReaction = nil
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
