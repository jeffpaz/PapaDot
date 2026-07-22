import XCTest
@testable import PapaDot

final class PapaDotLogicTests: XCTestCase {

    // MARK: - Helpers

    private func makePlayer(_ name: String, handicap: Int = 0) -> Player {
        Player(name: name, phoneNumber: "555-0000", handicap: handicap)
    }

    private func makeGame(
        players: [Player],
        rules: GameRules,
        scores: [Int: [String: [String: Bool]]] = [:],
        greenieValues: [Int: Int] = [:],
        lowHoleValues: [Int: Int] = [:]
    ) -> GameState {
        var game = GameState(gameID: "TEST01", players: players, rules: rules)
        game.scores = scores
        game.greenieValues = greenieValues
        game.lowHoleValues = lowHoleValues
        return game
    }

    // MARK: - Greenie Carry-Over Tests

    // 4 par-3 holes; no winner on holes 1–3; winner on hole 4 → should receive 4 pts, not 1
    func testGreenieCarryOver_FourPar3s_NoWinnerFirst3_WinnerHole4Gets4Points() {
        let alice = makePlayer("Alice")
        let bob   = makePlayer("Bob")
        let rules = GameRules(par3Holes: [1, 2, 3, 4])

        // Simulate 1-pt base: carry-over accumulates each missed hole (1→2→3→4)
        let game = makeGame(
            players: [alice, bob],
            rules: rules,
            scores: [4: ["Alice": ["Greenie": true]]],
            greenieValues: [4: 4]   // value stored when alice wins on hole 4
        )

        let dots = calculateTotalDots(game: game)

        XCTAssertEqual(dots[alice], 4,
            "Alice wins greenie on hole 4 after 3 carry-overs: expected 4 pts (1 base × 4 accumulated holes)")
        XCTAssertEqual(dots[bob], 0,
            "Bob wins nothing: expected 0 dots")
    }

    // Greenie won on hole 1, no winner hole 2, winner hole 3 → hole 3 worth 2 pts
    func testGreenieCarryOver_WonHole1_MissedHole2_WonHole3_Hole3Worth2Points() {
        let alice = makePlayer("Alice")
        let bob   = makePlayer("Bob")
        let rules = GameRules(par3Holes: [1, 2, 3])

        // Hole 1: base 1; hole 2: missed (carry-over to 2); hole 3: worth 2
        let game = makeGame(
            players: [alice, bob],
            rules: rules,
            scores: [
                1: ["Alice": ["Greenie": true]],
                3: ["Bob":   ["Greenie": true]]
            ],
            greenieValues: [1: 1, 3: 2]
        )

        let dots = calculateTotalDots(game: game)

        XCTAssertEqual(dots[alice], 1,
            "Alice wins hole-1 greenie at base value 1")
        XCTAssertEqual(dots[bob], 2,
            "Bob wins hole-3 greenie carrying over from hole 2: expected 2 pts (1 base + 1 carry)")
    }

    // Greenie won on every par-3 hole → each worth 1 pt (carry-over resets each hole)
    func testGreenieCarryOver_WonEveryHole_EachWorthBasePoint() {
        let alice = makePlayer("Alice")
        let bob   = makePlayer("Bob")
        let rules = GameRules(par3Holes: [1, 2, 3, 4])

        let game = makeGame(
            players: [alice, bob],
            rules: rules,
            scores: [
                1: ["Alice": ["Greenie": true]],
                2: ["Bob":   ["Greenie": true]],
                3: ["Alice": ["Greenie": true]],
                4: ["Bob":   ["Greenie": true]]
            ],
            greenieValues: [1: 1, 2: 1, 3: 1, 4: 1]   // resets to base 1 after every win
        )

        let dots = calculateTotalDots(game: game)

        XCTAssertEqual(dots[alice], 2,
            "Alice wins holes 1 and 3 at 1 pt each: expected 2 dots")
        XCTAssertEqual(dots[bob], 2,
            "Bob wins holes 2 and 4 at 1 pt each: expected 2 dots")
    }

