# PapaDot
PapaDot ⛳
Golf Betting Made Simple
PapaDot is a SwiftUI iOS app for tracking "dot" (point-based) golf betting games with friends. Create or join multiplayer rounds, customize tasks, and sync scores in real-time—no more pen and paper chaos on the course!

Key Features

Multiplayer Sync: Host creates a game with a 6-character code; friends join instantly. Real-time updates via CloudKit.
Custom Rules: Define tasks (e.g., "sand save", "longest drive")—some exclusive to one player per hole.
Game Flow: Setup → Waiting Room → Scoring (hole-by-hole) → Game Over summary.
Resume Anytime: Active games persist locally and show a resume banner on the home screen.
History: Review completed rounds.

Tech Stack

SwiftUI (with Observation framework)
CloudKit for real-time multiplayer sync
Local persistence for seamless resuming

Getting Started

Clone the repo:textgit clone https://github.com/jeffpaz/PapaDot.git
Open PapaDot.xcodeproj in Xcode (latest version recommended).
Build and run on a simulator or device (iOS 17+).
Enable CloudKit in your Apple Developer account and configure the container.

Contributing
Feel free to open issues or PRs! Focus areas: add more stats, payment integration (Stripe), or UI polish.
License
MIT
Happy golfing! 🏌️‍♂️
