# PapaDot Architecture

## Overview

PapaDot is a single-target iOS app (+ WidgetKit extension) built in SwiftUI. The core design goal is *offline-first local state with CloudKit as the sync layer* — the game is fully playable without a connection, and changes upload as soon as the network is available.

---

## Layer Map

```
Views/                  ← SwiftUI screens, read game state from GameManager
  ├── GameSetup/        ← CreateGameView, JoinGameView, UserProfileSetupView
  ├── ScoreEntryView    ← Active scoring (hole-by-hole)
  ├── GameOverView      ← Stats + Payouts end screen
  ├── StatisticsView    ← Live stats tab during play
  ├── ScorecardView     ← Traditional scorecard grid
  ├── SideBetsView      ← Side bet management
  └── ...               ← History, HomeView, WaitingRoom, etc.

Managers/
  ├── GameManager       ← Single source of truth; owns game: GameState?
  ├── FavoritesManager  ← Persists favorite players + last-used handicaps
  └── SavedTasksManager ← Named task presets (CustomTask arrays)

Models/
  ├── GameState         ← All mutable per-game data (scores, carry-over, etc.)
  ├── GameRules         ← Immutable-ish config chosen at game creation
  ├── CustomTask        ← Task definition (points, flags, carry-over config)
  └── Player            ← Name, phone, handicap, lastUsedHandicap

Utilities/
  ├── Helpers.swift     ← Pure dot-calculation functions (no side effects)
  └── PersistenceManager← JSON encode/decode to UserDefaults (current + history)

GolfCourseData/
  ├── GolfCourse        ← Course identity (name, address)
  └── GolfCourseData    ← Hole-by-hole data (par, yardage, handicap index)

Services/
  └── GolfCourseAPIService ← External course lookup

PapaDotWidget/          ← WidgetKit extension (reads shared UserDefaults)

PapaDotTests/           ← XCTest unit tests — pure Helpers.swift math + GameManager mutator contracts
PapaDotUITests/         ← XCUITest UI tests — launches with -UITesting (see Testing, below)
```

---

## GameManager

`GameManager` is an `@Observable` class injected at the app root via `.environment`. All views read from it; only the host player's device writes to it during a round.

### Key state

| Property | Purpose |
|---|---|
| `game: GameState?` | Nil between rounds; non-nil while a round is active |
| `isHost: Bool` | Only the host may call `advanceHole`, `setHole`, score toggles — enforced inside those methods themselves, not just in the UI |
| `isMultiplayer: Bool` | True when a CloudKit record exists |
| `isOfflineMode: Bool` | True when game was created without connectivity |
| `hasPendingLocalChanges: Bool` | Blocks polling from overwriting unsaved local state |
| `isSaving: Bool` | Blocks polling during an in-flight CloudKit save |
| `updateCounter: Int` | Incremented on every scoring mutation; see *View update propagation*, below |

### Host authorization

`isHost` is set once, at creation/join time, and is never derived from a display name — two
devices can easily share the same `userName` (both left at the default "Me"), so name equality
is not a valid identity check. `setStrokeScore`, `toggleScore`, `adjustRepeatableCount`, and
`setHole` all guard on `isHost` directly; views (`ScoreEntryView`, `ScorecardView`,
`GameOverView`) read `manager.isHost` to disable/hide controls, but the manager-level guard is
the actual source of truth.

`isHost` is device-local — it is *not* part of `GameState` (every joined guest also gets a
CloudKit `recordID`, so `recordID != nil` is not a valid host signal either). It is persisted
separately via `PersistenceManager.saveIsHost` / `loadIsHost` and restored on cold launch
alongside `loadCurrent()`.

### Scoring write path

```
User tap → manager.toggleScore / adjustRepeatableCount / setStrokeScore
         → mutate game (local struct copy)
         → persistence.saveCurrent(g)          ← immediate local persist
         → scheduleCloudSync()                  ← debounced 0.5s CloudKit write
```

`scheduleCloudSync` cancels any pending upload and restarts a 0.5s Task. Rapid successive taps produce exactly one CloudKit write, 0.5s after the last tap.

**Birdie/stroke-score reconciliation:** Birdie requires `strokes == holePar - 1`; `toggleScore` sets that up automatically when Birdie is checked. But strokes can also change *without* going through `toggleScore` — a manual edit via the stroke picker or Scorecard's tap-to-edit cell (`setStrokeScore`), or an OB tick (`adjustRepeatableCount`'s `OB` branch). Both of those mutators independently clear Birdie if the resulting score no longer equals `holePar - 1`, so a stale Birdie can't survive a score change made through any path. `holePar(game:hole:)` (`Helpers.swift`) is the shared par lookup all three of these call sites — plus `ScorecardView.par(_:)` — use, so they can't drift out of sync with each other.