    // No greenies scored all round → carry-over accumulates to 18 but no dots are ever paid out
    func testGreenieCarryOver_NoGreenieScoredAllRound_ZeroDotsAwarded() {
        let alice = makePlayer("Alice")
        let bob   = makePlayer("Bob")
        let rules = GameRules(par3Holes: Set(1...18))

        // No greenieValues stored (no winners); carry-over value builds to 18 but is never awarded
        let game = makeGame(players: [alice, bob], rules: rules)

        let dots = calculateTotalDots(game: game)

        XCTAssertEqual(dots[alice], 0,
            "No greenie ever claimed: carry-over reaches 18 but zero dots are awarded to Alice")
        XCTAssertEqual(dots[bob], 0,
            "No greenie ever claimed: carry-over reaches 18 but zero dots are awarded to Bob")
    }

    // MARK: - Negative Task Tests

    // Player A gets Sand on hole 5 → all OTHER players each receive 1 dot; Player A receives nothing
    func testNegativeTask_PlayerHitsSand_OtherPlayersEachReceive1Dot() {
        let alice   = makePlayer("Alice")
        let bob     = makePlayer("Bob")
        let charlie = makePlayer("Charlie")
        let rules   = GameRules()

        let game = makeGame(
            players: [alice, bob, charlie],
            rules: rules,
            scores: [5: ["Alice": ["Sand": true]]]
        )

        let dots = calculateTotalDots(game: game)

        XCTAssertEqual(dots[alice],   0, "Alice scored Sand (negative task): expected 0 dots for herself")
        XCTAssertEqual(dots[bob],     1, "Bob should receive 1 dot from Alice's Sand")
        XCTAssertEqual(dots[charlie], 1, "Charlie should receive 1 dot from Alice's Sand")
    }

    // Player A gets OB AND 3-Putt on same hole → each other player receives 2 dots (1 per negative task)
    func testNegativeTask_OBAndThreePuttSameHole_EachOtherPlayerReceives2Dots() {
        let alice   = makePlayer("Alice")
        let bob     = makePlayer("Bob")
        let charlie = makePlayer("Charlie")
        let rules   = GameRules()

        let game = makeGame(
            players: [alice, bob, charlie],
            rules: rules,
            scores: [5: ["Alice": ["OB": true, "3-Putt": true]]]
        )

        let dots = calculateTotalDots(game: game)

        XCTAssertEqual(dots[alice],   0, "Alice scored OB + 3-Putt (both negative): expected 0 dots for herself")
        XCTAssertEqual(dots[bob],     2, "Bob should receive 2 dots: 1 from OB + 1 from 3-Putt")
        XCTAssertEqual(dots[charlie], 2, "Charlie should receive 2 dots: 1 from OB + 1 from 3-Putt")
    }

    // MARK: - Team Mode Tests

    // Team A player scores Birdie → both Team A players get the dot, Team B gets nothing
    func testTeamMode_TeamAScoresBirdie_TeamASharesDots_TeamBGetsNothing() {
        let alice   = makePlayer("Alice")    // Team A — players[0]
        let bob     = makePlayer("Bob")      // Team A — players[1]
        let charlie = makePlayer("Charlie")  // Team B — players[2]
        let dave    = makePlayer("Dave")     // Team B — players[3]

        var rules = GameRules()
        rules.isTeamMode = true
        // Use 2-pt Birdie so the 1-dot-each split between teammates is exact
        if let idx = rules.tasks.firstIndex(where: { $0.name == "Birdie" }) {
            rules.tasks[idx] = CustomTask(name: "Birdie", points: 2)
        }

        let game = makeGame(
            players: [alice, bob, charlie, dave],
            rules: rules,
            scores: [1: ["Alice": ["Birdie": true]]]
        )

        let dots = calculateTotalDots(game: game)

        XCTAssertEqual(dots[alice],   1, "Alice (Team A) should receive 1 dot: 2-pt Birdie split evenly with teammate")
        XCTAssertEqual(dots[bob],     1, "Bob (Team A) should receive 1 dot: shares Team A's Birdie with Alice")
        XCTAssertEqual(dots[charlie], 0, "Charlie (Team B) should receive 0 dots: Birdie belongs to Team A")
        XCTAssertEqual(dots[dave],    0, "Dave (Team B) should receive 0 dots: Birdie belongs to Team A")
    }

