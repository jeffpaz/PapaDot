# PapaDot Changelog

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