### View update propagation

`ScoreToggleButton` and `ScoreStepperButton` (in `ScoreEntryView`) each carry an explicit `.id()` that includes `manager.updateCounter`. This is load-bearing, not decorative: without it, SwiftUI can reuse the previously-rendered node across a tap instead of repainting it — the underlying `GameState` updates correctly, but the circle/count visually freezes until something else (e.g. navigating to another hole and back) forces a full rebuild. `StrokeScorePicker` follows the same pattern. Scoping the `.id()` to *only* player/task/hole (without `updateCounter`) looks like a natural performance win — fewer view identities changing per tap — but reintroduces exactly this staleness; see the v1.28 changelog entry for the incident this caused.

### Hole advance path

```
advanceHole()
  autoAwardLowHole(hole)      ← pick player with lowest net score
  autoAwardTeamLow(hole)      ← pick team with best net (team mode only)
  checkAndUpdateGreenieValue  ← update carry-over counter for Greenie
  checkAndUpdateLowHoleValue  ← update carry-over counter for Low Hole
  if isLastHole → completedDate, saveToHistory, showGameOver = true
  else          → currentHole += 1
  persistence.saveCurrent     ← single save at end
  scheduleCloudSync           ← single sync at end
```

### CloudKit sync

- **Poll interval:** 5 seconds (`startListeningForChanges`)
- **Write guard:** `fetchLatestGame` skips if `hasPendingLocalChanges || isSaving`
- **Staleness check:** remote `lastModified > local lastModified` required to apply a fetch
- **Error handling:** network errors schedule a 30s retry; all errors caught (no silent swallowing)
- **Offline recovery:** `NWPathMonitor` fires `uploadOfflineGameToCloudKit` when connectivity is restored

---

## GameState & GameRules

`GameState` is a plain `Codable` struct — value semantics, no references. `GameManager` holds the sole copy; mutations follow the *copy-modify-assign* pattern (`var g = game; …; game = g`).

`GameRules` is embedded inside `GameState` and carries both the immutable game config (tasks, stake, handicap flag) and mutable carry-over values (`currentLowHoleValue`, `currentGreenieValue`) that change hole-by-hole.

### Schema evolution

Every field added after the initial release uses `decodeIfPresent` with a safe default:

```swift
teamLowPoints = try c.decodeIfPresent(Int.self, forKey: .teamLowPoints) ?? 2
```

This guarantees old CloudKit records load without crashing when new fields are absent.

### Key scoring dictionaries

| Field | Type | Purpose |
|---|---|---|
| `scores` | `[Int: [String: [String: Bool]]]` | Hole → player → task → won? |
| `strokeScores` | `[Int: [String: Int]]` | Hole → player → gross strokes |
| `repeatableCounts` | `[Int: [String: [String: Int]]]` | Hole → player → task → count (OB, Sand) |
| `lowHoleValues` | `[Int: Int]` | Hole → dots paid out (after carry-over) |
| `greenieValues` | `[Int: Int]` | Hole → dots paid out (after carry-over) |
| `teamLowWinner` | `[Int: String]` | Hole → "A" or "B" (team mode) |

---

## Dot Calculation (Helpers.swift)

All dot math is in pure free functions — no access to `GameManager`, no side effects.

```
holePar(game:hole:)
  └── prefers loaded course data; falls back to 3 for holes in game.rules.par3Holes, 4
      otherwise. Shared by the Birdie/stroke reconciliation in GameManager and
      ScorecardView.par(_:) so the two can't disagree on what a hole's par is.

calculateTotalDots(game:)
  └── if team mode → calculateTeamModeDots(game:)
      else         → loop scores + repeatableCounts (standard logic)

calculateHoleDots(game:hole:)
  └── if team mode → calculateTeamModeHoleDots(game:hole:)
      else         → same loop scoped to one hole

calculateNetScore(playerHandicap:grossScore:holeNumber:holePar:courseData:)
  └── single source of truth for handicap-adjusted net score; par-3 holes always get 0
      strokes, the full handicap is distributed across non-par-3 holes re-ranked by
      difficulty. Used by the Low Hole auto-award, the stroke picker's net-score tooltip,
      and the Scorecard's NET column — all three call this instead of keeping their own copy.

calculateCappedDebts(game:) -> [(payer: Player, owes: [(to: Player, amount: Int)])]
  └── per-payer debts derived from calculateTotalDots, with the Maximum Owed cap applied
      when game.rules.maxOwedEnabled. Mirrors GameOverView's settlement math so
      GameHistoryView's lifetime-winnings leaderboard always agrees with what was actually
      shown/settled at the end of each game.
```

