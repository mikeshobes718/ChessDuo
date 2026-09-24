# Chess Duo 2.0

Native SwiftUI chess for two, rebuilt from scratch. iOS 17+, iPhone and iPad.

## What's inside

- **Engine** (`ChessDuo/Engine`): full move generation (perft-verified), SAN/PGN/FEN, draw rules
  (stalemate, fifty-move, repetition, insufficient material), alpha-beta search with iterative
  deepening, quiescence, transposition table, killers/history, null-move and LMR, an opening book,
  five difficulty levels, an on-device coach, and a post-game reviewer (accuracy, best/mistake/blunder).
- **Modes**: Online rooms (Berth game function, room codes, spectate, draw/undo offers,
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

Online play talks to the `game` function on Berth, app `chessduo`:
`https://api.atberth.com/v1/apps/chessduo/functions/game`. The source is `berth/functions/game.ts`,
deployed with `berth functions deploy --app chessduo game berth/functions/game.ts --verify key
--timeout-ms 30000 --memory-mb 256`. The app sends the publishable key (`API_PUBLISHABLE_KEY`,
safe to ship); the `games`, `match_archives`, and `push_tokens` tables are secret-only, so only the
function can touch them. Function secrets (APNs, OpenRouter/OpenAI) are set with `berth env set`.

Optional accounts use Berth end-user auth on the same app (`ChessDuo/Account`): Apple, Google, email +
password, and passwordless email codes; `/auth/reset` for forgot password (two calls, signs in, and Berth
revokes every other session); `/auth/verify-email` for a signed-in but unverified user; `/auth/sessions`
for the signed-in devices screen. `chessduo` requires a verified email, so password signup returns no
session until the emailed code is confirmed via `/auth/verify` (a wrong address can be corrected first
with `POST /auth/email {email, current}`). Password rules come from `GET /auth/settings`. Rate limits
and lockouts are enforced by Berth; the app only shows the server's `Retry-After` countdown.

`supabase/` is the previous backend, kept until the old database is retired. No secret keys in
this repo.
