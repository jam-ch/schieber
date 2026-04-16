# Schieber

A minimal SwiftUI iOS app to track Schieber rounds and team scores.

Features
- Record rounds with points for Team A and Team B (points in each round must sum to 157).
- Support for multiple Spielarten (Normal, Doppelt, Obeabe, Undeufe, Slalom) with factor multipliers that affect scoring and match bonuses.
- Match bonus: when "Match" is checked for a round, a bonus of 100 points (configurable constant MATCH_BONUS) is applied and multiplied by the Spielart factor.
- Spielstand (team totals) aggregates totals across all rounds including scaled bonuses.
- Import/Export JSON for persistence and backup.

Quick start

Prerequisites
- Xcode 15 or newer
- macOS with Apple Silicon or Intel (use the appropriate iOS simulator)

Build & Run
1. Open the Xcode project: `Schieber.xcodeproj`
2. Select a Simulator (e.g. iPhone 17, iOS 26.4)
3. Build & Run (⌘R)

Repository
- Tag: `v1`
- URL: https://github.com/jam-ch/schieber

Notes
- Team names are persisted using `AppStorage`.
- Validation: the app enforces that the sum of points entered for both teams in a round equals 157 and auto-fills the other team's points when you type one side.
- The match bonus is applied as `MATCH_BONUS * spielart.faktor` (e.g., doppelt doubles both points and the bonus).

Contributing
- Feel free to open issues or PRs on GitHub.

License
- Add a license if you plan to share this publicly.