    // Low Hole is exclusive per team: if Team A player wins it, Team B player cannot also win it
    func testTeamMode_LowHoleExclusive_TeamAWinsLowHole_TeamBReceivesNone() {
        let alice   = makePlayer("Alice")    // Team A — players[0]
        let bob     = makePlayer("Bob")      // Team A — players[1]
        let charlie = makePlayer("Charlie")  // Team B — players[2]
        let dave    = makePlayer("Dave")     // Team B — players[3]

        var rules = GameRules()
        rules.isTeamMode = true

        // Alice (Team A) wins Low Hole; Team B players explicitly not awarded
        let game = makeGame(
            players: [alice, bob, charlie, dave],
            rules: rules,
            scores: [5: [
                "Alice":   ["Low Hole": true],
                "Bob":     ["Low Hole": false],
                "Charlie": ["Low Hole": false],
                "Dave":    ["Low Hole": false]
            ]],
            lowHoleValues: [5: 2]   // 2-pt Low Hole, no carry-over
        )

        let dots = calculateTotalDots(game: game)

        XCTAssertEqual(dots[alice],   1, "Alice (Team A) receives 1 dot: 2-pt Low Hole split with teammate Bob")
        XCTAssertEqual(dots[bob],     1, "Bob (Team A) receives 1 dot: Low Hole shared with Alice")
        XCTAssertEqual(dots[charlie], 0, "Charlie (Team B) did not win Low Hole: expected 0 dots")
        XCTAssertEqual(dots[dave],    0, "Dave (Team B) did not win Low Hole: expected 0 dots")
    }

    // Handicap net score: player with handicap 18 on a handicap-1 hole gets 1 stroke subtracted
    // Gross scores tied at 5; Alice net = 4, Bob net = 5 → Alice wins Low Hole
    func testHandicap_Handicap18OnHandicap1Hole_WinsLowHoleAfterStrokeReduction() {
        let alice = makePlayer("Alice", handicap: 18)  // receives 1 stroke on handicap-1 hole
        let bob   = makePlayer("Bob",   handicap:  0)  // scratch; no strokes

        let rules = GameRules()
        // autoAwardLowHole would compute: alice net 4, bob net 5 → alice wins
        let game = makeGame(
            players: [alice, bob],
            rules: rules,
            scores: [1: [
                "Alice": ["Low Hole": true],
                "Bob":   ["Low Hole": false]
            ]],
            lowHoleValues: [1: 2]
        )

        let dots = calculateTotalDots(game: game)

        XCTAssertEqual(dots[alice], 2,
            "Alice (handicap 18) wins Low Hole: net score is 1 stroke lower than Bob's on this handicap-1 hole")
        XCTAssertEqual(dots[bob], 0,
            "Bob (scratch) does not win Low Hole after handicap adjustment: expected 0 dots")
    }

    // MARK: - Edge Cases

    // All players tie on every task → zero dots for everyone
    func testAllPlayersTie_ZeroDotsForEveryone() {
        let alice = makePlayer("Alice")
        let bob   = makePlayer("Bob")
        let rules = GameRules()

        // Tied Low Hole is cleared to false by autoAwardLowHole; no other tasks scored
        let game = makeGame(
            players: [alice, bob],
            rules: rules,
            scores: [1: [
                "Alice": ["Low Hole": false],
                "Bob":   ["Low Hole": false]
            ]]
        )

        let dots = calculateTotalDots(game: game)

        XCTAssertEqual(dots[alice], 0,
            "Tied Low Hole awards nothing: expected 0 dots for Alice")
        XCTAssertEqual(dots[bob], 0,
            "Tied Low Hole awards nothing: expected 0 dots for Bob")
    }

