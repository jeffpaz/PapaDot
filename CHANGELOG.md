# PapaDot Changelog

## Version 1.7 — Multiplayer Finish, Handicap Fix, OB Fix
*May 29, 2026*

---

### New Features

**Auto-Advance to Results for Non-Host Players**
- When the host taps "Finish" on hole 18, all other players' screens automatically navigate to the Round Complete results view
- Previously, non-host players had to manually tap "End" to see results
- Implementation: host stamps `completedDate` on the game state and syncs it to CloudKit; the 5-second polling loop on each non-host device detects the field and sets `showGameOver = true`

### Bug Fixes

**Handicap Excludes Par 3 Holes**
- Par 3 holes no longer receive any handicap strokes
- Previously, high-handicap players (20+) received up to 1 stroke on par 3s
- Now, a player's full handicap is distributed only across non-par-3 holes, re-ranked among themselves by hole difficulty (e.g. a 10-handicap on a course with 14 non-par-3 holes gets strokes on the 10 hardest of those 14 holes)
- Applies to both net score display in the stroke picker and Low Hole auto-award calculation

**OB Stroke Adjustment Using Wrong Baseline**
- Fixed: tapping OB for a player showing par (e.g. 4) would set their score to 1 instead of 5
- Root cause: the OB adjustment code defaulted to `0` when no explicit stroke score had been entered, while the picker displayed `defaultPar` — the mismatch caused the first OB tap to write `0 + 1 = 1` instead of `par + 1`
- Fix: OB adjustment now uses the hole's par as the fallback baseline, matching the picker display

**Finish Button Silent After "Back to Hole 18"**
- Fixed: after finishing on hole 18, tapping "Back to Hole 18" and then "Finish" again did nothing
- Root cause: `historySaved = true` after the first finish prevented `showGameOver` from being set again
- Fix: `showGameOver = true` is now set unconditionally on the last hole; a re-finish removes the old history entry and saves an updated one with the latest scores

---

## Version 1.6 — OB Stats & Auto-Stroke
*May 28, 2026*

---

### New Features

**OB Auto-Increments Stroke Score**
- Tapping OB for a player now automatically adds 1 to their stroke count for that hole
- Removing an OB subtracts 1 stroke (clamped to 0)

### Bug Fixes

**OB and Sand Missing from End-of-Round Stats**
- Fixed: OB and Sand counts were calculating dots correctly but not appearing in the per-player task breakdown on the Stats tab
- Root cause: nested dict mutation via force-unwrap (`counts[player]![key] += n`) operated on a copy and did not write back; since OB/Sand are only stored in `repeatableCounts` (not the Bool `scores` dict), they had no fallback path into the stats totals
- Fix: replaced all inner-dict mutations with `counts[player, default: [:]][key, default: 0] += n`, which uses subscript-with-default semantics at both levels and correctly propagates writes back to the outer dict

---

## Version 1.5 — Scorecard Tab
*May 11, 2026*

---

### New Features

**Stroke Play Scorecard Tab**
- New "Scorecard" tab in the main game view (between Stats and End)
- Traditional golf scorecard grid: hole numbers, par row, optional handicap row, one row per player
- Score markings follow golf convention: eagle = double gold circle, birdie = single red circle, par = no marking, bogey = single square border, double bogey+ = double square border
- Summary columns: OUT (front 9), IN (back 9), TOT (gross total), NET (net total), +/- (net vs par), DOTS
- Current hole highlighted in yellow across the entire column
- Tap any past hole cell to edit stroke score — wheel picker with label (Par, Birdie, Bogey, etc.)
- Holes played at par with no explicit stroke entry display the par value in muted white; future holes are blank
- History mode (opened from Game History): read-only, no edit tap, no current-hole indicator, no "Tap cell to edit" label
- Team mode: player names tinted cyan/orange by team, with a 5pt team dot beside each name

### Bug Fixes

**Scorecard Layout Split**
- Fixed: left column (PAR, HDCP, player names) and scrollable hole columns rendered at different vertical positions
- Rewrote grid using ZStack sticky-column pattern: `ScrollView` with a `Color.clear` spacer reserves space under the fixed left column; left column overlaid at `.topLeading`; outer `ZStack` pinned to exact `gridHeight` so both sides are always flush
- Fixed `leftCell` padding order — `.padding(.leading, 8)` was applied after `.frame(width: leftW)`, making header cells 8pt wider than player rows; moved padding before the frame

