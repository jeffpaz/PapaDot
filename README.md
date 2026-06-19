# PapaDot ⛳
**Golf Betting Made Simple** — v1.25

PapaDot is a SwiftUI iOS app for tracking "dot" (point-based) golf betting games. Create or join multiplayer rounds, customize scoring tasks, and sync scores in real-time—no more pen-and-paper chaos on the course.

---

## Features

### Multiplayer & Sync
- Host creates a game with a 6-character code; friends join on their own devices
- Real-time score sync via CloudKit — all players see updates within seconds
- Non-host players auto-advance to results when the host finishes hole 18
- Offline mode: games created without connectivity upload automatically when the network returns

### Scoring
- Stroke score picker per player per hole (par, birdie, bogey, etc.)
- Handicap-adjusted net scores: strokes distributed across non-par-3 holes ranked by hole difficulty; par-3 holes receive no strokes
- Auto Low Hole: lowest net score each hole wins automatically; ties carry the pot forward
- Greenie carry-over: par-3 hole-in-proximity bonus that accumulates until won
- Configurable carry-over limits: cap the max payout, optionally reset to zero on a win
- OB and Sand steppers (0–3 hits per hole) with automatic dot distribution

### Team Mode (2v2)
- Players 1 & 2 vs Players 3 & 4 with customizable team names
- Team Low auto-award: team with the best net score each hole wins configurable dot bonus
- Live scoring header shows two team badges (total dots + hole dots) instead of individual badges
- End-of-round screen shows team totals, Team Low win summary, and per-player payouts

### Game Setup
- Fully customizable task list: add, edit, or remove tasks; save/load named presets
- Task options: points value, exclusive (one winner per hole), negative (penalty), carry-over, repeatable stepper
- Presets save the Team Low point value alongside the task list; loading a preset in a team game fully restores the configuration
- Wager per dot, maximum owed cap (proportional debt redistribution), handicap toggle, starting hole
- Game history: review any past round in read-only stats + payout view; lifetime leaderboard correctly tallies team game payouts

### End of Round
- Stats tab: per-player dot bar chart, task breakdown, best hole highlight, fun loser labels
- Team stats card with Team Low wins displayed per team
- Payouts tab: who owes whom and how much, with optional cap applied
- Share results via iMessage

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI with `@Observable` / `@Environment` |
| Multiplayer | CloudKit (`CKRecord`, private database, 5s polling) |
| Local persistence | `UserDefaults` + `JSONEncoder` via `PersistenceManager` |
| Networking | `NWPathMonitor` for offline-game upload detection |
| Home screen widget | WidgetKit (`PapaDotWidgetExtension`) |

---

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for a full breakdown of layers, data flow, and key design decisions.

---

## Getting Started

```bash
git clone https://github.com/jeffpaz/PapaDot.git
```

1. Open `PapaDot.xcodeproj` in Xcode (16+)
2. Build and run on a simulator or physical device (iOS 17+)
3. Configure your iCloud container (`iCloud.com.jeffpaz.PapaDot`) in your Apple Developer account

---

## License

MIT — Happy golfing! 🏌️‍♂️