    // Single-player game: negative task has no other recipients, so no dots change hands
    func testSinglePlayer_NegativeTask_NoDotsChangeHands() {
        let alice = makePlayer("Alice")
        let rules = GameRules()

        // Alice hits Sand; there are no other players to receive the dot
        let game = makeGame(
            players: [alice],
            rules: rules,
            scores: [1: ["Alice": ["Sand": true]]]
        )

        let dots = calculateTotalDots(game: game)

        XCTAssertEqual(dots[alice], 0,
            "Single-player game: negative task has no recipients, so no dots change hands")
    }

    // Player scores Birdie AND Greenie on the same hole → both calculated correctly and independently
    func testBirdieAndGreenieSameHole_BothCalculatedIndependently() {
        let alice = makePlayer("Alice")
        let bob   = makePlayer("Bob")
        let rules = GameRules()   // default Birdie = 3 pts, default Greenie = 2 pts

        let game = makeGame(
            players: [alice, bob],
            rules: rules,
            scores: [1: ["Alice": ["Birdie": true, "Greenie": true]]],
            greenieValues: [1: 2]   // base greenie value, no carry-over
        )

        let dots = calculateTotalDots(game: game)

        XCTAssertEqual(dots[alice], 5,
            "Alice should receive 3 dots for Birdie + 2 dots for Greenie = 5 total on hole 1")
        XCTAssertEqual(dots[bob], 0,
            "Bob scores nothing on hole 1: expected 0 dots")
    }

    // MARK: - GameManager Update-Propagation Contract
    //
    // ScoreEntryView's toggle/stepper buttons include manager.updateCounter in their .id()
    // so SwiftUI is forced to refresh their rendered state on every mutation (a static id
    // reuses the previously rendered node and the tap silently fails to repaint — see
    // ScoreToggleButton/ScoreStepperButton in ScoreEntryView.swift). PapaDotUITests is
    // disabled, so this pins the data-layer half of that contract: updateCounter must
    // increment exactly once per mutating call.

    @MainActor
    func testToggleScore_IncrementsUpdateCounterExactlyOnce() {
        let alice = makePlayer("Alice")
        let bob = makePlayer("Bob")
        var game = GameState(gameID: "TEST01", players: [alice, bob], rules: GameRules())
        game.isActive = true

        let manager = GameManager()
        manager.game = game
        manager.isHost = true
        let before = manager.updateCounter

        manager.toggleScore(playerName: "Alice", hole: 1, task: "Fairway")

        XCTAssertEqual(manager.updateCounter, before + 1)
        XCTAssertEqual(manager.game?.scores[1]?["Alice"]?["Fairway"], true)
    }

    @MainActor
    func testAdjustRepeatableCount_IncrementsUpdateCounterExactlyOnce() {
        let alice = makePlayer("Alice")
        let bob = makePlayer("Bob")
        var game = GameState(gameID: "TEST01", players: [alice, bob], rules: GameRules())
        game.isActive = true

        let manager = GameManager()
        manager.game = game
        manager.isHost = true
        let before = manager.updateCounter

        manager.adjustRepeatableCount(playerName: "Alice", hole: 1, task: "Sand", delta: 1)

        XCTAssertEqual(manager.updateCounter, before + 1)
        XCTAssertEqual(manager.game?.repeatableCounts[1]?["Alice"]?["Sand"], 1)
    }

    // MARK: - Stroke Score / Birdie Reconciliation
    //
    // Birdie requires strokes == par - 1. toggleScore sets that up when Birdie is checked,
    // but a later manual score edit (stroke picker or Scorecard tap-to-edit, both routed
    // through setStrokeScore) or an OB tick (adjustRepeatableCount) can move the stroke
    // count without ever touching the Birdie flag. setStrokeScore/adjustRepeatableCount
    // must clear a stale Birdie so calculateHoleDots stops crediting it.

    private func makePar4CourseData(hole: Int = 1) -> GolfCourseData {
        GolfCourseData(courseName: "Test", totalPar: 4, par3Holes: [], holes: [
            HoleInfo(number: hole, par: 4, yardage: 400)
        ])
    }