**Scorecard Score Edit Not Saving**
- Fixed: tapping a cell and saving a new stroke via the picker had no effect
- Root cause: `ScorecardView` was rendering from a struct-copy of `GameState` passed by `MainGameView`; after `setStrokeScore` updated `manager.game`, the scorecard waited for `MainGameView` to re-render before receiving the new value
- Fix: `ScorecardView` now owns a computed `game` property that reads `manager.game` directly for live games and falls back to the passed-in historical game for history view; `@Observable` tracking fires an immediate re-render on every save

---

## Version 1.4 — Handicap Toggle, History View, Stepper Layout
*May 11, 2026*

---

### New Features

**Use Handicap Toggle**
- New "Use Handicap" toggle in game setup (Game Options section, alongside Wager and Payout Cap), defaulting to ON
- When disabled: HCP pickers hidden for the host and all added players in CreateGameView; handicap picker hidden in PlayerPickerView manual tab; Low Hole uses gross scores for all players; `(net X)` label suppressed in ScoreEntryView stroke picker
- `useHandicap` stored in `GameRules`, persisted through CloudKit and local storage with `decodeIfPresent` (defaults to `true` for backward compat with existing games)

**Game History — Return to Home**
- `GameOverView` now accepts an `isHistoryView: Bool` parameter (default `false`)
- When opened from `GameHistoryView` (history mode): Share Results, Back to Hole 18, and New Round buttons are hidden; replaced with a single green "Return to Home" button that calls `manager.startNewGame()` and routes back to HomeView
- System back-swipe still works in history mode (returns to the history list)
- Live game mode (`isHistoryView: false`): all existing buttons unchanged

### Bug Fixes

**OB/Sand Stepper Layout Overflow**
- Fixed: stepper rows overflowed horizontally with 3–4 players, breaking the scoring grid
- Redesigned `ScoreStepperButton` as a compact pill: natural width 60pt (down from ~96pt)
  - Buttons reduced from 30pt circles to 22pt tap-rectangle targets
  - Font sizes reduced (14pt semibold buttons, 13pt bold count)
  - Capsule background drawn at fixed 26pt height without constraining the 36pt tap area
  - Pill fills red when count > 0; minus dimmed to near-invisible when count is 0
- Narrowed Task label column from 100pt + 20pt padding to 90pt + 16pt padding across all four alignment sites (headers, stroke row, task rows)
- Layout now fits on iPhone SE (375pt) for all player counts: 67pt per column at 4 players, 90pt at 3, 134pt at 2 — stepper content (60pt) fits in all cases
- Row height restored to consistent `.padding(.vertical, 12)` matching all other task rows

---

## Version 1.3 — Repeatable Task Steppers
*May 11, 2026*

---

### New Features

**OB and Sand Steppers**
- OB and Sand tasks now use a `[−][count][+]` stepper instead of a radio toggle, supporting 0–3 hits per hole
- Count defaults to 0; buttons are disabled at their respective bounds
- Each hit distributes 1 dot to every other player (negative task behavior), so 2 OB = 2 dots to each opponent
- Stepper UI is read-only for non-host players, consistent with all other score controls
- Counts stored in a separate `repeatableCounts` field (`hole → player → task → count`) alongside the existing Bool scores, ensuring full backward compatibility with saved games

**Repeatable Task Architecture**
- New `isRepeatable` flag on `CustomTask` — when true, the task is scored as a stepper count rather than a Bool toggle
- `adjustRepeatableCount` manager method clamps counts to 0–3, triggers haptic feedback, and syncs to CloudKit via `repeatableCountsJSON`
- All four dot calculation functions (`calculateTotalDots`, `calculateHoleDots`, `calculateTeamModeHoleDots`, `calculateTeamModeDots`) now include a second pass over `repeatableCounts`, multiplying task points by count
- Game Over stats section accumulates repeatable counts per player (e.g. "OB: 3" across the round)
- `repeatableCounts` stored in `GameState`, synced through CloudKit, and decoded with `decodeIfPresent` for zero-migration backward compat

**Splash Screen Persistence Fix**
- Birthday splash screen now uses `@AppStorage` to persist the last-shown date across app sessions
- Splash shows at most once per calendar day, surviving memory purges and cold relaunches
- Previously used `@State`, which reset after ~10 minutes in the background

---

## Version 1.2 — Course Flexibility & Payout Cap
*May 7, 2026*

---

### New Features

