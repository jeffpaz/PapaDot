# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

PapaDot is a single-target SwiftUI iOS app (+ WidgetKit extension) for tracking "dot" (point-based) golf betting games, with CloudKit multiplayer sync. See `README.md` for the feature list and `ARCHITECTURE.md` for a full breakdown of layers, data flow, and key design decisions (GameManager state machine, host authorization, scoring/hole-advance write paths, carry-over math, CloudKit record schema) — read `ARCHITECTURE.md` before making non-trivial changes to `GameManager`, `Helpers.swift`, or the CloudKit sync path rather than re-deriving it from source.

## Commands

Build and test via `xcodebuild` (scheme `PapaDot`, project `PapaDot.xcodeproj`). There is no Swift Package / SPM-only build — this is an Xcode project.

```bash
# Build
xcodebuild -project PapaDot.xcodeproj -scheme PapaDot -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests (PapaDotTests + PapaDotUITests)
xcodebuild -project PapaDot.xcodeproj -scheme PapaDot -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test class or method
xcodebuild -project PapaDot.xcodeproj -scheme PapaDot -destination 'platform=iOS Simulator,name=iPhone 16' \
  test -only-testing:PapaDotTests/PapaDotLogicTests/testGreenieCarryOver_FourPar3s_NoWinnerFirst3_WinnerHole4Gets4Points

# Run a single UI test
xcodebuild -project PapaDot.xcodeproj -scheme PapaDot -destination 'platform=iOS Simulator,name=iPhone 16' \
  test -only-testing:PapaDotUITests/PapaDotUITests/testTaskToggleUpdatesImmediatelyOnTap
```

PapaDotUITests launches the app with `-UITesting`, which makes `GameManager.init()` synthesize a fixed 2-player game in memory (skipping CloudKit and persistence) so tests land directly on a deterministic Score screen — see `GameManager.init()`.

Alternatively, open `PapaDot.xcodeproj` in Xcode 16+ and build/run/test from there (Cmd+U for tests). `buildServer.json` configures `xcode-build-server` for LSP/SourceKit support in editors outside Xcode.

Requires `PapaDot/Config.xcconfig` (gitignored, not present from a fresh clone) with `GOLF_API_KEY` and `GOOGLE_API_KEY` set — the app will not build without it.

### Release / version bump

`scripts/bump_version.sh <X.Y>` bumps `MARKETING_VERSION` (app + widget targets) and `CURRENT_PROJECT_VERSION` (YYYYMMDD build number) in `project.pbxproj`, syncs the README version badge, commits, and tags — but never pushes. It refuses to run unless `CHANGELOG.md` already has a `## Version X.Y` entry, and refuses if any files other than `project.pbxproj`/`CHANGELOG.md`/`README.md` are dirty. Always add the changelog entry first, then run the script, then push manually (`git push origin main --tags`).

## Architecture essentials

- **State ownership**: `GameManager` (`PapaDot/Managers/GameManager.swift`) is an `@Observable` class injected at the app root via `.environment`; it holds the single `game: GameState?` and is the only thing that mutates it. Views never mutate `GameState` directly.
- **Host authorization is server-side, not UI-side**: only the host device may call the scoring mutators (`setStrokeScore`, `toggleScore`, `adjustRepeatableCount`, `setHole`, `advanceHole`) — each mutator itself guards on `GameManager.isHost`, which is set once at creation/join time, persisted device-locally (`PersistenceManager.saveIsHost`/`loadIsHost`), and is *never* derived from a display name or from `recordID != nil` (guests get a `recordID` too). Views additionally read `isHost` to hide/disable controls, but that's a UX nicety, not the actual gate — don't remove the manager-level guard when touching UI.
- **Dot math is centralized and pure**: all scoring/net-score/carry-over/payout calculations live as free functions in `PapaDot/Utilities/Helpers.swift` (`calculateTotalDots`, `calculateHoleDots`, `calculateNetScore`, `calculateCarryOverResult`, `calculateCappedDebts`) with no access to `GameManager` and no side effects. Every screen that needs one of these numbers (`ScoreEntryView`, `ScorecardView`, `GameOverView`, `GameHistoryView`'s lifetime leaderboard) calls the shared function rather than keeping its own copy — this has been a repeated source of bugs (three divergent copies of the net-score formula, a lifetime-leaderboard payout mismatch), so when changing scoring logic, grep for all call sites of the relevant `Helpers.swift` function rather than patching one caller.
- **Team mode** is derived, not stored: `players[0-1]` = Team A, `players[2-3]` = Team B, computed on the fly via `teamForPlayer(_:)`/`teamAssignments` — there's no separate team-assignment model.
- **Persistence**: `PersistenceManager` (`PapaDot/Utilities/PersistenceManager.swift`) round-trips `GameState` to `UserDefaults` via `JSONEncoder`/`JSONDecoder` under keys `currentGame` and `gameHistory`. Every field added after the initial release must use `decodeIfPresent(...) ?? default` in `GameState`/`GameRules` custom decoding so old CloudKit records and old locally-persisted games load without crashing.
- **CloudKit sync**: writes are debounced 0.5s per edit (`scheduleCloudSync`), polling reads happen every 5s and are skipped while `hasPendingLocalChanges || isSaving` to avoid clobbering an in-flight local edit; a remote fetch is only applied if its `lastModifiedDate` is newer than local. Offline-created games upload automatically via `NWPathMonitor` when connectivity returns.
- **Widget**: `PapaDotWidgetExtension` reads game state from an App Group `UserDefaults`, written by `GameManager+Widget.swift`; widget timeline reloads are debounced (400ms) separately from the CloudKit sync debounce.

## Conventions

- `GameState` mutations follow copy-modify-assign (`var g = game; ...; game = g`) — `GameState` is a value type with no reference semantics.
- `CHANGELOG.md` entries are written per-release under `## Version X.Y — <theme>`, grouped by category (Security/Data Integrity, Bug Fixes, Performance, Code Quality, New Features), each with root cause and fix described.
