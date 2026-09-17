# Chess Duo 2.0

Native SwiftUI chess for two, rebuilt from scratch. iOS 17+, iPhone and iPad.

## What's inside

- **Engine** (`ChessDuo/Engine`): full move generation (perft-verified), SAN/PGN/FEN, draw rules
  (stalemate, fifty-move, repetition, insufficient material), alpha-beta search with iterative
  deepening, quiescence, transposition table, killers/history, null-move and LMR, an opening book,
  five difficulty levels, an on-device coach, and a post-game reviewer (accuracy, best/mistake/blunder).
- **Modes**: Online rooms (existing Supabase edge function, room codes, spectate, draw/undo offers,
  nudges, push alerts), Pass & Play, vs Computer, Puzzles (100 engine-verified), Learn, Analysis board.
- **Boards**: 2D (Canvas, drag or tap, sliding animations) and 3D (SceneKit, orbit/pinch camera,
  animated moves). Ten board themes + custom colours, three piece styles.
- **Extras**: clocks with increments, match review with eval graph, history with replay and PGN
  share, stats, EN/PT/ES localisation, synthesized sounds + haptics, deep links `chessduo://room/CODE`.

## Build & install

```bash
scripts/install.sh          # both phones
scripts/install.sh mike     # or: liana
```

The script regenerates the Xcode project with XcodeGen, builds Release outside iCloud Drive
(`/tmp/chessduo-dd`), strips extended attributes and installs over Wi‑Fi with `devicectl`.
Bundle id `com.mikeshobes.chesscoachduo` (same as the original app, so it replaces it in place).

## Tests

- Engine perft + rules: `/tmp/chessduo-test` harness (see git history) – all reference perft nodes match.
- UI: `ChessDuoUITests` taps through every screen and control on the simulator:
  `xcodebuild -scheme ChessDuo -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test`

## Server

Online play talks to `https://kcdlmmfzeksjqwdppjzy.supabase.co/functions/v1/game` (unchanged from
v1; source lives in `../ChessCoach/supabase/functions/game`). No secrets in this repo.