**Maximum Owed Cap**
- New toggle in game setup ("Payout Cap" section) to limit the maximum any player can owe
- Defaults to $20 when enabled; fully configurable per game
- Debts over the cap are redistributed proportionally across creditors (floor each share, remainder to smallest creditor)
- Cap applied independently per debtor — one player's cap never affects another's calculation
- PaymentView: capped rows show original amount in red with strikethrough and capped amount in green, plus "Cap applied" label; a summary banner shows original vs. capped totals
- Game Over payouts tab: yellow shield banner ("Maximum owed cap of $X applied") when any cap was triggered; same strikethrough treatment per debt row
- Share Results text includes cap notice and original amounts alongside capped amounts
- `maxOwedEnabled` and `maxOwedAmount` stored in `GameRules`, persisted through CloudKit and local storage with `decodeIfPresent` for backward compat

**Course Selection Without Scorecard Data**
- Selecting a golf course no longer requires the Golf Course API to return hole data
- Create Game button enables as soon as a course is selected, even if par/handicap data is unavailable
- When no scorecard data is found, a warning badge is shown in the course section: "No scorecard data found — Par 3s and handicap won't be tracked"
- Allows play at courses the API doesn't cover (e.g. Red Wing Golf Course) without having to pick a surrogate course

### Bug Fixes

**Greenie Value Inflated After Back Navigation**
- Fixed: pressing Next through par 3 holes accumulated greenie carryover, then pressing Prev left `currentGreenieValue` at the inflated level instead of recalculating to match the target hole
- Added `recalculateGreenieCarryover` (mirrors the existing `recalculateLowHoleCarryover`) — called alongside Low Hole recalculation whenever `setHole` navigates backward
- Greenie value now correctly resets to base points when navigating back to the starting hole

---

## Version 1.1 — Stability, Sync & Quality of Life
*April 30, 2026*

---

### New Features

**Starting Hole Selection**
- Choose front 9 or back 9 when creating a game via configurable starting hole

**Configurable Scoring Tasks**
- Added **4-Putt** (-3 dots) and **Lady's Tee** (-3 dots) as default negative tasks
- Preset editor now offers "Update" (overwrite current) or "Save as New" when saving changes

**Smart Birdie Toggle**
- Checking Birdie automatically sets stroke score to par - 1
- Unchecking Birdie resets stroke score back to par

**Join Game Error Handling**
- Inline error messages when join code is invalid, game not found, or player index is out of range
- Error clears automatically when the code is edited
- Join only dismisses the sheet on success

**Network Resilience**
- Games created offline are automatically uploaded to CloudKit when connectivity is restored
- Network monitor (`NWPathMonitor`) watches for path changes and triggers upload

**Persisted State Validation**
- On launch, restored game state is validated (non-empty gameID, players, valid hole range)
- Corrupted or unusable persisted state is discarded instead of crashing

**Backward-Compatible Decoding**
- `GameRules` uses `decodeIfPresent` for all fields so older saved games and history entries decode without errors when new fields are added

### Bug Fixes & Crash Prevention

**Crash Fixes**
- Replaced all force-unwrapped `manager.game!` with safe nil-coalescing fallbacks in MainGameView, ScoreEntryView, StatisticsView, and SideBetsView
- Replaced all force-unwrapped dictionary lookups (`dict[key]!`) with `dict[key, default: 0]` across Helpers.swift, GameOverView, LiveLeaderboardView, and StatisticsView
- Guarded team mode array indices (`players[0]`..`players[3]`) in ScoreEntryView to prevent index-out-of-bounds if team mode activates with fewer than 4 players

**Score Calculation Fixes**
- Fixed backward hole navigation resetting Low Hole and Greenie dots — now clears both stored values AND score booleans so carry-over recalculates correctly on forward traversal
- Fixed `recalculateLowHoleCarryover` to also restore `lowHoleValues` for winning holes, keeping stored values consistent with carryover
- Fixed team mode rounding creating phantom dots — odd totals now split correctly (e.g., 5 dots = 3 + 2 instead of 3 + 3)
- Fixed `calculatePayments()` using a different algorithm than `debtsByPayer` — both now use standard golf pairwise diffs
- Fixed net score calculation using arbitrary default (10) when hole handicap data is missing — now falls back to gross score

**Par 3 Handicap Cap**
- Players with handicap 20+ receive at most 1 stroke on par 3 holes
- Players with handicap under 20 receive 0 strokes on par 3 holes