    @MainActor
    func testSetStrokeScore_ClearsBirdieWhenScoreNoLongerMatchesParMinusOne() {
        let alice = makePlayer("Alice")
        let bob = makePlayer("Bob")
        var game = GameState(gameID: "TEST01", players: [alice, bob], rules: GameRules())
        game.isActive = true
        game.courseData = makePar4CourseData()

        let manager = GameManager()
        manager.game = game
        manager.isHost = true

        manager.toggleScore(playerName: "Alice", hole: 1, task: "Birdie")
        XCTAssertEqual(manager.game?.strokeScores[1]?["Alice"], 3,
            "Birdie on a par-4 hole should auto-set strokes to par - 1 = 3")

        manager.setStrokeScore(playerName: "Alice", hole: 1, strokes: 6)

        XCTAssertEqual(manager.game?.scores[1]?["Alice"]?["Birdie"], false,
            "Manually setting strokes away from par - 1 must clear the now-stale Birdie flag")

        let dots = calculateHoleDots(game: manager.game!, hole: 1)
        XCTAssertEqual(dots[alice], 0,
            "Birdie dots must not be credited once the score no longer qualifies")
    }

    @MainActor
    func testSetStrokeScore_BirdieUnaffectedWhenScoreStillMatchesParMinusOne() {
        let alice = makePlayer("Alice")
        let bob = makePlayer("Bob")
        var game = GameState(gameID: "TEST01", players: [alice, bob], rules: GameRules())
        game.isActive = true
        game.courseData = makePar4CourseData()

        let manager = GameManager()
        manager.game = game
        manager.isHost = true

        manager.toggleScore(playerName: "Alice", hole: 1, task: "Birdie")
        manager.setStrokeScore(playerName: "Alice", hole: 1, strokes: 3)

        XCTAssertEqual(manager.game?.scores[1]?["Alice"]?["Birdie"], true,
            "Re-setting the score to the same par - 1 value must not clear Birdie")
    }

    @MainActor
    func testAdjustRepeatableCount_OBTick_ClearsBirdieWhenResultingScoreBreaksParMinusOne() {
        let alice = makePlayer("Alice")
        let bob = makePlayer("Bob")
        var game = GameState(gameID: "TEST01", players: [alice, bob], rules: GameRules())
        game.isActive = true
        game.courseData = makePar4CourseData()

        let manager = GameManager()
        manager.game = game
        manager.isHost = true

        manager.toggleScore(playerName: "Alice", hole: 1, task: "Birdie")
        XCTAssertEqual(manager.game?.strokeScores[1]?["Alice"], 3)

        manager.adjustRepeatableCount(playerName: "Alice", hole: 1, task: "OB", delta: 1)

        XCTAssertEqual(manager.game?.strokeScores[1]?["Alice"], 4,
            "An OB tick should add a stroke to the existing score")
        XCTAssertEqual(manager.game?.scores[1]?["Alice"]?["Birdie"], false,
            "Birdie must clear once the OB-adjusted score breaks par - 1")
    }

    // MARK: - Nassau

    private func makeNassauCourseData() -> GolfCourseData {
        let holes = (1...18).map { HoleInfo(number: $0, par: 4, yardage: 400, handicap: $0) }
        return GolfCourseData(courseName: "Test", totalPar: 72, par3Holes: [], holes: holes)
    }

