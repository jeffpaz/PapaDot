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
```

---

## GameManager

`GameManager` is an `@Observable` class injected at the app root via `.environment`. All views read from it; only the host player's device writes to it during a round.

### Key state

| Property | Purpose |
|---|---|
| `game: GameState?` | Nil between rounds; non-nil while a round is active |
| `isHost: Bool` | Only the host may call `advanceHole`, `setHole`, score toggles |
| `isMultiplayer: Bool` | True when a CloudKit record exists |
| `isOfflineMode: Bool` | True when game was created without connectivity |
| `hasPendingLocalChanges: Bool` | Blocks polling from overwriting unsaved local state |
| `isSaving: Bool` | Blocks polling during an in-flight CloudKit save |

### Scoring write path

```
User tap → manager.toggleScore / adjustRepeatableCount / setStrokeScore
         → mutate game (local struct copy)
         → persistence.saveCurrent(g)          ← immediate local persist
         → scheduleCloudSync()                  ← debounced 0.5s CloudKit write
```

`scheduleCloudSync` cancels any pending upload and restarts a 0.5s Task. Rapid successive taps produce exactly one CloudKit write, 0.5s after the last tap.

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
calculateTotalDots(game:)
  └── if team mode → calculateTeamModeDots(game:)
      else         → loop scores + repeatableCounts (standard logic)

calculateHoleDots(game:hole:)
  └── if team mode → calculateTeamModeHoleDots(game:hole:)
      else         → same loop scoped to one hole
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
