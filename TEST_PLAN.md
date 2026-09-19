# PapaDot Test Plan

Status as of 2026-09-19, v1.30 (build 20260919). Covers every feature in `README.md`.
Baseline: `xcodebuild test` — **33/33 passing** (28 `PapaDotLogicTests`, 5 `PapaDotUITests`),
up from 27 at the start of this audit.

This document has two parts:
1. **Findings** — concrete bugs found while auditing `Helpers.swift`, `GameManager.swift`,
   `PersistenceManager.swift`, `NassauMatch.swift`, `SideBetsView.swift`, `GameManager+Widget.swift`,
   and the widget extension, for this test plan. None of these were covered by the suite at the
   time they were found (that's *why* they survived). 11 findings total, ordered roughly by
   real-world impact — **all 11 are now resolved**, see each finding's "Fix applied" note.
2. **Test Plan** — a full manual/automated checklist by feature area, noting existing automated
   coverage and flagging gaps.

---

## Part 1 — Findings (logic/bugs found during this audit)

### 1. ✅ FIXED — Host's Waiting Room can never learn a guest joined — `lastModifiedDate` is never stamped on game creation or join

**Files:** `GameManager.swift` — `createGame` (~96-119), `joinGame`'s join-save (~220-223), `fetchLatestGame`'s staleness gate (~888)

`createGame` never sets `record["lastModifiedDate"]`, and `joinGame`'s write of `joinedPlayerIDsJSON` back to CloudKit doesn't either. `fetchLatestGame`'s gate only applies a fetch when `latest.lastModified > currentGame.lastModified`. A CloudKit record with no `lastModifiedDate` decodes to `.distantPast`, while the host's freshly-created local `GameState` defaults `lastModified` to `Date()` — so `.distantPast` is never newer than "now," and the gate silently fails **forever** for this specific transition.

**Concrete failure:** Host creates a game and sits on the Waiting Room screen. A guest joins with a valid code; their `joinedPlayerIDsJSON` write lands in CloudKit fine. The host's Waiting Room never shows the new player — not after 5s, not ever — because nothing in the join-save path stamps a `lastModifiedDate` newer than what the host already has. Fix direction: stamp `lastModifiedDate` on both the initial record save and the join-save.

**Fix applied:** `createGame` now stamps `record["lastModifiedDate"] = Date() as NSDate` on the initial record before saving. `joinGame`'s join-save now stamps `fetched.lastModified = Date()` and writes the same value to `record["lastModifiedDate"]` before saving, so the host's next poll sees a strictly newer timestamp and applies the fetch.

### 2. ✅ FIXED — `hasPendingLocalChanges` can get stuck `true` forever on a persistent (non-network) CloudKit error, silently halting all inbound sync

**File:** `GameManager.swift` — `updateCloudGame`'s catch-all (~821-823), `fetchLatestGame`'s guard (~872/882)

The bare `catch { scheduleRetrySync(afterSeconds: 30) }` never clears `hasPendingLocalChanges`. If the underlying error is persistent rather than transient (iCloud sign-out, quota exceeded, permissions failure — not just a flaky network blip), the flag never clears, and every future `fetchLatestGame` poll skips applying remote state, with **no user-facing indication sync has stopped**. Only an app relaunch resets it (fresh `GameManager` instance).

**Concrete failure:** User signs out of iCloud mid-round (or hits an account-level CloudKit restriction). The next local score change fails to sync and sets `hasPendingLocalChanges = true`; it's never cleared. From that point on, this device stops receiving any updates from other players for the rest of the session, with no error banner or retry indicator visible.

**Fix applied:** `updateCloudGame` now tracks `consecutiveSyncFailures`, counted only on non-network errors (network errors keep the prior indefinite-retry behavior, since they're expected to resolve on their own). After 3 consecutive non-network failures, it gives up, clears `hasPendingLocalChanges` so `fetchLatestGame` can resume, and sets a new `syncError: String?` property (mirroring the existing `joinError` pattern) — not yet wired into any UI, but available for a future banner rather than failing silently. The counter and error reset on the next successful sync and in `startNewGame()`.

### 3. ✅ FIXED — `autoAwardLowHole`/`autoAwardTeamLow` use a second, wrong copy of "hole par" — can flip who wins Low Hole

**Files:** `PapaDot/Managers/GameManager.swift:289` and `:331`

```swift
let holePar = game.courseData?.holes?.first(where: { $0.number == hole })?.par ?? 4
```

This ignores `game.rules.par3Holes` entirely — unlike the canonical `holePar(game:hole:)` in
`Helpers.swift:8`, which falls back to `game.rules.par3Holes.contains(hole) ? 3 : 4`.
`game.rules.par3Holes` is exactly the fallback CreateGameView populates when the golf course API
returns no per-hole data (`Par3EntryView`'s manual par-3 flow, or the `Par3EntryCache` — see
`CreateGameView.swift:344-361`, both of which build a `GolfCourseData` with `holes: nil`). This
is a real, reachable state: `courseData != nil` but `courseData.holes == nil`.

**Concrete failure:** Hole 5 is a manually-entered par-3 (no full scorecard, `courseData.holes ==
nil`). Player A enters a legitimate bogey (4) and it's saved via the stroke picker. Player B never
opens the stroke picker for that hole and just taps Next. Correct par for the hole is 3, so B
should default to gross 3 and win Low Hole outright (3 < 4). Instead `autoAwardLowHole` defaults
B's missing score to the hardcoded `4`, so A and B tie at 4–4 — **no one wins Low Hole and the pot
incorrectly carries over**, instead of B winning it.

This is the exact "divergent copy of a shared formula" bug class flagged in `CLAUDE.md` as a
repeat offender (three previous divergent net-score copies). Fix direction: replace both inline
calculations with a call to `holePar(game:hole:)`.

**Fix applied:** both `autoAwardLowHole` and `autoAwardTeamLow` now call `holePar(game:hole:)` (bound to a locally-named `parForHole` to avoid shadowing the free function). New regression test: `testAdvanceHole_NoCourseData_ManualPar3Hole_UnscoredPlayerDefaultsToCorrectPar`.

### 4. ✅ FIXED — Checking "Birdie" without full course data doesn't update the stroke score

**File:** `PapaDot/Managers/GameManager.swift:462-465`

```swift
if task == "Birdie",
   let holeData = g.courseData?.holes?.first(where: { $0.number == hole }) {
    g.strokeScores[hole, default: [:]][playerName] = wasOn ? holeData.par : holeData.par - 1
}
```

Unlike `setStrokeScore` and `adjustRepeatableCount`'s OB branch (both of which call the
fallback-safe `holePar(game:hole:)`), this block requires real `courseData.holes` data and
silently no-ops without it — the same `courseData.holes == nil` state as Finding 3.

**Concrete failure:** No full course data loaded. Player checks "Birdie" on hole 7 (par 3, per
manual `par3Holes` entry). The Birdie dot is still awarded (its points come from `task.points`,
independent of strokes), but `strokeScores[7][player]` is never set to `par - 1`. Any code that
reads gross score off `strokeScores` for that hole (`autoAwardLowHole`'s default, Nassau's
`calculateNassauResult`, the Scorecard's gross/net columns) still sees the hole as unplayed and
defaults to par — so the player's net score for Low Hole/Nassau purposes doesn't reflect the
birdie they were just credited for elsewhere. Fix direction: use `holePar(game: g, hole: hole)`
instead of requiring `courseData.holes`.

**Fix applied:** `toggleScore`'s Birdie branch now calls `holePar(game: g, hole: hole)` unconditionally, so it works with or without a full course scorecard. New regression test: `testToggleScore_BirdieOn_NoCourseData_ManualPar3Hole_SetsStrokeScoreToParMinusOne`.

### 5. ✅ FIXED — Side-bet settle dialog lets you assign the win to a player who isn't even a participant

**Files:** `SideBetsView.swift` (`SideBetCard`'s confirmation dialog, ~183-188), `GameManager.settleSideBet(id:winner:)` (~695-704)

The settle-bet confirmation dialog does `ForEach(players)` — every player in the game — instead of `ForEach(bet.participants)`. `settleSideBet` does no validation that `winner` is actually among `sideBets[idx].participants` either.

**Concrete failure:** Create a side bet with participants `["Alice", "Bob"]` (Carol excluded). Tap Settle, pick "Carol" from the dialog. `winnerId` is now a name that never opted into the bet, and `calculateSideBetPayouts` (audited separately, math itself is correct) computes a payout split among `participants` that doesn't include the actual declared winner — producing a nonsensical settlement (e.g. "winner" owes money to people, or the split is over the wrong pool). Fix direction: filter the dialog to `bet.participants`, and add a `guard bet.participants.contains(winner)` in `settleSideBet`.

**Fix applied:** the settle dialog now filters to participants matching by id or name (see Finding 6), and `settleSideBet` gained `g.sideBets[idx].participants.contains(winner)` as part of its guard. New regression test: `testSettleSideBet_RejectsWinnerNotInParticipants`.

### 6. ✅ FIXED — Side bets identify players by display name, not a stable id — two same-named players collide

**Files:** `GameState.swift` (`SideBet.participants: [String]` / `winnerId: String?`, ~16-17), `SideBetsView.swift`'s `AddSideBetView` (~281-299, 310-319)

Side bets key entirely on `player.name`, unlike Nassau (which correctly uses stable `playerAID`/`playerBID`, `NassauMatch.swift:9-10`). `ARCHITECTURE.md` itself already warns "two devices can easily share the same `userName`... name equality is not a valid identity check" for host auth — but side bets rely on exactly that. `CreateGameView`'s player entry has no uniqueness check on names.

**Concrete failure:** Two players both named "Mike" join a game. Adding a side bet with both as participants collapses them into one `Set<String>` entry (only one "Mike"), and settling with winner "Mike" is ambiguous as to which one gets paid. Fix direction: key `SideBet` on stable player ids, matching the Nassau pattern.

**Fix applied:** `AddSideBetView` now stores `player.id` in `participants`/`selectedParticipants` instead of `player.name`. `calculateSideBetPayouts` (Helpers.swift) resolves an identifier to a display name via `game.players.first(where: { $0.id == identifier })?.name ?? identifier` — an id match wins, and a raw string that doesn't match any id (i.e. an older bet that still holds a name from before this fix) falls through to being used as-is, so already-persisted/synced bets keep displaying correctly. `SettledBetCard` and `SideBetCard`'s settle dialog do the same id-or-name resolution/matching. `calculateSideBetPayouts`'s return type gained a resolved `winnerName: String` field so `GameOverView`'s Payouts tab and iMessage share text no longer read `bet.winnerId` raw. New regression test: `testCalculateSideBetPayouts_DuplicatePlayerNames_DistinguishedByStableId`.

### 7. ✅ FIXED — Concurrent `NWPathMonitor` callbacks can create duplicate CloudKit records for the same offline-created game

**File:** `GameManager.swift` — `startNetworkMonitorForOfflineGame`'s `pathUpdateHandler` (~1041-1046), `uploadOfflineGameToCloudKit` (~1055-1083)

`pathUpdateHandler` spawns a new `Task { await uploadOfflineGameToCloudKit() }` on *every* `.satisfied` event, with no in-flight guard (unlike `isSaving`, which protects the normal save path). `uploadOfflineGameToCloudKit`'s only guard (`guard isOfflineMode, let g = game, g.recordID == nil`) is checked synchronously before the first `await` — since it's `@MainActor`, two such Tasks triggered close together (e.g. a WiFi↔cellular handoff firing `.satisfied` twice) can both pass the guard before either updates `isOfflineMode`/`recordID`, and both save a **separate new `CKRecord`** — two CloudKit records sharing the same `gameID`.

**Concrete failure:** Create a game fully offline, then walk into an area with flaky connectivity that flips satisfied/unsatisfied/satisfied in quick succession. Two CloudKit records for the same round now exist; a guest joining with the game's code could land on either one depending on which the join-search happens to match, potentially the "wrong" (stale) copy.

**Fix applied:** added `isUploadingOfflineGame` guard (mirroring the existing `isSaving` pattern for `updateCloudGame`), checked and set before any `await` so a second concurrent invocation returns immediately instead of racing to save its own `CKRecord`. Reset in `startNewGame()`. Hard to unit test directly (real `NWPathMonitor`/CloudKit timing) — treat as a manual regression check per §1.16.

### 8. ✅ FIXED — Widget shows hardcoded fake leaderboard data whenever there's no active game

**Files:** `PapaDotWidget.swift` (`fetchCurrentGame()`, ~60-75; `SmallWidgetView`, ~136-188)

When `UserDefaults(suiteName:).data(forKey: "currentGame")` is `nil` — exactly the state right after `GameManager.clearWidgetData()` runs on game completion, or before any game has ever been played — `fetchCurrentGame()` returns **hardcoded fake data**: players "Jeff" (+14, leader), "Scott" (+12), "Yelena" (+11), "Jim" (+10), `courseName: "No Active Game"`, `isActive: false`. Nothing in `SmallWidgetView`/`MediumWidgetView`/`LargeWidgetView` branches on `entry.isActive` for *what to render* (only for refresh-interval timing) — `SmallWidgetView` doesn't render `courseName` at all.

**Concrete failure:** Finish a round (or never having started one). The home-screen widget (small size especially) shows a fully fabricated leaderboard — "JP / Jeff / +14 👑" with a crown icon — indistinguishable from a real live game, forever, until a new round starts. Medium/Large sizes at least show "No Active Game" as the course name next to the same fake scores, which is confusing but has a tell. Fix direction: replace the fake fallback data with a real "no active game" empty state in all three widget sizes.

**Fix applied:** `fetchCurrentGame()`'s no-game fallback now returns an empty `players: []` array instead of fabricated standings. All three widget views (`SmallWidgetView`, `MediumWidgetView`, `LargeWidgetView`) now branch on `entry.players.isEmpty` and render a real "No Active Round" empty state (flag-slash icon + text) instead of falling through to render whatever `entry.players` happens to contain. `placeholder(in:)`/`getSnapshot`/`#Preview` still use representative sample data, which is normal, expected WidgetKit gallery/preview behavior, not the bug — only the live timeline entry shown to real users was fabricated.

### 9. ✅ FIXED — Editing a completed round's scores overwrites its history `completedDate` to "now"

*(Independently confirmed by two separate audits of this codebase.)*

**File:** `PapaDot/Utilities/PersistenceManager.swift:68-77`

```swift
func saveToHistory(_ game: GameState) {
    var history = loadHistory()
    var completed = game
    completed.completedDate = Date()   // <-- always "now"
    ...
}
```

`saveToHistory` has exactly two call sites, both in `GameManager.advanceHole()`
(`GameManager.swift:522` and `:527`), and both already run *after* `g.completedDate = g.completedDate
?? Date()` (line 515) has stamped the game with its true completion time. The unconditional
overwrite here is at best redundant and at worst destructive.

**Concrete failure:** Finish a round on Monday. Days later, use `setHole` to go back and correct a
misentered score, then advance back through to hole 18. `advanceHole`'s "user went back to edit
scores" branch (line 526-527) calls `removeFromHistory` + `saveToHistory(g)` — but `g.completedDate`
is still correctly Monday's date at that point (preserved by the `?? Date()` on line 515). `saveToHistory`
then stomps it to today's date anyway, so **Game History now shows the round as played today**, not
Monday. Fix direction: `completed.completedDate = game.completedDate ?? Date()`.

**Fix applied:** `saveToHistory` now does `completed.completedDate = game.completedDate ?? Date()`, preserving the true completion date. New regression test: `testSaveToHistory_PreservesOriginalCompletedDate_NotOverwrittenToNow`.

### 10. ✅ FIXED — `SideBetsView` has no host gating — guests can "successfully" add/settle/delete bets that silently no-op

**File:** `PapaDot/Views/SideBetsView.swift` (whole file — no `manager.isHost` reference anywhere)

Per `ARCHITECTURE.md`, every other scoring-adjacent view (`ScoreEntryView`, `ScorecardView`,
`GameOverView`) reads `manager.isHost` to hide/disable controls as a UX nicety on top of the real
manager-level guard. `SideBetsView` never does this — the "Settle", the trash/delete button, and
the "New Side Bet" FAB are all shown and tappable for guest players.

Because `GameManager.addSideBet`/`settleSideBet`/`deleteSideBet` correctly guard on `isHost`
(confirmed in code, fixed in v1.29), a guest tapping these doesn't corrupt data — but it's a
real, reproducible UX bug that's worse than doing nothing: **`AddSideBetView`'s "Add" button calls
`onAdd(bet)` then unconditionally `dismiss()`** (`SideBetsView.swift:320-321`), so a guest who
fills out a new side bet and taps "Add" sees the sheet close as if it succeeded — with no
indication the bet was never actually created. Same silent-no-op UX for Settle/Delete confirmations.
Fix direction: gate the FAB/Settle/Delete controls on `manager.isHost`, matching every other view.

**Fix applied:** the "New Side Bet" FAB is now hidden entirely (not just disabled) when `!manager.isHost`, matching the pattern elsewhere in the app. `SideBetCard` gained an `isHost` parameter and hides its Settle/Delete buttons when false. Since the FAB is gone for guests, `AddSideBetView`'s sheet is simply unreachable for them — no separate fix needed there.

### 11. ✅ RESOLVED (documentation, not a bug) — `calculateCarryOverResult`'s excess-clamp isn't in `ARCHITECTURE.md`, and isn't tested

**File:** `PapaDot/Managers/GameManager.swift:609-634`

`ARCHITECTURE.md`'s table says, for "Limit, no reset": `newCarryOver = (excess + 1) × base` where
`excess = holesCarried − limit`. The actual code additionally clamps that excess to at most
`limit − 1` before computing `newCarryOver` (see the `clampedRemainder` line), with a comment
explaining the intent ("so the carry never triggers a second capped win"). For `holesCarried` more
than roughly `2 × limit`, the two formulas diverge (e.g. `limit=3, holesCarried=10`: doc formula
gives `newCarryOver = 8×base`, actual code gives `3×base`). This may well be the intended design —
the code comment suggests it is — but there's no test locking in this behavior for a long unclaimed
streak, and the architecture doc doesn't mention the clamp at all. Recommend either updating
`ARCHITECTURE.md`'s table with the clamp, or adding a test for `holesCarried > 2×limit` to confirm
the clamped value is intentional (see Test Plan §2.4 below).

**Resolution:** confirmed intentional by tracing the math — the clamp guarantees a single long unclaimed streak can't, by itself, hand the next round enough of a head start to trigger a second capped payout on the very next win. `ARCHITECTURE.md`'s Carry-Over Logic table now documents the clamped formula (`(min(excess, limit - 1) + 1) × base`) and explains why, and also corrects a separate small doc inaccuracy found while in there — `calculateCarryOverResult` is a private `GameManager` method, not a free function in `Helpers.swift` as the doc previously implied. New regression test: `testCheckAndUpdateLowHoleValue_LongUnclaimedStreak_ExcessClampedNotFullRemainder`, which drives 10 tied holes through the real `advanceHole()` flow and asserts the clamped carry value.

---

## Part 2 — Test Plan by Feature Area

Legend: 🤖 = covered by an existing automated test · 🧪 = needs a new automated test (good
candidate for `PapaDotLogicTests`) · 👆 = manual/UI only.

### 1. Multiplayer & Sync
| # | Test | Notes |
|---|---|---|
| 1.1 | Host creates game, gets a 6-char code | 👆 |
| 1.2 | Guest joins with `<gameID><playerIndex>` (7-char) code before host starts round → lands in waiting room | 👆 |
| 1.3 | Guest joins after host already started (`isActive == true`) → skips waiting room straight to scoring | 👆 (`GameManager.swift:230-232`) |
| 1.4 | Invalid/expired code → `joinError` shown, no crash | 👆 |
| 1.5 | Join code with out-of-range player index → "Invalid join code" | 👆 |
| 1.6 | Two guest devices see host's score changes within ~5s (poll interval) | 👆, needs 2 physical/simulator devices |
| 1.7 | Guest device taps a scoring control → no-op (guest is never host) | 🤖 `testSideBetMutators_NoOpWhenNotHost`, `testAddRemoveNassauMatch_NoOpWhenNotHost` cover the manager layer; UI-level hiding is now consistent across views (see Finding 10 fix) but has no dedicated UI test |
| 1.14 | Guest joins while host is sitting on the Waiting Room | 👆 — currently **fails**, see Finding 1 (`lastModifiedDate` never stamped) |
| 1.15 | CloudKit save fails with a persistent (non-network) error, e.g. simulated iCloud sign-out | 👆 — currently **fails silently forever**, see Finding 2 |
| 1.16 | Offline game upload during flaky connectivity (rapid satisfied/unsatisfied flips) | 👆 fixed, see Finding 7 — still needs a manual regression pass, not unit-testable |
| 1.8 | Non-host auto-advances to Game Over when host finishes hole 18 | 👆 (`fetchLatestGame`, `GameManager.swift:901-903`) |
| 1.9 | Rapid successive score taps produce exactly one CloudKit write ~0.5s later, not one per tap | 👆, watch network/CK dashboard or logs |
| 1.10 | Offline-created game auto-uploads to CloudKit when connectivity returns | 👆, toggle airplane mode during/after game creation |
| 1.11 | CloudKit save fails 3x (simulate network loss) → local data preserved, 30s retry fires | 👆 |
| 1.12 | Remote fetch with `lastModified` *not* newer than local → ignored (no flicker/rollback) | 👆 |
| 1.13 | Remote fetch never regresses `currentHole` below local host's position | 👆 (`GameManager.swift:892-894`) |

### 2. Scoring
| # | Test | Notes |
|---|---|---|
| 2.1 | Stroke picker sets gross score; net score reflects handicap on non-par-3 holes only | 🤖 `testHandicap_Handicap18OnHandicap1Hole_WinsLowHoleAfterStrokeReduction` |
| 2.2 | Toggling Birdie ON with full course data sets strokes to `par - 1`; OFF resets to `par` | 🤖 `testSetStrokeScore_*` (via setStrokeScore path) |
| 2.3 | Toggling Birdie ON **without** full course data (manual par-3 entry) | 🤖 `testToggleScore_BirdieOn_NoCourseData_ManualPar3Hole_SetsStrokeScoreToParMinusOne` — fixed, see Finding 4 |
| 2.4 | `calculateCarryOverResult` for `holesCarried` well beyond `2×limit` | 🤖 `testCheckAndUpdateLowHoleValue_LongUnclaimedStreak_ExcessClampedNotFullRemainder` — resolved (documentation), see Finding 11 |
| 2.5 | Manual stroke edit clears a stale Birdie flag if new score ≠ `par - 1` | 🤖 `testSetStrokeScore_ClearsBirdieWhenScoreNoLongerMatchesParMinusOne` |
| 2.6 | Manual stroke edit that still equals `par - 1` leaves Birdie untouched | 🤖 `testSetStrokeScore_BirdieUnaffectedWhenScoreStillMatchesParMinusOne` |
| 2.7 | OB tick changes strokes and can clear a stale Birdie | 🤖 `testAdjustRepeatableCount_OBTick_ClearsBirdieWhenResultingScoreBreaksParMinusOne` |
| 2.8 | Auto Low Hole: single lowest net score wins; ties carry the pot forward | 🤖 (partially) `testAllPlayersTie_ZeroDotsForEveryone`; add a "2 of 3 tie for low, one clear winner elsewhere" case |
| 2.9 | Auto Low Hole default-gross-score fallback on a manually-flagged par-3 with no full course data | 🤖 `testAdvanceHole_NoCourseData_ManualPar3Hole_UnscoredPlayerDefaultsToCorrectPar` — fixed, see Finding 3 |
| 2.10 | Greenie carry-over: no winner accumulates; winner resets to base | 🤖 `testGreenieCarryOver_*` (4 variants) |
| 2.11 | Carry-over limit + reset-to-zero: winner takes full pot regardless of limit | 🧪 new — not explicitly covered |
| 2.12 | Carry-over limit, no reset: payout capped at `(min(carried,limit)+1)×base` | 🧪 new — table exists in `ARCHITECTURE.md` but no direct test found for the capped (non-Greenie/Low-Hole-specific) case |
| 2.13 | OB / Sand steppers clamp to 0–3, award dots to all *other* players (negative task) | 🤖 `testNegativeTask_OBAndThreePuttSameHole_EachOtherPlayerReceives2Dots`, `testNegativeTask_PlayerHitsSand_OtherPlayersEachReceive1Dot` |
| 2.14 | `updateCounter` increments exactly once per `toggleScore`/`adjustRepeatableCount` call | 🤖 `testToggleScore_IncrementsUpdateCounterExactlyOnce`, `testAdjustRepeatableCount_IncrementsUpdateCounterExactlyOnce` |
| 2.15 | Birdie + Greenie scored on the same hole are independent (both count) | 🤖 `testBirdieAndGreenieSameHole_BothCalculatedIndependently` |
| 2.16 | Score toggle UI updates the visible control immediately (no stale render) | 🤖 `testTaskToggleUpdatesImmediatelyOnTap`, `testStepperIncrementsImmediatelyOnTap` (regression test for the v1.28 incident) |
| 2.17 | Toggling one player's task doesn't affect another player's row | 🤖 `testTogglingOnePlayerDoesNotAffectAnother` |

### 3. Team Mode (2v2)
| # | Test | Notes |
|---|---|---|
| 3.1 | Players 0-1 = Team A, 2-3 = Team B, correct badges shown | 👆 |
| 3.2 | Positive task by a player credits their team; negative task credits the *opposing* team | 🤖 `testTeamMode_TeamAScoresBirdie_TeamASharesDots_TeamBGetsNothing` |
| 3.3 | Team Low is exclusive — winning team gets it, other team gets nothing | 🤖 `testTeamMode_LowHoleExclusive_TeamAWinsLowHole_TeamBReceivesNone` |
| 3.4 | Team Low tie → `teamLowWinner[hole]` stays nil, no one credited | 🧪 new — not explicitly covered |
| 3.5 | Odd total team dots split with remainder going to player index 0 | 🧪 new — worth a direct assertion (currently only implied by passing team tests) |
| 3.6 | Team totals/Team Low summary correct on Game Over screen | 👆 |
| 3.7 | `autoAwardTeamLow`'s par default bug (see Finding 3) applies here too | 👆 fixed alongside `autoAwardLowHole` (same `holePar` call); no dedicated team-mode test yet — the fix is identical code, covered indirectly |

### 4. Game Setup
| # | Test | Notes |
|---|---|---|
| 4.1 | Add/edit/remove custom tasks; save/load named presets | 👆 |
| 4.2 | Preset save/load in a team game restores Team Low points too | 👆 |
| 4.3 | Wager per dot applied correctly to payouts | 👆, cross-check against §7 |
| 4.4 | Maximum Owed cap redistributes proportionally, never negative, sums back to cap | 🧪 new — `calculateCappedDebts`'s scaling math (`Helpers.swift:75-92`) has no direct test found; verify last-payee-gets-remainder logic doesn't produce a negative `remaining` when `cap` is very small relative to debt count |
| 4.5 | Starting hole other than 1 — play order wraps correctly (front/back Nassau still uses fixed 1-9/10-18 regardless) | 🧪 new, see §5 Nassau notes |
| 4.6 | Handicap toggle off → net score always equals gross | 🤖 implied by `calculateNetScore`'s `guard playerHandicap > 0` — add an explicit `useHandicap == false` test |
| 4.7 | Game history read-only view for a past round | 👆 |
| 4.8 | Lifetime leaderboard respects max-owed cap and team payouts | 👆, cross-check `calculateCappedDebts` output against what was actually shown at game end |

### 5. Side Games — Nassau
| # | Test | Notes |
|---|---|---|
| 5.1 | Front 9 / back 9 / overall settle independently, hole-by-hole match play | 🤖 `testNassau_FrontWinBackPushOverallWin_AcrossFullRound` |
| 5.2 | Segment not resolved (no payout) until every hole in its range is reached | 🤖 `testNassau_SegmentNotResolvedUntilAllHolesReached` |
| 5.3 | Handicap on/off changes the effective segment winner | 🤖 `testNassau_HandicapChangesSegmentWinner` |
| 5.4 | Push (margin 0 at resolution) → no money changes hands | 🤖 (covered within `testNassau_FrontWinBackPushOverallWin_AcrossFullRound`'s "back" push) |
| 5.5 | Back 9 is holes 10-18 regardless of a non-default `startingHole` | 🧪 new — explicitly test with `startingHole != 1` |
| 5.6 | Referenced player no longer in roster → segment reports unresolved/zeroed, no crash | 🧪 new — `calculateNassauResult`'s early-return branch (`Helpers.swift:357-365`) has no test |
| 5.7 | `netSettlement` correctly nets multiple resolved segments to one signed payer→payee amount | 🧪 new |
| 5.8 | Nassau matches configured at setup survive into the *initial* CloudKit record (not just later syncs) | 👆 — join a game before the host's first score change and confirm Nassau tab is populated |
| 5.9 | Any number of Nassau pairings per round | 👆 |
| 5.10 | Nassau excluded from Maximum Owed cap | 👆, cross-check §4.4/§7 |
| 5.11 | Only the host can add/remove a Nassau match | 🤖 `testAddRemoveNassauMatch_NoOpWhenNotHost` — note: **no UI currently calls `addNassauMatch`/`removeNassauMatch`** (grep found zero call sites outside `GameManager.swift`); Nassau matches are only ever set at creation time via `createGame(nassauMatches:)`. Confirm this is intentional (no "add Nassau mid-round" UI is expected) rather than a missing feature. |

### 6. Side Games — Side Bets
| # | Test | Notes |
|---|---|---|
| 6.1 | Freeform bet among any subset of participants | 👆 |
| 6.2 | Settling splits the pot evenly across losers, remainder to first loser(s), sums to `amount` | 🤖 `testCalculateSideBetPayouts_UnevenSplitSumsExactlyToAmount` |
| 6.3 | Unsettled (active) bets produce no payout line | 🧪 new — implied but not directly asserted |
| 6.4 | Only host can add/settle/delete a side bet (manager layer) | 🤖 `testSideBetMutators_NoOpWhenNotHost` |
| 6.5 | **Guest-visible UI gating on Settle/Delete/Add** | 👆 fixed, see Finding 10 — FAB/Settle/Delete now hidden for guests; no dedicated UI test added (no existing UI-test coverage of guest-vs-host view state to extend) |
| 6.6 | Side bets excluded from Maximum Owed cap | 👆, cross-check §4.4/§7 |
| 6.7 | Settle dialog only offers the bet's actual participants as winner choices | 👆 fixed, see Finding 5 — `testSettleSideBet_RejectsWinnerNotInParticipants` covers the manager-level guard; the dialog's own filtering is UI-only |
| 6.8 | Two players with the same display name in one side bet | 🤖 `testCalculateSideBetPayouts_DuplicatePlayerNames_DistinguishedByStableId` — fixed, see Finding 6 |

### 7. Security & Data Integrity (host authorization)
| # | Test | Notes |
|---|---|---|
| 7.1 | Every scoring mutator (`setStrokeScore`, `toggleScore`, `adjustRepeatableCount`, `setHole`, `advanceHole`) guards on `isHost` | 🤖 covered indirectly by the update-counter/reconciliation tests all constructing `manager.isHost = true`; add an explicit `isHost = false` no-op test per mutator (only side bets/Nassau currently have one) |
| 7.2 | `isHost` survives app relaunch mid-round (persisted device-locally) | 👆 — kill and relaunch the app mid-round on host and guest devices, confirm roles unchanged |
| 7.3 | `isHost` is never derivable from `userName` or `recordID != nil` | 🤖 implicitly true by inspection (`GameManager.swift:65-69`); no test needed unless someone reintroduces a shortcut |
| 7.4 | `addPhoto`/`removePhoto` intentionally ungated — guests can add their own hole photos | 👆 |

### 8. End of Round
| # | Test | Notes |
|---|---|---|
| 8.1 | Stats tab: dot bar chart, task breakdown, best hole, loser labels | 👆 |
| 8.2 | Team stats card shows Team Low wins per team | 👆 |
| 8.3 | Payouts tab shows Dots/Side Bets/Nassau sections, each only if non-empty | 👆 |
| 8.4 | "Everyone Even!" empty state only when *all three* categories are empty | 👆 — regression test for the v1.29 fix |
| 8.5 | iMessage share text matches on-screen Dots/Side Bets/Nassau breakdown | 👆 — regression test for the v1.27 vanishing-category bug |
| 8.6 | Editing scores after game completion and re-finishing updates the *same* history entry (not a duplicate) with correct `completedDate` | 🤖 `testSaveToHistory_PreservesOriginalCompletedDate_NotOverwrittenToNow` — fixed, see Finding 9 |

### 9. Persistence & Schema Evolution
| # | Test | Notes |
|---|---|---|
| 9.1 | Old locally-persisted `GameState` (missing newer fields) loads without crashing | 🧪 new — construct a JSON blob missing e.g. `nassauMatches`/`teamLowWinner` and decode it |
| 9.2 | Corrupted/invalid persisted state is discarded on launch, not crashed on | 🧪 new — `GameManager.isValidRestoredState` (`GameManager.swift:80-84`) has no direct test |
| 9.3 | App Group migration from `UserDefaults.standard` runs exactly once | 👆 — hard to unit test without mocking `UserDefaults`; at minimum manually verify on an upgrade from a pre-App-Group build if such a build still exists |
| 9.4 | `lookupLastHandicap` sentinel handling (`-1` = absent field vs. `0` = scratch) | 🧪 new — `GameManager.swift:153-168`'s special-casing has no direct test |

### 10. Widget
| # | Test | Notes |
|---|---|---|
| 10.1 | Widget reflects current game state after a score change (debounced ~400ms, verified separate from the 0.5s CloudKit debounce) | 👆 |
| 10.2 | Widget clears when game ends / new game starts | 👆 (`clearWidgetData`) — but see 10.3, clearing doesn't mean the widget then shows nothing |
| 10.3 | Widget shows a real empty state with no active game | 👆 fixed, see Finding 8 — visually verify on-device/Simulator widget gallery, not unit-testable (widget target has no test suite) |
| 10.4 | App Group identifier matches between write side (`GameManager+Widget.swift`) and read side (widget extension) | 🤖 confirmed correct by inspection — `"group.com.jeffpaz.PapaDot"` / key `"currentGame"` match on both sides; add a regression test if either side ever changes |

### 11. Golf Course Lookup
*(Already covered by this session's earlier work — see `CHANGELOG.md` v1.30 entry. Included here
for completeness of the full test matrix.)*
| # | Test | Notes |
|---|---|---|
| 11.1 | Search finds nearby courses via Google Places | 👆 |
| 11.2 | Selecting a course pulls full scorecard (par/yardage/handicap) via golfcourseapi.com | 👆 |
| 11.3 | 9-hole/executive courses (e.g. Blackberry Farm) load correctly | 👆 — fixed this session |
| 11.4 | Courses whose `/v1/search` tees field is an int count, not an array (e.g. Sunnyvale Gc) still resolve | 👆 — fixed this session |
| 11.5 | Manual par-3 entry fallback when no API scorecard is available | 👆 — see Findings 3 & 4 above for bugs in this exact path |
| 11.6 | Decode/network failures produce a diagnosable console log, not a silent empty scorecard | 👆 — added this session |

---

## Suggested Next Steps

**All 11 findings are resolved.** 9 were real bugs with code fixes and regression tests
(1, 3, 4, 5, 6, 7, 8, 9, 10); Finding 11 turned out to be intentional design, resolved by
documenting it in `ARCHITECTURE.md` and adding a test to lock in the behavior so it isn't
"fixed" away by accident later. The automated suite is at 33 tests (28 logic + 5 UI), up from
the original 27.

**What's not covered by automated tests, and still worth a manual pass before the next release:**

- Findings 1, 2, and 7 are CloudKit timing/race conditions (join-save staleness, a stuck sync
  flag after a persistent error, concurrent offline-upload). The fixes are in and the full suite
  stays green, but none of these paths are reachable from `PapaDotTests`' in-memory `GameManager`
  construction — they need two physical/simulator devices and deliberately induced network
  conditions to be confident (§1.14-1.16).
- Finding 8 (widget empty state) has no automated coverage at all — the widget extension target
  has no test suite — so it needs a visual check in the widget gallery after finishing a round
  (§10.3).
- Finding 10 (side-bet host gating) fixed the UI but has no dedicated UI test — there's no
  existing pattern in `PapaDotUITests` for asserting guest-vs-host view state to extend.

See Part 1 above for the "Fix applied" note under each finding, and Part 2 for the full
per-feature checklist with current 🤖/🧪/👆 coverage status.
3. Do the manual regression pass noted above for Findings 1, 2, and 7 before the next release —
   these are the ones this session's automated suite can't fully prove.