**Team mode dot routing:**
- Positive task scored by player on Team A → Team A dots
- Negative task scored by player on Team A → Team B dots (penalty flows to opponents)
- Team Low winner → winning team dots (additive with individual Low Hole)
- Team total = sum of both players' split dots (odd remainder goes to player 0)

---

## Carry-Over Logic

Both Low Hole and Greenie carry forward when no one wins a hole, accumulating until claimed.

The single source of truth for carry-over math is:

```swift
calculateCarryOverResult(
    holesCarried: Int,   // pot / basePoints - 1
    pointValue:   Int,   // task.points (base per hole)
    limitEnabled: Bool,  // task.carryOverLimitEnabled
    limit:        Int,   // task.carryOverLimit
    resetToZero:  Bool   // task.carryOverResetToZero
) -> (payout: Int, newCarryOver: Int)
```

| Condition | Payout | Next carry |
|---|---|---|
| No limit | Full pot | Base points |
| Limit + reset-to-zero | Full pot | Base points |
| Limit, no reset | `(min(carried, limit) + 1) × base` | `(excess + 1) × base` |

All three consumers (`cappedLowHolePayout`, `checkAndUpdateLowHoleValue`, `recalculateLowHoleCarryover`) delegate to this function.

---

## Team Mode

Team assignments are derived from player order: players[0–1] = Team A, players[2–3] = Team B. No separate team assignment store — `teamForPlayer(_:)` computes the assignment on the fly from `teamAssignments`, a computed dict on `GameState`.

Team Low is auto-awarded in `autoAwardTeamLow` alongside the individual Low Hole in `autoAwardLowHole`. Both run on every `advanceHole` / `setHole` call.

Team names (`teamNameA`, `teamNameB`) live in `GameRules` so they travel with the game record through CloudKit and history.

---

## Persistence

`PersistenceManager` uses `UserDefaults` with `JSONEncoder`/`JSONDecoder`:

| Key | Content |
|---|---|
| `currentGame` | The active `GameState` (written on every score change) |
| `gameHistory` | Array of completed `GameState` values |

The Widget reads from an `AppGroup` UserDefaults via `GameManager+Widget.swift`.

---

## CloudKit Record Fields

| Field | Type | Notes |
|---|---|---|
| `gameID` | String | 6-char join code |
| `playersJSON` | Data | `[Player]` |
| `rulesJSON` | Data | `GameRules` (includes tasks, carry-over config, team names) |
| `scoresJSON` | Data | `[Int: [String: [String: Bool]]]` |
| `strokeScoresJSON` | Data | `[Int: [String: Int]]` |
| `repeatableCountsJSON` | Data | `[Int: [String: [String: Int]]]` |
| `lowHoleValuesJSON` | Data | `[Int: Int]` |
| `greenieValuesJSON` | Data | `[Int: Int]` |
| `teamLowWinnerJSON` | Data | `[Int: String]` |
| `photosJSON` | Data | `[HolePhoto]` |
| `sideBetsJSON` | Data | `[SideBet]` |
| `currentHole` | Int | |
| `isActive` | Bool | |
| `completedDate` | Date? | Signals non-host players to show results |
| `lastModifiedDate` | Date | Used by polling staleness check |
| `joinedPlayerIDsJSON` | Data | `Set<String>` |
| `golfCourseJSON` | Data | `GolfCourse?` |
| `courseDataJSON` | Data | `GolfCourseData?` |

---

## Testing

`PapaDotTests` covers pure `Helpers.swift` math and `GameManager` mutator contracts (e.g. `updateCounter` incrementing exactly once per scoring call, Birdie/stroke reconciliation) by constructing a `GameManager` directly and driving it with `manager.game = ...; manager.isHost = true`.

`PapaDotUITests` drives the real app through `XCUIApplication`. Tests launch with the `-UITesting` argument, which `GameManager.init()` checks first: it skips `persistence.loadCurrent()`, CloudKit, and course/API lookups entirely and synthesizes a fixed 2-player (`Alice`/`Bob`), active, offline game in memory, landing directly on a deterministic Score screen.

XCUITest's accessibility tree reflects SwiftUI's *logical* view state, not the composited/rendered pixels — an `isSelected`-style assertion can pass even when a control's rendered appearance is stale (the failure mode behind the v1.28 toggle fix). Where that distinction matters, tests also capture an `XCUIElement.screenshot()` and average its pixel color rather than relying on accessibility state alone — note that even this did not reproduce a failure against the pre-fix code on this Simulator/iOS build, so treat it as defense in depth rather than proven coverage of that specific bug.
