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
}