    func testNassau_FrontWinBackPushOverallWin_AcrossFullRound() {
        let alice = makePlayer("Alice")
        let bob = makePlayer("Bob")
        var game = GameState(gameID: "TEST01", players: [alice, bob], rules: GameRules())
        game.isActive = true
        game.rules.useHandicap = false
        game.courseData = makeNassauCourseData()
        game.completedDate = Date()   // round complete — every hole counts as played

        // Front 9: Alice shoots 3, Bob shoots 4 every hole — Alice wins all 9.
        for h in 1...9 {
            game.strokeScores[h] = ["Alice": 3, "Bob": 4]
        }
        // Back 9: 4 holes each, 1 tied hole — nets to a push.
        game.strokeScores[10] = ["Alice": 3, "Bob": 4]
        game.strokeScores[11] = ["Alice": 4, "Bob": 3]
        game.strokeScores[12] = ["Alice": 3, "Bob": 4]
        game.strokeScores[13] = ["Alice": 4, "Bob": 3]
        game.strokeScores[14] = ["Alice": 3, "Bob": 4]
        game.strokeScores[15] = ["Alice": 4, "Bob": 3]
        game.strokeScores[16] = ["Alice": 3, "Bob": 4]
        game.strokeScores[17] = ["Alice": 4, "Bob": 3]
        game.strokeScores[18] = ["Alice": 4, "Bob": 4]

        let match = NassauMatch(playerAID: alice.id, playerBID: bob.id, frontBet: 5, backBet: 5, overallBet: 5)
        let result = calculateNassauResult(game: game, match: match)

        let front = result.segments.first { $0.segment == .front }!
        let back = result.segments.first { $0.segment == .back }!
        let overall = result.segments.first { $0.segment == .overall }!

        XCTAssertTrue(front.isResolved)
        XCTAssertEqual(front.winnerID, alice.id, "Alice wins every front-9 hole")
        XCTAssertEqual(front.amount, 5)

        XCTAssertTrue(back.isResolved)
        XCTAssertNil(back.winnerID, "A 4-4 split with one tied hole is a push")
        XCTAssertEqual(back.amount, 0)

        XCTAssertTrue(overall.isResolved)
        XCTAssertEqual(overall.winnerID, alice.id, "Front win + back push nets an overall win for Alice")
        XCTAssertEqual(overall.amount, 5)

        let net = result.netSettlement
        XCTAssertEqual(net?.payerID, bob.id)
        XCTAssertEqual(net?.payeeID, alice.id)
        XCTAssertEqual(net?.amount, 10, "Bob owes front ($5) + overall ($5); back is a push")
    }

    func testNassau_SegmentNotResolvedUntilAllHolesReached() {
        let alice = makePlayer("Alice")
        let bob = makePlayer("Bob")
        var game = GameState(gameID: "TEST01", players: [alice, bob], rules: GameRules())
        game.isActive = true
        game.rules.useHandicap = false
        game.courseData = makeNassauCourseData()
        game.currentHole = 5   // only holes 1-4 reached; round in progress

        for h in 1...4 {
            game.strokeScores[h] = ["Alice": 3, "Bob": 4]
        }

        let match = NassauMatch(playerAID: alice.id, playerBID: bob.id)
        let result = calculateNassauResult(game: game, match: match)
        let front = result.segments.first { $0.segment == .front }!
        let back = result.segments.first { $0.segment == .back }!

        XCTAssertFalse(front.isResolved, "Only 4 of 9 front holes have been reached")
        XCTAssertNil(front.winnerID, "Must not report a settled winner before the segment completes")
        XCTAssertEqual(front.amount, 0)
        XCTAssertEqual(front.holesPlayed, 4)
        XCTAssertEqual(front.margin, 4, "Live margin can still show Alice leading, even though it isn't settled")

        XCTAssertFalse(back.isResolved)
        XCTAssertEqual(back.holesPlayed, 0)
    }

    func testNassau_HandicapChangesSegmentWinner() {
        let alice = makePlayer("Alice", handicap: 0)
        let bob = makePlayer("Bob", handicap: 9)
        var game = GameState(gameID: "TEST01", players: [alice, bob], rules: GameRules())
        game.isActive = true
        game.courseData = makeNassauCourseData()
        game.completedDate = Date()

        // Alice shoots 3, Bob shoots 4 every front-9 hole — gross favors Alice outright.
        for h in 1...9 {
            game.strokeScores[h] = ["Alice": 3, "Bob": 4]
        }
        let match = NassauMatch(playerAID: alice.id, playerBID: bob.id)

        game.rules.useHandicap = false
        let grossFront = calculateNassauResult(game: game, match: match).segments.first { $0.segment == .front }!
        XCTAssertEqual(grossFront.winnerID, alice.id, "Without handicap, Alice's better gross score wins every hole")

        game.rules.useHandicap = true
        let netFront = calculateNassauResult(game: game, match: match).segments.first { $0.segment == .front }!
        // Bob's 9-handicap gives him a stroke on every front-9 hole (handicap index 1-9),
        // pulling his net to 3 — level with Alice's untouched 3 — turning the same raw
        // scores into a push once handicap is applied.
        XCTAssertNil(netFront.winnerID, "With handicap, Bob's strokes level every hole into a push")
        XCTAssertNotEqual(grossFront.winnerID, netFront.winnerID)
    }