**CloudKit Sync**
- Added `@MainActor` to all GameManager methods that mutate game state, preventing SwiftUI thread-safety issues
- Fixed leaked polling tasks — `startListeningForChanges()` now cancels previous task before spawning a new one; `isPolling` flag prevents duplicate loops
- `startNewGame()` cancels sync, pending upload, and retry tasks
- Serialized concurrent `updateCloudGame()` calls with a 0.5s debounce — rapid score taps now coalesce into a single CloudKit push instead of overlapping saves
- Added retry logic (3 attempts) to `updateCloudGame()` for transient network failures
- Re-reads latest game state after each CloudKit `await` to capture changes made during the wait
- Added `hasPendingLocalChanges` and `isSaving` flags — sync polling skips remote updates while local changes are pending upload or actively saving, preventing stale data from overwriting in-flight changes
- History is saved exactly once per game (`historySaved` guard)

**Deep Link Safety**
- Deep link join (`papadot://join`) now ignores the link if an active game is in progress, preventing accidental data loss

### Removed

- **WeatherKit** — removed
- **Venmo / Cash App** — removed
- **Guest scoring permissions** — removed
- **Summary tab** on Round Complete screen — removed

---

## Version 1.0 — Benoit 50th Birthday Build
*April 2026*

---

### New Features

**Team Mode**
- 4-player games can now be played as teams (Team A: Players 1 & 2, Team B: Players 3 & 4)
- Low Hole is exclusive per team — only one dot awarded between teammates per hole
- Team carry-over low hole support added

**Handicap Support**
- Added handicap field (0–36) per player during game setup
- Handicap used for net score calculation on Low Hole

**Live Dot Strip Enhancements**
- Current hole dots displayed in real time alongside total dots
- Strip updates instantly on every score toggle — no longer requires advancing to next hole

**Player Management**
- Add players from Contacts
- Add manual players (no contact required)
- Favorite contacts for quick access
- Select multiple favorite contacts at once
- First player auto-populated as phone owner

**Custom Tasks**
- Save and reload custom task presets across games
- Task presets persist between sessions

**Game History**
- History labeled by course name
- History includes date of round
- History persists through app version updates
- Delete individual games from history
- Individual stat history with rolling stats per player

**Invite / Join Flow**
- Send invite link per player that pre-populates recipient and launches app directly into game
- Deep link auto-join via `papadot://join?code=XXXXXX`

**End Game Screen**
- Stats shown on Round Complete screen
- Dollars owed per player displayed clearly
- Greenie stats show correct total dots (including carry-over value)
- Share results via native iOS share sheet

**Greenie Carry-Over**
- If no Greenie scored on a par 3, value carries over and accumulates correctly
- Greenie and Sandy grouped together, displayed only on par 3 holes

**Birthday Splash Screen**
- Benoit 50th Birthday Edition splash screen on every app launch

---

### Bug Fixes

**Scoring**
- Fixed: Adjacent radio button toggle sometimes clearing neighboring player's score (SwiftUI view identity fix)
- Fixed: Greenie carry-over multiplier — 4 consecutive greenies now correctly awards cumulative value, not flat multiplier
- Fixed: Sandy and Greenie now display only on par 3 holes, grouped together
- Fixed: Par 3 holes no longer advance then immediately go back
- Fixed: Back to Hole 18 now works correctly — game does not end until all 18 holes are completed
- Fixed: Task radio buttons display in black on light mode

**Navigation & Sync**
- Fixed: App no longer returns to home screen after inactivity — game state preserved
- Fixed: Current hole no longer moves backwards unexpectedly — only Previous/Next buttons change hole
- Fixed: CloudKit sync no longer overwrites local hole navigation with stale server values
- Fixed: In-game player join sync

**Scoring Logic**
- Fixed: Low Hole exclusive per team in team mode (not per individual)

---

### Removed

- **Apple Pay** — removed for non-supported devices
- **Reactions (trash talk)** — removed
- **Permissions for others to modify scores** — removed
- **QR code functionality** — removed

---

### Security

- API keys moved out of source code into `Config.xcconfig` (excluded from git)
- `papadot_all_files.txt` removed from repository
- Google Places API key rotated after accidental GitHub exposure
- Golf Course API key rotated
- `.gitignore` updated to exclude all `.xcconfig` files

---

### Infrastructure

- Migrated to Claude Code for direct file editing
- CloudKit container deployed to production
- TestFlight external testing group created
- Public TestFlight link: https://testflight.apple.com/join/J3Yuv37C

---

*Built with ❤️ for the Benoit 50th Birthday golf trip — Las Vegas, April 2026*