    @MainActor
    func testAddRemoveNassauMatch_NoOpWhenNotHost() {
        let alice = makePlayer("Alice")
        let bob = makePlayer("Bob")
        var game = GameState(gameID: "TEST01", players: [alice, bob], rules: GameRules())
        game.isActive = true

        let manager = GameManager()
        manager.game = game
        manager.isHost = false

        let match = NassauMatch(playerAID: alice.id, playerBID: bob.id)
        manager.addNassauMatch(match)
        XCTAssertEqual(manager.game?.nassauMatches ?? [], [], "A non-host must not be able to add a Nassau match")

        manager.isHost = true
        manager.addNassauMatch(match)
        manager.isHost = false
        manager.removeNassauMatch(id: match.id)
        XCTAssertEqual(manager.game?.nassauMatches.count, 1, "A non-host must not be able to remove a Nassau match")
    }

    // MARK: - Side Bet host-gating (regression test for the addSideBet/settleSideBet/
    // deleteSideBet host-authorization gap: previously any guest device could add a bet,
    // delete anyone's bet, or declare any player the winner of a real-money bet)

    @MainActor
    func testSideBetMutators_NoOpWhenNotHost() {
        let alice = makePlayer("Alice")
        let bob = makePlayer("Bob")
        var game = GameState(gameID: "TEST01", players: [alice, bob], rules: GameRules())
        game.isActive = true

        let manager = GameManager()
        manager.game = game
        manager.isHost = false

        let bet = SideBet(title: "Longest Drive", description: "", amount: 10,
                           createdBy: "Alice", participants: ["Alice", "Bob"])
        manager.addSideBet(bet)
        XCTAssertEqual(manager.game?.sideBets.count, 0, "A non-host must not be able to add a side bet")

        manager.isHost = true
        manager.addSideBet(bet)
        manager.isHost = false

        manager.settleSideBet(id: bet.id, winner: "Alice")
        XCTAssertEqual(manager.game?.sideBets.first?.status, .active,
            "A non-host must not be able to settle a side bet")

        manager.deleteSideBet(id: bet.id)
        XCTAssertEqual(manager.game?.sideBets.count, 1, "A non-host must not be able to delete a side bet")
    }

    // MARK: - Side Bet Payout Split

    func testCalculateSideBetPayouts_UnevenSplitSumsExactlyToAmount() {
        let alice = makePlayer("Alice")
        let bob = makePlayer("Bob")
        let charlie = makePlayer("Charlie")
        var game = GameState(gameID: "TEST01", players: [alice, bob, charlie], rules: GameRules())

        var bet = SideBet(title: "Closest to Pin", description: "", amount: 5,
                           createdBy: "Alice", participants: ["Alice", "Bob", "Charlie"])
        bet.winnerId = "Alice"
        bet.status = .settled
        game.sideBets = [bet]

        let payouts = calculateSideBetPayouts(game: game)
        XCTAssertEqual(payouts.count, 1)
        let winnerPays = payouts[0].winnerPays
        XCTAssertEqual(winnerPays.count, 2)
        let total = winnerPays.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(total, 5, "Payout lines must sum back to exactly the bet's pot, no dollars lost to integer division")
        XCTAssertEqual(Set(winnerPays.map { $0.amount }), Set([2, 3]), "$5 over 2 losers: $2 base + $1 remainder to the first")
    }
}
